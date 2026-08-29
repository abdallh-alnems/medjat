<?php

declare(strict_types=1);

namespace App\Services\Attendance;

use App\Domain\Attendance\AttendanceMethod;
use App\Domain\Attendance\AttendanceSecurityLog;
use App\Domain\Attendance\BranchQrChallenge;
use App\Domain\Attendance\NetworkVerifier;
use App\Domain\Attendance\PunchPhotoStore;
use App\Domain\Attendance\SharedDeviceDetector;
use App\Domain\Attendance\WebAccessPolicy;
use App\Domain\Face\FaceMatcher;
use App\Domain\Time\TenantClock;
use App\Exceptions\ApiFailure;
use App\Models\Attendance;
use App\Models\Branch;
use App\Models\Employee;
use App\Services\Auth\WebSessionService;
use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * Recording a departure.
 *
 * Every control that guards the arrival is repeated here, and the repetition is
 * the point: a control applied only on the way in is a control an employee can
 * walk away from. "Clock out from home on a spoofed location", "have a
 * colleague close your day", "leave early from anywhere, the network is only
 * checked in the morning" — each of those is a hole that opens the moment one of
 * these checks exists on check-in alone.
 */
final class CheckOutAction
{
    public function __construct(private readonly FaceMatcher $faces) {}

    /**
     * @param  array<array-key, mixed>  $input  Straight off the request.
     * @return array{message: string, time: string, cancelled_breaks: int, session_ended: bool}
     *
     * @throws ApiFailure
     */
    public function execute(
        Employee $employee,
        int $tenantId,
        array $input,
        bool $isWeb,
        ?string $sessionDeviceId,
    ): array {
        $latitude = isset($input['latitude']) ? Value::float($input['latitude']) : null;
        $longitude = isset($input['longitude']) ? Value::float($input['longitude']) : null;
        $requestedMethod = Value::nullableString($input['method'] ?? null);
        $branchId = $employee->branch_id;
        $branch = $branchId === null ? null : Branch::query()->forTenant($tenantId)->whereKey($branchId)->first();
        $origin = $isWeb ? 'web' : 'app';

        if ($isWeb) {
            $this->guardWebChannel($employee, $tenantId, $branchId, $latitude, $longitude);
        }

        // Mirrors check-in. Enforcing on arrival only would leave the hole half
        // open: someone could arrive legitimately and then clock out from home
        // on a spoofed location.
        if (Value::int($input['is_mock_location'] ?? null) === 1 && $this->rejectsMockLocation($tenantId)) {
            AttendanceSecurityLog::record($tenantId, $employee->id, $branchId, 'mock_location', 'blocked', $latitude, $longitude);
            throw new ApiFailure('تم رصد موقع وهمي', 403, 'MOCK_LOCATION');
        }

        // Same reasoning: enforcing on arrival only would let a colleague clock
        // someone out.
        if ($this->requiresLocalBiometric($tenantId) && Value::int($input['local_biometric'] ?? null) !== 1) {
            AttendanceSecurityLog::record($tenantId, $employee->id, $branchId, 'no_local_biometric', 'blocked', $latitude, $longitude);
            throw new ApiFailure('يجب التحقق ببصمة الجهاز أولاً', 403, 'LOCAL_BIOMETRIC_REQUIRED');
        }

        $methods = AttendanceMethod::resolveFor($employee, $tenantId);

        $this->guardFace($employee, $tenantId, $branch, $methods, $requestedMethod, $input, $latitude, $longitude);

        // WiFi on the way out, for the same reason as the face path.
        if ($branch !== null && $requestedMethod === 'wifi_gps' && in_array('wifi_gps', $methods, true)) {
            $network = NetworkVerifier::acceptsApp($branch, $input);
            if (! $network['accepted']) {
                throw new ApiFailure('يجب الاتصال بشبكة الفرع', 403, 'WIFI_'.strtoupper($network['reason']));
            }
        }

        if ($isWeb && $branch !== null && ! NetworkVerifier::acceptsBrowser($branch)) {
            AttendanceSecurityLog::record($tenantId, $employee->id, $branchId, 'web_wrong_network', 'blocked', $latitude, $longitude);
            throw new ApiFailure('يجب الاتصال بشبكة الفرع', 403, 'WEB_WRONG_NETWORK');
        }

        $this->guardRotatingQr($employee, $tenantId, $branch, $requestedMethod, $input, $latitude, $longitude);

        $photo = $this->captureEvidence($employee, $tenantId, $methods, $requestedMethod, $input, $isWeb);

        Attendance::recordCheckOut($employee->id, $tenantId);

        $today = TenantClock::date($tenantId);
        Attendance::recordChannel($tenantId, $employee->id, $today, 'check_out', $origin, $photo);

        $sessionEnded = false;
        if ($isWeb) {
            $others = SharedDeviceDetector::otherEmployeesOnDevice($tenantId, (string) $sessionDeviceId, $employee->id, $today);
            SharedDeviceDetector::flag($tenantId, $today, $employee->id, $others, $branchId);

            // The system ends the session, not the employee. A shared office
            // computer has to be left safe by default — relying on the person
            // walking out to remember a "log out" button is exactly how the next
            // person inherits their identity.
            WebSessionService::revokeAllForEmployee($employee->id, 'web_checked_out');
            $sessionEnded = true;
        }

        // Once the employee has left, a still-pending permission for today can
        // no longer be acted on, so it is cancelled rather than left hanging.
        $cancelledBreaks = DB::table('break_requests')
            ->where('employee_id', $employee->id)
            ->where('tenant_id', $tenantId)
            ->where('status', 'pending')
            ->where('date', '<=', DB::raw('CURDATE()'))
            ->update([
                'status' => 'cancelled',
                'decision_note' => 'أُلغي تلقائياً بعد تسجيل الانصراف',
            ]);

        return [
            'message' => 'Check-out successful',
            // The company's wall clock, matching what was just stored.
            'time' => TenantClock::time($tenantId),
            'cancelled_breaks' => $cancelledBreaks,
            'session_ended' => $sessionEnded,
        ];
    }

