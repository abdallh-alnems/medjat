<?php

declare(strict_types=1);

namespace App\Http\Controllers\Kiosk;

use App\Domain\Attendance\AttendanceMethod;
use App\Domain\Kiosk\KioskEmployeeCode;
use App\Domain\Kiosk\RecognitionLog;
use App\Domain\Time\TenantClock;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Branch;
use App\Models\Employee;
use App\Services\Kiosk\IdentifyAction;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;

/**
 * Ports of api/app/kiosk/{identify,identify_by_code}.php.
 *
 * Two ways to answer "who is this?" — a face, or the six digits somebody types
 * when the camera did not recognise them. Both end at the same short-lived
 * punch ticket, so the punch step has one contract.
 */
final class IdentifyController
{
    /** Ten wrong codes in five minutes is not somebody mistyping. */
    private const CODE_ATTEMPTS = 10;

    private const CODE_WINDOW_SECONDS = 300;

    private const TICKET_TTL_SECONDS = 30;

    public function __construct(private readonly IdentifyAction $identify) {}

    public function byFace(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $stationId = Value::int($request->attributes->get('station_id'));
        $branch = self::branch($request);

        $result = $this->identify->execute($request->all(), $branch, $tenantId, $stationId);

        $logId = RecognitionLog::record(
            $result['log'] + ['tenant_id' => $tenantId, 'station_id' => $stationId, 'branch_id' => $branch->id],
            $result['capture_ttl'],
        );

        // A failed identification is a normal result of a normal interaction —
        // somebody stood in front of a camera and was not recognised — so it
        // answers 200 with an outcome the tablet renders as guidance.
        if ($result['outcome'] === 'matched') {
            return ApiResponse::success($result['payload'] + ['recognition_log_id' => $logId]);
        }

        return ApiResponse::success($result['payload'] + [
            'code_fallback_available' => self::codeFallbackEnabled($branch),
        ]);
    }

    public function byCode(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $stationId = Value::int($request->attributes->get('station_id'));
        $branch = self::branch($request);

        if (! self::codeFallbackEnabled($branch)) {
            throw new ApiFailure(__('messages.kiosk_code_disabled'), 422, 'kiosk_code_disabled');
        }

        $log = static fn (string $result, ?int $employeeId = null, bool $accepted = false): int => RecognitionLog::record([
            'tenant_id' => $tenantId,
            'station_id' => $stationId,
            'branch_id' => $branch->id,
            'employee_id' => $employeeId,
            'purpose' => 'check_in',
            'method' => 'code',
            'result' => $result,
            'accepted' => $accepted,
        ]);

        // Throttled per station, not per IP: every tablet at a company may
        // share one address, so an IP limit would let one abused kiosk lock out
        // every other branch.
        if (RateLimiter::tooManyAttempts('kiosk_code_'.$stationId, self::CODE_ATTEMPTS)) {
            $log('no_match');
            $this->flagBruteForce($tenantId, $branch->id, $request->ip());

            throw new ApiFailure(__('messages.kiosk_code_throttled'), 429, 'kiosk_code_throttled');
        }

        RateLimiter::hit('kiosk_code_'.$stationId, self::CODE_WINDOW_SECONDS);

        $code = trim(Value::string($request->input('code')));

        if ($code === '') {
            throw new ApiFailure('code is required', 422, 'code_required');
        }

        $match = KioskEmployeeCode::resolve($code, $tenantId, $branch->id);

        if ($match === null) {
            $log('no_match');

            return self::guidance('no_match', 'kiosk_code_invalid');
        }

        $employeeId = Value::int($match['id'] ?? null);
        $employee = Employee::query()->where('id', $employeeId)->where('tenant_id', $tenantId)->first();

        if ($employee === null) {
            $log('no_match');

            return self::guidance('no_match', 'kiosk_code_invalid');
        }

        // The code identified them, but the same gates as the face path apply.
        if (! in_array('kiosk', AttendanceMethod::resolveFor($employee, $tenantId), true)) {
            $log('wrong_method', $employeeId);

            return self::guidance('wrong_method', 'kiosk_wrong_method');
        }

        $today = TenantClock::date($tenantId);
        $existing = DB::table('attendance')
            ->where('employee_id', $employeeId)->where('date', $today)->where('tenant_id', $tenantId)
            ->first(['check_in_time', 'check_out_time']);

        $checkedIn = $existing !== null && Value::string($existing->check_in_time) !== '';
        $nextAction = $checkedIn ? 'check_out' : 'check_in';

        if ($nextAction === 'check_out' && $existing !== null && Value::string($existing->check_out_time) !== '') {
            $log('too_soon', $employeeId);

            return self::guidance('too_soon', 'kiosk_too_soon');
        }

        $ticket = bin2hex(random_bytes(32));
        DB::insert(
            'INSERT INTO face_challenges (tenant_id, employee_id, nonce, challenge, purpose, expires_at)'
            ." VALUES (?, ?, ?, 'blink', 'check_in', DATE_ADD(NOW(), INTERVAL ? SECOND))",
            [$tenantId, $employeeId, $ticket, self::TICKET_TTL_SECONDS],
        );

        return ApiResponse::success([
            'outcome' => 'matched',
            'method' => 'code',
            'recognition_log_id' => $log('matched', $employeeId, true),
            'employee' => [
                'id' => $employeeId,
                'name' => $employee->name,
                'photo_url' => $employee->getAttribute('face_photo_url'),
            ],
            'next_action' => $nextAction,
            'current_state' => ['checked_in_at' => $existing->check_in_time ?? null],
            'punch_ticket' => $ticket,
            'ticket_expires_in_seconds' => self::TICKET_TTL_SECONDS,
        ]);
    }

    /**
     * A person cannot type ten wrong six-digit codes in five minutes by
     * accident, so this is recorded as a security event rather than a mistake.
     */
    private function flagBruteForce(int $tenantId, int $branchId, ?string $ip): void
    {
        $employeeId = DB::table('employees')
            ->where('tenant_id', $tenantId)->where('branch_id', $branchId)
            ->value('id');

        if ($employeeId === null) {
            return;
        }

        DB::table('attendance_security_logs')->insert([
            'tenant_id' => $tenantId,
            'employee_id' => Value::int($employeeId),
            'branch_id' => $branchId,
            'reason' => 'kiosk_pin_bruteforce',
            'action' => 'blocked',
            'ip_address' => $ip,
        ]);
    }

    private static function guidance(string $outcome, string $messageKey): JsonResponse
    {
        return ApiResponse::success([
            'outcome' => $outcome,
            'message_key' => $messageKey,
            'code_fallback_available' => true,
        ]);
    }

    private static function codeFallbackEnabled(Branch $branch): bool
    {
        return Value::int($branch->getAttribute('station_code_fallback_enabled'), 1) === 1;
    }

    private static function branch(Request $request): Branch
    {
        $branch = Branch::query()
            ->where('id', Value::int($request->attributes->get('branch_id')))
            ->where('tenant_id', Value::int($request->attributes->get('tenant_id')))
            ->first();

        if ($branch === null || Value::int($branch->getAttribute('station_enabled')) !== 1) {
            throw new ApiFailure(__('messages.kiosk_pair_branch_disabled'), 403, 'kiosk_pair_branch_disabled');
        }

        return $branch;
    }
}
