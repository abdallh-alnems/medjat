<?php

declare(strict_types=1);

namespace App\Services\Attendance;

use App\Domain\Attendance\AttendanceSecurityLog;
use App\Domain\Attendance\GeofenceCheck;
use App\Domain\Time\TenantClock;
use App\Models\Branch;
use App\Models\Employee;
use App\Support\Value;
use DateTimeImmutable;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Punches the app queued while it had no signal.
 *
 * Every record is re-verified here, because a queued punch is the least
 * trustworthy input the system takes: the phone chose its own timestamp and its
 * own coordinates, offline, with nothing watching. So the geofence is evaluated
 * again on arrival, a spoofed location is refused outright, and anything older
 * than a day is dropped rather than back-dated.
 *
 * One record failing never fails the batch. A queue is a whole day's punches
 * from a phone that has finally found signal, and refusing all of them because
 * one is malformed would strand the rest — each is answered individually so the
 * app can retry or discard per record.
 */
final class SyncOfflineAction
{
    /** A queue older than this is stale enough that back-dating it is a guess. */
    private const MAX_AGE_SECONDS = 86400;

    /**
     * @param  array<array-key, mixed>  $records
     * @return array{synced: int, failed: int, results: list<array<string, mixed>>}
     */
    public function execute(array $records, Employee $employee, int $tenantId): array
    {
        $synced = 0;
        $failed = 0;
        $results = [];
        $now = time();

        foreach ($records as $record) {
            if (! is_array($record)) {
                continue;
            }

            $clientId = Value::string($record['client_record_id'] ?? null, 'unknown');

            try {
                $reason = $this->reject($record, $employee, $tenantId, $now);

                if ($reason !== null) {
                    $results[] = ['client_record_id' => $clientId, 'status' => 'rejected', 'reason' => $reason];
                    $failed++;

                    continue;
                }

                $this->write($record, $employee, $tenantId);
                $results[] = ['client_record_id' => $clientId, 'status' => 'synced'];
                $synced++;
            } catch (Throwable $e) {
                Log::error('Offline sync failed for a record', ['client_record_id' => $clientId, 'exception' => $e]);
                $results[] = ['client_record_id' => $clientId, 'status' => 'rejected', 'reason' => 'SERVER_ERROR'];
                $failed++;
            }
        }

        return ['synced' => $synced, 'failed' => $failed, 'results' => $results];
    }

    /**
     * Why this record cannot be accepted, or null when it can.
     *
     * @param  array<array-key, mixed>  $record
     */
    private function reject(array $record, Employee $employee, int $tenantId, int $now): ?string
    {
        $branchId = Value::int($record['branch_id'] ?? null);
        if ($branchId <= 0) {
            return 'INVALID_BRANCH';
        }

        $branch = Branch::query()->forTenant($tenantId)->whereKey($branchId)->first();
        if ($branch === null) {
            return 'INVALID_BRANCH';
        }

        $qrCode = $record['qr_code'] ?? null;
        if ($qrCode !== null && $branch->getAttribute('qr_code') !== $qrCode) {
            return 'INVALID_QR';
        }

        $capturedAt = $this->capturedAt(Value::string($record['captured_at'] ?? null), $tenantId);
        if ($capturedAt === null) {
            return 'EXPIRED';
        }

        // A phone offline chose this timestamp itself, so a future one is either
        // a wrong clock or an attempt to book tomorrow's shift today.
        if ($capturedAt > $now) {
            return 'FUTURE_DATE';
        }

        if (($now - $capturedAt) > self::MAX_AGE_SECONDS) {
            return 'EXPIRED';
        }

        $latitude = Value::float($record['check_in_latitude'] ?? null);
        $longitude = Value::float($record['check_in_longitude'] ?? null);

        if (Value::int($record['is_mock_location'] ?? null) === 1) {
            AttendanceSecurityLog::record(
                $tenantId, $employee->id, $branchId, 'mock_location', 'blocked', $latitude ?: null, $longitude ?: null
            );

            return 'MOCK_LOCATION';
        }

        // Re-evaluated on arrival: the phone verified nothing anyone can see.
        if (! GeofenceCheck::evaluate($branch, $latitude, $longitude)->passed) {
            return 'GPS_OUT_OF_RANGE';
        }

        $date = Value::string($record['date'] ?? null);
        if ($date === '') {
            return 'INVALID_DATA';
        }

        // A punch made online while the phone thought it was offline wins. The
        // online one was verified as it happened; the queued one was not.
        $onlineExists = DB::table('attendance')
            ->where('employee_id', $employee->id)
            ->where('tenant_id', $tenantId)
            ->where('date', $date)
            ->where(function (QueryBuilder $query): void {
                $query->where('is_offline', 0)->orWhereNull('is_offline');
            })
            ->exists();

        return $onlineExists ? 'ONLINE_EXISTS' : null;
    }

