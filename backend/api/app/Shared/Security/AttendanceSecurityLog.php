<?php

declare(strict_types=1);

namespace App\Shared\Security;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Request;
use Throwable;

/**
 * Every attendance attempt that was blocked or flagged.
 *
 * This table did not exist for the first months the anti-spoofing checks were
 * live, so every blocked attempt was silently discarded and there was no way to
 * tell a working guard from a broken one. Writing here is the point of the
 * guard, not a side effect of it.
 *
 * Never throws, for the same reason as the audit log: failing to record a
 * refusal must not turn the refusal into an acceptance.
 */
final class AttendanceSecurityLog
{
    /**
     * @param  string  $action  What was done about it — 'blocked' or 'flagged'.
     *                          A company in log-only mode records 'flagged' and
     *                          rejects nobody, which is how a threshold gets
     *                          tuned on real data before it starts refusing
     *                          people.
     */
    public static function record(
        int $tenantId,
        ?int $employeeId,
        ?int $branchId,
        string $reason,
        string $action,
        ?float $latitude = null,
        ?float $longitude = null,
    ): void {
        try {
            DB::table('attendance_security_logs')->insert([
                'tenant_id' => $tenantId,
                'employee_id' => $employeeId,
                'branch_id' => $branchId,
                'reason' => $reason,
                'action' => $action,
                'latitude' => $latitude,
                'longitude' => $longitude,
                'ip_address' => Request::ip(),
                // Client-reported, so useful for triage and worthless as
                // evidence — which is why nothing is decided on them.
                'platform' => self::header('X-Platform'),
                'app_version' => self::header('X-App-Version'),
            ]);
        } catch (Throwable $e) {
            Log::warning('Attendance security log write failed', ['reason' => $reason, 'exception' => $e]);
        }
    }

    private static function header(string $name): ?string
    {
        $value = Request::header($name);

        return is_string($value) && $value !== '' ? mb_substr($value, 0, 20) : null;
    }
}
