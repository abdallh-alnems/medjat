<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Services;

use App\Exceptions\ApiFailure;
use App\Models\Attendance;
use App\Models\Branch;
use App\Models\Employee;
use App\Modules\Attendance\Domain\AttendanceMethod;
use App\Modules\Attendance\Domain\BranchQrChallenge;
use App\Modules\Attendance\Domain\GeofenceCheck;
use App\Modules\Attendance\Domain\NetworkVerifier;
use App\Modules\Attendance\Domain\PunchPhotoStore;
use App\Modules\Attendance\Domain\WebAccessPolicy;
use App\Shared\Face\FaceMatcher;
use App\Shared\Security\AttendanceSecurityLog;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * Recording an arrival.
 *
 * The order of the checks below is the design, not an accident of how it was
 * written. Each one is placed where it is for a reason that is stated at the
 * step, and most of those reasons are about not making the employee pay for a
 * refusal: an out-of-range person should not burn a rotating QR code or a
 * liveness challenge they will need thirty seconds later once they walk in.
 *
 * The cheap checks also come first, so an obvious refusal costs no image
 * processing and no round trip.
 */
final class CheckInAction
{
    public function __construct(private readonly FaceMatcher $faces) {}

    /**
     * @param  array<array-key, mixed>  $input  Straight off the request.
     * @return array{message: string, time: string, branch: string}
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
        $branchId = Value::int($input['branch_id'] ?? null);
        $latitude = Value::float($input['latitude'] ?? null);
        $longitude = Value::float($input['longitude'] ?? null);
        $qrCode = isset($input['qr_code']) && is_string($input['qr_code']) ? $input['qr_code'] : null;
        $isVpn = Value::int($input['is_vpn'] ?? null) === 1;
        $isMockLocation = Value::int($input['is_mock_location'] ?? null) === 1;

        if ($branchId <= 0) {
            throw new ApiFailure('branch_id is required', 422, 'missing_fields');
        }

        $origin = $isWeb ? 'web' : 'app';

        // 1. The browser channel is allowed at all. Checked before anything
        //    else because a company that has not switched it on should not have
        //    its geofence, its QR codes or its cameras consulted.
        if ($isWeb && ! WebAccessPolicy::isAllowed($employee, $tenantId)) {
            WebAccessPolicy::refuse($tenantId, $employee->id, 'web_not_permitted', $branchId, $latitude ?: null, $longitude ?: null);
        }

        $branch = Branch::query()->forTenant($tenantId)->whereKey($branchId)->first();
        if ($branch === null) {
            throw new ApiFailure('Branch not found', 404, 'BRANCH_NOT_FOUND');
        }

        // 2. The method the company allows for this person.
        $allowed = AttendanceMethod::resolveFor($employee, $tenantId);
        $method = $this->resolveMethod($input, $qrCode, $allowed);

        // 3. Device biometric. The cheapest check on the path — a boolean — so
        //    it refuses before any QR, GPS or face work happens. It answers the
        //    question every other control here takes for granted: whether the
        //    person tapping is the person the phone belongs to. Opt-in, and only
        //    enforced when opted in, because older builds never send the field.
        if ($this->requiresLocalBiometric($tenantId) && Value::int($input['local_biometric'] ?? null) !== 1) {
            $this->block($tenantId, $employee, $branchId, 'no_local_biometric', $latitude, $longitude);
            throw new ApiFailure('يجب التحقق ببصمة الجهاز أولاً', 403, 'LOCAL_BIOMETRIC_REQUIRED');
        }

        // 4. QR shape. A branch on rotating codes does not accept its printed
        //    one, and vice versa — the flag is per branch, so one branch can be
        //    on a screen while the next is still on a laminated sheet. No app
        //    release is involved: the app forwards whatever the camera read and
        //    has never interpreted it, so the server decides what it expects.
        $rotatingQr = $method === 'qr_gps' && $branch->rotating_qr_enabled;

        if ($rotatingQr) {
            // Said before the geofence is evaluated: someone who scanned nothing
            // should be told to look at the screen, not told they are out of
            // range.
            if ($qrCode === null || $qrCode === '') {
                throw new ApiFailure('امسح الرمز المعروض على الشاشة', 400, 'QR_REQUIRED');
            }
        } elseif ($qrCode !== null && $qrCode !== '' && $branch->getAttribute('qr_code') !== $qrCode) {
            throw new ApiFailure('Invalid QR code for this branch', 400, 'INVALID_QR');
        }

        // 5. A real location. Both qr_gps and gps_only need one, and a denied
        //    permission reads as 0,0 — refuse that rather than let a QR code
        //    pass with no location check behind it.
        if ($latitude === 0.0 && $longitude === 0.0) {
            throw new ApiFailure('Location is required for check-in', 400, 'LOCATION_REQUIRED');
        }

        // 6. A mocked location invalidates the geofence entirely, so this runs
        //    before it rather than after. The app refuses to get this far on its
        //    own, but that check lives on the employee's phone; this is the one
        //    they cannot remove. Opt-in, and only meaningful on Android — iOS
        //    never reports it.
        if ($isMockLocation && $this->rejectsMockLocation($tenantId)) {
            $this->block($tenantId, $employee, $branchId, 'mock_location', $latitude, $longitude);
            throw new ApiFailure('تم رصد موقع وهمي', 403, 'MOCK_LOCATION');
        }

        // 7. The geofence.
        $geofence = GeofenceCheck::evaluate($branch, $latitude, $longitude);

        // The sighting is recorded BEFORE the geofence verdict and regardless of
        // it. "Someone tried from outside the fence on network X" is exactly the
        // signal the approval screen needs to keep an employee's home router out
        // of the branch's approved list.
        if ($method === 'wifi_gps') {
            NetworkVerifier::recordSighting(
                $tenantId,
                $branchId,
                $employee->id,
                $input,
                $geofence->passed,
                $geofence->distanceMetres,
            );
        }

        if (! $geofence->passed) {
            throw new ApiFailure($geofence->message, 400, $geofence->reason ?? 'GPS_OUT_OF_RANGE');
        }

        // 8. WiFi, as an additional constraint on top of the geofence — never a
        //    substitute, because GPS drifts indoors and the signal leaks
        //    outdoors.
        if ($method === 'wifi_gps') {
            $network = NetworkVerifier::acceptsApp($branch, $input);
            if (! $network['accepted']) {
                throw new ApiFailure('يجب الاتصال بشبكة الفرع', 403, 'WIFI_'.strtoupper($network['reason']));
            }
        }

        // 9. The browser channel's network control. Restriction is one of the
        //    compensating controls that make the weakest channel acceptable, and
        //    the status endpoint had been announcing it to the page since day
        //    one while nothing applied it here — the control existed on the
        //    screen and nowhere else.
        if ($isWeb && ! NetworkVerifier::acceptsBrowser($branch)) {
            $this->block($tenantId, $employee, $branchId, 'web_wrong_network', $latitude, $longitude);
            throw new ApiFailure('يجب الاتصال بشبكة الفرع', 403, 'WEB_WRONG_NETWORK');
        }

        // 10. The rotating code is claimed after the geofence for the same
        //     reason the face check runs there: spending a code writes a row,
        //     and someone standing outside the radius must not burn one they
        //     will need thirty seconds later when they walk in.
        if ($rotatingQr) {
            $claim = BranchQrChallenge::consume((string) $qrCode, $tenantId, $branchId, $employee->id, 'check_in');

            if (! $claim['ok']) {
                // A replay is a forwarded screenshot; an expiry is usually a slow
                // scan. Both are recorded, because a run of expiries at one
                // branch is how a dead display announces itself.
                $this->block($tenantId, $employee, $branchId, $claim['reason'], $latitude, $longitude);
                throw new ApiFailure($claim['message'], 403, strtoupper($claim['reason']));
            }
        }

        // 11. Face verification runs after GPS so an out-of-range employee never
        //     burns a liveness challenge, and so the cheap checks refuse first.
        //
        //     The phone extracts the embedding; the *server* scores it. A client
        //     that reported its own verdict would be asking the thing being
        //     verified whether it passed.
        $faceScore = null;
        if ($method === 'face_selfie') {
            $verification = $this->faces->verify($employee, $tenantId, $branch, 'check_in', $input, $latitude ?: null, $longitude ?: null);

            if (! $verification->accepted) {
                throw new ApiFailure(
                    $verification->message,
                    403,
                    'FACE_'.strtoupper($verification->result),
                    ['score' => $verification->score, 'threshold' => $verification->threshold],
                );
            }

            $faceScore = $verification->score;
        }

        // 12. Evidence, captured before the punch is written so a company that
        //    requires a photo never ends up with attendance recorded without
        //    one. Two independent reasons to hold an image, and they are not the
        //    same rule: photo_gps is a method chosen *because* the company wants
        //    a photograph and no biometric processing, while the browser rule is
        //    a property of the weakest channel. A company can be on both, so
        //    this is an OR rather than a branch.
        $photo = null;
        if ($method === 'photo_gps' || ($isWeb && WebAccessPolicy::photoRequired($tenantId))) {
            $photo = PunchPhotoStore::store(
                is_string($input['photo_base64'] ?? null) ? $input['photo_base64'] : null,
                $tenantId,
                $employee->id,
            );

            if ($photo === null) {
                throw new ApiFailure('الصورة مطلوبة لتسجيل الحضور', 422, 'PHOTO_REQUIRED');
            }
        }

        // 10. Write it.
        Attendance::recordCheckIn(
            employeeId: $employee->id,
            branchId: $branchId,
            tenantId: $tenantId,
            method: $method,
            latitude: $latitude ?: null,
            longitude: $longitude ?: null,
            isVpn: $isVpn,
        );

        $today = TenantClock::date($tenantId);
        Attendance::recordChannel($tenantId, $employee->id, $today, 'check_in', $origin, $photo);

        // 11. A VPN is flagged, never blocked: plenty of people run one for
        //     ordinary reasons, and the pattern is worth seeing rather than
        //     punishing.
        if ($isVpn) {
            AttendanceSecurityLog::record($tenantId, $employee->id, $branchId, 'vpn', 'flagged', $latitude ?: null, $longitude ?: null);
        }

        return [
            'message' => 'Check-in successful',
            // The company's wall clock, matching what was just stored.
            'time' => TenantClock::time($tenantId),
            'branch' => (string) $branch->name,
        ];
    }

    /**
     * @param  array<array-key, mixed>  $input  Straight off the request.
     * @param  list<string>  $allowed
     */
    private function resolveMethod(array $input, ?string $qrCode, array $allowed): string
    {
        // Older builds do not send `method` — infer it from the QR, as before.
        $requested = is_string($input['method'] ?? null) && $input['method'] !== ''
            ? (string) $input['method']
            : ($qrCode !== null && $qrCode !== '' ? 'qr_gps' : 'gps_only');

        if (! in_array($requested, AttendanceMethod::SELF_SERVICE, true)) {
            throw new ApiFailure('Unsupported check-in method', 422, 'METHOD_NOT_ALLOWED');
        }

        if (in_array($requested, $allowed, true)) {
            return $requested;
        }

        // Two near-misses get their own message, because "not allowed" would
        // leave the employee with nothing to do about it.
        if ($requested === 'qr_gps' && in_array('gps_only', $allowed, true)) {
            throw new ApiFailure('QR check-in is not enabled for this branch', 403, 'METHOD_NOT_ALLOWED');
        }

        if ($requested === 'gps_only' && in_array('qr_gps', $allowed, true)) {
            throw new ApiFailure('QR code is required for this branch', 400, 'QR_REQUIRED');
        }

        throw new ApiFailure('Self check-in is disabled for this branch', 403, 'METHOD_NOT_ALLOWED');
    }

    private function requiresLocalBiometric(int $tenantId): bool
    {
        return Value::int(DB::table('tenants')->where('id', $tenantId)->value('require_local_biometric')) === 1;
    }

    private function rejectsMockLocation(int $tenantId): bool
    {
        return Value::int(DB::table('tenants')->where('id', $tenantId)->value('reject_mock_location')) === 1;
    }

    private function block(int $tenantId, Employee $employee, int $branchId, string $reason, float $lat, float $lng): void
    {
        AttendanceSecurityLog::record($tenantId, $employee->id, $branchId, $reason, 'blocked', $lat ?: null, $lng ?: null);
    }
}
