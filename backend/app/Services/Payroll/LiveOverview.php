<?php

declare(strict_types=1);

namespace App\Services\Payroll;

use App\Domain\Payroll\PayrollCalculator;
use App\Domain\Time\TenantClock;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Month-to-date pay for everybody, computed and never written.
 *
 * This is the payroll screen's main view, and it deliberately shows two
 * different numbers per person: what they have earned so far in the cycle, and
 * what the full cycle projects to. The first is what somebody would be owed if
 * the month stopped today; the second is the figure that can be compared with
 * last month's completed cycle without the comparison being nonsense.
 */
final class LiveOverview
{
    public function __construct(private readonly PayrollCalculator $calculator) {}

    /**
     * @return array{items: list<array<string, mixed>>, total_count: int}
     */
    public function forMonth(int $tenantId, string $month, ?int $branchId, ?int $limit, int $offset): array
    {
        $employees = DB::table('employees as e')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->where('e.tenant_id', $tenantId)
            ->where('e.status', 'active')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId))
            ->orderBy('e.name')
            ->when($limit !== null && $limit > 0, fn (QueryBuilder $q): QueryBuilder => $q->limit((int) $limit)->offset(max(0, $offset)))
            ->get([
                'e.id', 'e.name', 'e.job_title', 'e.branch_id', 'e.shift_id', 'e.hire_date',
                'b.name as branch_name',
                DB::raw('(SELECT GROUP_CONCAT(category_id) FROM employee_category_assignments WHERE employee_id = e.id) AS category_ids'),
            ]);

        $saved = $this->savedSlips($tenantId, $month);
        $previous = $this->previousTotals($tenantId, self::previousMonth($month));
        $today = TenantClock::date($tenantId);

        $items = [];

        foreach ($employees as $employee) {
            $employeeId = Value::int($employee->id);
            $calculation = $this->calculator->calculate($employeeId, $month, $tenantId, $today);

            if ($calculation === []) {
                continue;
            }

            // Somebody hired after this cycle ended did not exist during the
            // period the row would describe, so there is no row to show.
            $hireDate = Value::nullableString($employee->hire_date);
            if ($hireDate !== null && $hireDate > Value::string($calculation['cycle_end'] ?? null)) {
                continue;
            }

            $slip = $saved[$employeeId] ?? null;
            $prior = $previous[$employeeId] ?? null;

            $items[] = [
                'id' => $slip === null ? 0 : Value::int($slip['id'] ?? null),
                'employee_id' => $employeeId,
                'employee_name' => $employee->name,
                'job_title' => $employee->job_title,
                'branch_id' => Value::nullableInt($employee->branch_id),
                'branch_name' => $employee->branch_name,
                'shift_id' => Value::nullableInt($employee->shift_id),
                'category_ids' => self::categoryIds($employee->category_ids),
                'month' => $month,
                'base_salary' => $calculation['base_salary'],
                'total_deductions' => $calculation['total_deductions'],
                'total_bonuses' => $calculation['total_bonuses'],
                // Earned so far: base prorated by the days elapsed in the
                // cycle, less deductions, plus bonuses.
                'net_salary' => $calculation['earned_to_date'],
                // The full-cycle projection, on full base — the one that can be
                // set beside a completed month without misleading anybody.
                'projected_net' => $calculation['net_salary'],
                'prorated_base_salary' => $calculation['prorated_base_salary'],
                'cycle_start' => $calculation['cycle_start'],
                'cycle_end' => $calculation['cycle_end'],
                'days_in_cycle' => $calculation['days_in_cycle'],
                'days_elapsed' => $calculation['days_elapsed'],
                'status' => $slip === null ? 'live' : $slip['status'] ?? 'live',
                'paid_at' => $slip === null ? null : $slip['paid_at'] ?? null,
                // The per-line detail travels with the tile so expanding it
                // shows *why* the totals look like they do without a round trip
                // back to the employee's profile.
                'deductions_breakdown' => $calculation['deductions_breakdown'] ?? [],
                'bonuses_breakdown' => $calculation['bonuses_breakdown'] ?? [],
                'previous_net' => $prior['net'] ?? null,
                'previous_deductions' => $prior['deductions'] ?? null,
                'previous_bonuses' => $prior['bonuses'] ?? null,
            ];
        }

        $totalCount = DB::table('employees')
            ->where('tenant_id', $tenantId)->where('status', 'active')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('branch_id', $branchId))
            ->count();

        return ['items' => $items, 'total_count' => $totalCount];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function savedSlips(int $tenantId, string $month): array
    {
        $slips = [];

        $rows = DB::table('payroll')
            ->where('tenant_id', $tenantId)->where('month', $month)
            ->get(['employee_id', 'id', 'status', 'paid_at']);

        foreach ($rows as $row) {
            /** @var array<string, mixed> $columns */
            $columns = (array) $row;
            $slips[Value::int($row->employee_id)] = $columns;
        }

        return $slips;
    }

    /**
     * @return array<int, array{net: float, deductions: float, bonuses: float}>
     */
    private function previousTotals(int $tenantId, string $month): array
    {
        $totals = [];

        $rows = DB::table('payroll')
            ->where('tenant_id', $tenantId)->where('month', $month)
            ->get(['employee_id', 'net_salary', 'total_deductions', 'total_bonuses']);

        foreach ($rows as $row) {
            $totals[Value::int($row->employee_id)] = [
                'net' => Value::float($row->net_salary),
                'deductions' => Value::float($row->total_deductions),
                'bonuses' => Value::float($row->total_bonuses),
            ];
        }

        return $totals;
    }

    /**
     * The calendar-previous month, which is also the cycle-previous one because
     * cycles are addressed by label month throughout.
     */
    public static function previousMonth(string $month): string
    {
        $year = (int) substr($month, 0, 4);
        $number = (int) substr($month, 5, 2);

        return sprintf('%04d-%02d', $number === 1 ? $year - 1 : $year, $number === 1 ? 12 : $number - 1);
    }

    /**
     * @return list<int>
     */
    private static function categoryIds(mixed $concatenated): array
    {
        $raw = Value::nullableString($concatenated);

        if ($raw === null || $raw === '') {
            return [];
        }

        $ids = [];
        foreach (explode(',', $raw) as $id) {
            $parsed = (int) trim($id);
            if ($parsed > 0) {
                $ids[] = $parsed;
            }
        }

        return $ids;
    }
}