    /**
     * A company that disables the browser channel mid-shift must still let an
     * employee close the day they already opened.
     *
     * Refusing here would leave an open row only an administrator can fix, so a
     * settings change would cost the employee their hours. The policy applies to
     * *new* days; an already-open one is closed and flagged instead.
     */
    private function guardWebChannel(Employee $employee, int $tenantId, ?int $branchId, ?float $lat, ?float $lng): void
    {
        if (WebAccessPolicy::isAllowed($employee, $tenantId)) {
            return;
        }

        if (! Attendance::hasOpenDay($employee->id, $tenantId)) {
            WebAccessPolicy::refuse($tenantId, $employee->id, 'web_not_permitted', $branchId, $lat, $lng);
        }

        AttendanceSecurityLog::record($tenantId, $employee->id, $branchId, 'web_not_permitted', 'flagged', $lat, $lng);
    }

    /**
     * Face on the way out. Verifying only the arrival would leave the method
     * half enforced — a colleague could clock someone out.
     *
     * When face_selfie is the only self-service method the employee has, a
     * check-out that carries no selfie is refused outright: otherwise sending an
     * empty body would step around the face entirely.
     *
     * @param  list<string>  $methods
     * @param  array<array-key, mixed>  $input
     */
    private function guardFace(
        Employee $employee,
        int $tenantId,
        ?Branch $branch,
        array $methods,
        ?string $requestedMethod,
        array $input,
        ?float $lat,
        ?float $lng,
    ): void {
        $declared = $requestedMethod === 'face_selfie';
        $onlyMethod = in_array('face_selfie', $methods, true)
            && array_intersect(['qr_gps', 'gps_only'], $methods) === [];

        if (! $declared && ! $onlyMethod) {
            return;
        }

        if (! $declared) {
            throw new ApiFailure('التحقق بالوجه مطلوب لتسجيل الانصراف', 400, 'FACE_REQUIRED');
        }

        $verification = $this->faces->verify($employee, $tenantId, $branch, 'check_out', $input, $lat, $lng);

        if (! $verification->accepted) {
            throw new ApiFailure(
                $verification->message,
                403,
                'FACE_'.strtoupper($verification->result),
                ['score' => $verification->score, 'threshold' => $verification->threshold],
            );
        }
    }

    /**
     * @param  array<array-key, mixed>  $input
     */
    private function guardRotatingQr(
        Employee $employee,
        int $tenantId,
        ?Branch $branch,
        ?string $requestedMethod,
        array $input,
        ?float $lat,
        ?float $lng,
    ): void {
        if ($branch === null || $requestedMethod !== 'qr_gps' || ! $branch->rotating_qr_enabled) {
            return;
        }

        $qrCode = Value::string($input['qr_code'] ?? null);
        if ($qrCode === '') {
            throw new ApiFailure('امسح الرمز المعروض على الشاشة', 400, 'QR_REQUIRED');
        }

        // 'check_out' is a separate claim from 'check_in': arriving and leaving
        // inside one ninety-second window is unusual but legitimate, and
        // refusing it would mean a short errand costs the employee their day.
        $claim = BranchQrChallenge::consume($qrCode, $tenantId, $branch->id, $employee->id, 'check_out');

        if (! $claim['ok']) {
            AttendanceSecurityLog::record($tenantId, $employee->id, $branch->id, $claim['reason'], 'blocked', $lat, $lng);
            throw new ApiFailure($claim['message'], 403, strtoupper($claim['reason']));
        }
    }

    /**
     * Same rule as the arrival: capture the evidence before writing the punch,
     * so a company that asked for a photo never gets attendance recorded without
     * one.
     *
     * The "only method" clause mirrors the face path. Without it an employee
     * whose sole self-service method is photo_gps could close their day with an
     * empty body, and the company would find half its evidence missing.
     *
     * @param  list<string>  $methods
     * @param  array<array-key, mixed>  $input
     */
    private function captureEvidence(
        Employee $employee,
        int $tenantId,
        array $methods,
        ?string $requestedMethod,
        array $input,
        bool $isWeb,
    ): ?string {
        $photoIsOnlyMethod = in_array('photo_gps', $methods, true)
            && array_intersect(['qr_gps', 'gps_only', 'wifi_gps', 'face_selfie'], $methods) === [];

        $required = $requestedMethod === 'photo_gps'
            || $photoIsOnlyMethod
            || ($isWeb && WebAccessPolicy::photoRequired($tenantId));

        if (! $required) {
            return null;
        }

        $photo = PunchPhotoStore::store(
            is_string($input['photo_base64'] ?? null) ? $input['photo_base64'] : null,
            $tenantId,
            $employee->id,
        );

        if ($photo === null) {
            throw new ApiFailure('الصورة مطلوبة لتسجيل الانصراف', 422, 'PHOTO_REQUIRED');
        }

        return $photo;
    }

    private function requiresLocalBiometric(int $tenantId): bool
    {
        return Value::int(DB::table('tenants')->where('id', $tenantId)->value('require_local_biometric')) === 1;
    }

    private function rejectsMockLocation(int $tenantId): bool
    {
        return Value::int(DB::table('tenants')->where('id', $tenantId)->value('reject_mock_location')) === 1;
    }
}
