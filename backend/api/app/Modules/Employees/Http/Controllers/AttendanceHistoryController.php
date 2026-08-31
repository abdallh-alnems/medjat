<?php

declare(strict_types=1);

namespace App\Modules\Employees\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Modules\Employees\Services\AttendanceCalendar;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Port of api/app/employees/get_attendance_history.php.
 */
final class AttendanceHistoryController
{
    /** A careless range must not be able to pull years of rows. */
    private const MAX_DAYS = 366;

    public function __construct(private readonly AttendanceCalendar $calendar) {}

    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->query('employee_id'));

        if ($employeeId <= 0) {
            throw new ApiFailure('Employee ID required', 422, 'employee_id_required');
        }

        if (! Employee::query()->forTenant($tenantId)->whereKey($employeeId)->exists()) {
            throw new ApiFailure('Employee not found', 404);
        }

        [$from, $to] = $this->range($request);

        // Best-effort: the calendar renders correct statuses regardless, and a
        // failure here must not cost somebody the view of their own month.
        try {
            $this->calendar->catchUpAbsences($tenantId, $from, $to);
        } catch (Throwable $e) {
            Log::warning('Absence catch-up failed', ['tenant_id' => $tenantId, 'exception' => $e]);
        }

        $records = $this->calendar->build($employeeId, $tenantId, $from, $to);

        return ApiResponse::success([
            'records' => $records,
            'summary' => $this->summarise($records),
            'from' => $from,
            'to' => $to,
        ]);
    }

    /**
     * Either a month, or an explicit range. The month form is what the tabs
     * send and the range form is what the custom picker sends.
     *
     * @return array{string, string}
     */
    private function range(Request $request): array
    {
        $from = Value::string($request->query('from'));
        $to = Value::string($request->query('to'));

        if ($from === '' || $to === '') {
            $month = Value::string($request->query('month'), date('Y-m'));

            if (preg_match('/^\d{4}-\d{2}$/', $month) !== 1) {
                throw new ApiFailure('Invalid month format (expected YYYY-MM)', 422, 'invalid_month_format_expected_yyyy');
            }

            $from = $month.'-01';
            $to = date('Y-m-t', (int) strtotime($from));
        }

        foreach ([$from, $to] as $date) {
            if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) !== 1) {
                throw new ApiFailure('Invalid date format (expected YYYY-MM-DD)', 422, 'invalid_date_format_expected_yyyy');
            }
        }

        if (strtotime($from) > strtotime($to)) {
            throw new ApiFailure('Start date must be on or before end date', 422, 'start_date_before_end_date');
        }

        if (((int) strtotime($to) - (int) strtotime($from)) / 86400 > self::MAX_DAYS) {
            throw new ApiFailure('Date range cannot exceed 366 days', 422, 'date_range_cannot_exceed_366');
        }

        return [$from, $to];
    }

    /**
     * @param  list<array<string, mixed>>  $records
     * @return array<string, int>
     */
    private function summarise(array $records): array
    {
        $summary = [
            'present' => 0, 'absent' => 0, 'late' => 0, 'leave' => 0,
            'holiday' => 0, 'weekly_off' => 0, 'not_arrived' => 0,
            'worked_minutes' => 0, 'overtime_minutes' => 0, 'late_minutes' => 0,
        ];

        foreach ($records as $record) {
            $status = Value::string($record['status'] ?? null);
            $late = Value::int($record['late_minutes'] ?? null);

            // A late arrival counts as late rather than present: the two
            // together would always equal the headcount and tell nobody
            // anything.
            if ($status === 'present') {
                $summary[$late > 0 ? 'late' : 'present']++;
            } elseif (array_key_exists($status, $summary)) {
                $summary[$status]++;
            }

            $summary['worked_minutes'] += Value::int($record['worked_minutes'] ?? null);
            $summary['overtime_minutes'] += Value::int($record['overtime_minutes'] ?? null);
            $summary['late_minutes'] += $late;
        }

        return $summary;
    }
}