    /**
     * @param  array<array-key, mixed>  $record
     */
    private function write(array $record, Employee $employee, int $tenantId): void
    {
        $date = Value::string($record['date'] ?? null);
        $checkIn = Value::nullableString($record['check_in_time'] ?? null);
        $checkOut = Value::nullableString($record['check_out_time'] ?? null);
        $latitude = Value::float($record['check_in_latitude'] ?? null);
        $longitude = Value::float($record['check_in_longitude'] ?? null);

        [$start, $end] = $this->shiftWindow($employee, $tenantId, $date);

        $late = $checkIn === null ? 0 : $this->minutesBetween($start, $checkIn);
        $worked = $checkIn !== null && $checkOut !== null ? $this->minutesBetween($checkIn, $checkOut) : 0;
        $overtime = $checkIn !== null && $checkOut !== null ? $this->minutesBetween($end, $checkOut) : 0;

        DB::table('attendance')->upsert(
            [[
                'tenant_id' => $tenantId,
                'branch_id' => Value::int($record['branch_id'] ?? null),
                'employee_id' => $employee->id,
                'date' => $date,
                'check_in_time' => $checkIn,
                'check_out_time' => $checkOut,
                'check_in_latitude' => $latitude ?: null,
                'check_in_longitude' => $longitude ?: null,
                'check_in_method' => 'offline',
                'status' => 'present',
                'is_offline' => 1,
                'synced_at' => DB::raw('NOW()'),
                'late_minutes' => $late,
                'worked_minutes' => $worked,
                'overtime_minutes' => $overtime,
                'is_vpn' => Value::int($record['is_vpn'] ?? null) === 1 ? 1 : 0,
            ]],
            ['tenant_id', 'employee_id', 'date'],
            // Only a record that actually carries a departure updates the
            // totals. A queue often holds the arrival and the departure as two
            // separate records, and the arrival arriving second must not wipe
            // the hours the departure already computed.
            $checkOut === null
                ? ['synced_at']
                : ['check_out_time', 'check_out_method', 'synced_at', 'worked_minutes', 'overtime_minutes'],
        );
    }

    /**
     * @return array{string, string}
     */
    private function shiftWindow(Employee $employee, int $tenantId, string $date): array
    {
        $shift = DB::table('employee_shift_schedule as ess')
            ->leftJoin('shifts as s', 's.id', '=', 'ess.shift_id')
            ->where('ess.employee_id', $employee->id)
            ->where('ess.tenant_id', $tenantId)
            ->where('ess.work_date', $date)
            ->where('ess.status', 'published')
            ->first(['s.start_time', 's.end_time']);

        return [
            Value::string($shift?->start_time) ?: Value::string($employee->getAttribute('work_start_time'), '09:00:00'),
            Value::string($shift?->end_time) ?: Value::string($employee->getAttribute('work_end_time'), '17:00:00'),
        ];
    }

    private function minutesBetween(string $from, string $to): int
    {
        $fromAt = strtotime($from);
        $toAt = strtotime($to);

        return $fromAt === false || $toAt === false ? 0 : (int) max(0, ($toAt - $fromAt) / 60);
    }

    /**
     * When the phone captured this, as a timestamp.
     *
     * A naive string is read in the *company's* zone, not the server's. The
     * phone was offline in Cairo and wrote its own wall clock; parsing that as
     * UTC puts it three hours in the future and every queued punch is rejected
     * as a future date. A string that carries its own offset is respected as
     * sent.
     */
    private function capturedAt(string $raw, int $tenantId): ?int
    {
        if ($raw === '') {
            return null;
        }

        $carriesOffset = preg_match('/(Z|[+-]\d{2}:?\d{2})$/', trim($raw)) === 1;

        try {
            $moment = $carriesOffset
                ? new DateTimeImmutable($raw)
                : new DateTimeImmutable($raw, TenantClock::zone($tenantId));
        } catch (Throwable) {
            return null;
        }

        return $moment->getTimestamp();
    }
}
