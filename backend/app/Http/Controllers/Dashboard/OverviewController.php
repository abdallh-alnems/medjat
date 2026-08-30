<?php

declare(strict_types=1);

namespace App\Http\Controllers\Dashboard;

use App\Domain\Attendance\AbsenceBackfill;
use App\Domain\Dashboard\LiveBoard;
use App\Domain\Employees\ComplianceExpiry;
use App\Domain\Leave\LeaveRequests;
use App\Domain\Payroll\PayrollLedger;
use App\Domain\Time\TenantClock;
use App\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Port of api/app/dashboard/overview.php.
 *
 * The home screen: today's attendance, the queues waiting on somebody, and
 * this month's payroll so far.
 */
final class OverviewController
{
    /** How far ahead a document counts as "expiring" for the alert. */
    private const COMPLIANCE_WINDOW_DAYS = 30;

    public function __construct(private readonly PayrollLedger $payroll) {}

    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $now = TenantClock::now($tenantId);
        $today = $now->format('Y-m-d');
        $yesterday = $now->modify('-1 day')->format('Y-m-d');

        $branchId = self::filter($request->query('branch_id'));

        // Absences are materialised on open rather than waiting for the nightly
        // cron, so the board reflects today's no-shows now. Never at the cost
        // of the dashboard itself: a failure here loses the freshness, not the
        // screen.
        try {
            AbsenceBackfill::run($tenantId, $today, $now->format('H:i:s'));
        } catch (Throwable $e) {
            Log::warning('Absence catch-up failed on dashboard open', [
                'tenant_id' => $tenantId,
                'exception' => $e,
            ]);
        }

        $rows = LiveBoard::rows(
            $tenantId,
            $today,
            $branchId,
            self::filter($request->query('shift_id')),
            self::filter($request->query('category_id')),
        );

        $onLeave = LeaveRequests::employeesOnLeave($tenantId, $today);

        $present = 0;
        $absent = 0;
        $late = 0;
        $onLeaveCount = 0;
        $branches = [];

        foreach ($rows as $row) {
            $employeeId = Value::int($row['employee_id'] ?? null);
            $status = Value::nullableString($row['attendance_status'] ?? null);
            $isPresent = Value::nullableString($row['check_in_time'] ?? null) !== null;
            $isLate = $isPresent && Value::int($row['late_minutes'] ?? null) > 0;

            // "Absent" means a confirmed absence — a row somebody or the
            // backfill actually wrote. An active employee with no record has
            // simply not arrived yet, so the two never double-count.
            if ($isPresent) {
                $bucket = 'present';
            } elseif (in_array($status, LiveBoard::OFF_STATUSES, true) || isset($onLeave[$employeeId])) {
                $bucket = 'leave';
            } elseif ($status === 'absent') {
                $bucket = 'absent';
            } else {
                $bucket = 'not_in';
            }

            $present += $bucket === 'present' ? 1 : 0;
            $onLeaveCount += $bucket === 'leave' ? 1 : 0;
            $absent += $bucket === 'absent' ? 1 : 0;
            $late += $isLate ? 1 : 0;

            $key = Value::int($row['branch_id'] ?? null);

            $branches[$key] ??= [
                'branch_id' => $key,
                'branch_name' => Value::string($row['branch_name'] ?? null),
                'total_employees' => 0,
                'present' => 0,
                'absent' => 0,
                'late' => 0,
            ];

            $branches[$key]['total_employees']++;
            $branches[$key]['present'] += $bucket === 'present' ? 1 : 0;
            $branches[$key]['absent'] += $bucket === 'absent' ? 1 : 0;
            $branches[$key]['late'] += $isLate ? 1 : 0;
        }

        $month = $now->format('Y-m');
        $payroll = $this->payroll->summary($tenantId, $month);

        return ApiResponse::success([
            // The true headcount, unfiltered — it drives the first-run empty
            // state, which a branch filter must not make look like a company
            // with no employees.
            'total_employees' => DB::table('employees')->where('tenant_id', $tenantId)->count(),
            // The denominator for the rates, so they stay right under a filter.
            'active_in_scope' => count($rows),
            'present_today' => $present,
            'present_yesterday' => $this->presentOn($tenantId, $yesterday, $branchId),
            'absent_today' => $absent,
            'late_today' => $late,
            'on_leave_today' => $onLeaveCount,
            'branch_stats' => self::withRates($branches),
            'total_branches' => DB::table('branches')->where('tenant_id', $tenantId)->count(),
            // The queues are deliberately company-wide: an approval waiting on
            // you is waiting whichever branch the board is filtered to, and the
            // apps say so beside the numbers.
            'pending_leaves' => $this->pending('leaves', $tenantId),
            'pending_loans' => $this->pending('employee_loans', $tenantId),
            'pending_breaks' => $this->pending('break_requests', $tenantId),
            'assets_to_return' => DB::table('asset_custody')
                ->where('tenant_id', $tenantId)->where('status', 'return_requested')->count(),
            'expiring_compliance' => count(
                ComplianceExpiry::within($tenantId, self::COMPLIANCE_WINDOW_DAYS, null, true)
            ),
            'payroll_summary' => [
                'employee_count' => Value::int($payroll['employee_count'] ?? null),
                'total_base' => Value::float($payroll['total_base'] ?? null),
                'total_deductions' => Value::float($payroll['total_deductions'] ?? null),
                'total_bonuses' => Value::float($payroll['total_bonuses'] ?? null),
                'total_net' => Value::float($payroll['total_net'] ?? null),
            ],
            'current_month' => $month,
        ]);
    }

    private function pending(string $table, int $tenantId): int
    {
        return DB::table($table)->where('tenant_id', $tenantId)->where('status', 'pending')->count();
    }

    private function presentOn(int $tenantId, string $date, ?int $branchId): int
    {
        return DB::table('attendance as a')
            ->join('employees as e', 'e.id', '=', 'a.employee_id')
            ->where('a.tenant_id', $tenantId)
            ->where('a.date', $date)
            ->whereNotNull('a.check_in_time')
            ->when($branchId !== null, fn ($q) => $q->where('e.branch_id', $branchId))
            ->count();
    }

    /**
     * @param  array<int, array<string, mixed>>  $branches
     * @return list<array<string, mixed>>
     */
    private static function withRates(array $branches): array
    {
        return array_values(array_map(static function (array $branch): array {
            $total = Value::int($branch['total_employees'] ?? null);

            $branch['attendance_rate'] = $total > 0
                ? round(Value::int($branch['present'] ?? null) / $total * 100, 1)
                : 0;
            $branch['late_rate'] = $total > 0
                ? round(Value::int($branch['late'] ?? null) / $total * 100, 1)
                : 0;

            return $branch;
        }, $branches));
    }

    private static function filter(mixed $raw): ?int
    {
        $id = Value::int($raw);

        return $id > 0 ? $id : null;
    }
}
