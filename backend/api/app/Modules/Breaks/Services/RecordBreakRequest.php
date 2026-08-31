<?php

declare(strict_types=1);

namespace App\Modules\Breaks\Services;

use App\Exceptions\ApiFailure;
use App\Modules\Breaks\Domain\BreakRequests;
use App\Shared\Time\TenantClock;
use App\Support\Value;

/**
 * Validating and recording one permission request.
 *
 * Shared by the employee asking for themselves and the manager recording one on
 * somebody's behalf: the two differ in who is named and who is told, not in
 * what makes a request valid.
 */
final class RecordBreakRequest
{
    public function __construct(private readonly BreakRequests $breaks) {}

    /**
     * @param  array<array-key, mixed>  $input
     * @return array{id: int, date: string, start_time: string, end_time: string, duration_minutes: int}
     */
    public function execute(array $input, int $employeeId, int $tenantId): array
    {
        $date = Value::string($input['date'] ?? null);
        $startTime = Value::string($input['start_time'] ?? null);
        $endTime = Value::string($input['end_time'] ?? null);
        $type = trim(Value::string($input['type'] ?? null));

        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) !== 1) {
            throw new ApiFailure('date is required', 422, 'invalid_date');
        }

        foreach ([$startTime, $endTime] as $time) {
            if (preg_match('/^\d{2}:\d{2}(:\d{2})?$/', $time) !== 1) {
                throw new ApiFailure('start_time and end_time are required', 422, 'invalid_time');
            }
        }

        if (mb_strlen($type) > 100) {
            throw new ApiFailure(__('messages.request_type_too_long'), 422, 'type_too_long');
        }

        $duration = self::minutesBetween($date, $startTime, $endTime);

        if ($duration <= 0) {
            throw new ApiFailure(__('messages.end_before_start_time'), 422, 'invalid_time_range');
        }

        if ($duration > BreakRequests::MAX_DURATION_MINUTES) {
            throw new ApiFailure(__('messages.permission_too_long'), 422, 'duration_too_long');
        }

        // Judged by the company's clock, not the server's: a window that has
        // closed in Cairo has closed, whatever hour it is in UTC.
        if (BreakRequests::windowHasPassed($tenantId, $date, $endTime)) {
            throw new ApiFailure(__('messages.permission_window_passed_request'), 422, 'break_window_passed');
        }

        if ($this->breaks->overlaps($employeeId, $tenantId, $date, $startTime, $endTime)) {
            throw new ApiFailure(__('messages.permission_overlaps_existing'), 409, 'break_overlap');
        }

        $id = $this->breaks->create(
            $tenantId,
            $employeeId,
            $date,
            $startTime,
            $endTime,
            $duration,
            $type,
            Value::nullableString($input['reason'] ?? null),
            filter_var($input['deduct_from_salary'] ?? false, FILTER_VALIDATE_BOOLEAN),
        );

        return [
            'id' => $id,
            'date' => $date,
            'start_time' => $startTime,
            'end_time' => $endTime,
            'duration_minutes' => $duration,
        ];
    }

    /**
     * Both stamps are read in the company's zone, so the difference between
     * them is the same number of minutes wherever the server is.
     */
    public static function minutesBetween(string $date, string $startTime, string $endTime): int
    {
        $start = strtotime($date.' '.$startTime);
        $end = strtotime($date.' '.$endTime);

        if ($start === false || $end === false) {
            return 0;
        }

        return (int) round(($end - $start) / 60);
    }

    public static function today(int $tenantId): string
    {
        return TenantClock::date($tenantId);
    }
}
