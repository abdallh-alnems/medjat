<?php

declare(strict_types=1);

namespace App\Domain\Leave;

use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * How many annual leave days somebody has left.
 *
 * Computed rather than stored, so it cannot drift from the leave records it is
 * derived from. Three inputs: the entitlement, whatever was carried over from
 * last year, and what has already been taken.
 */
final class LeaveBalance
{
    /**
     * Egyptian labour law raises the entitlement after ten years' service.
     * Applied only when the company opts in, because it is a floor rather than
     * a rule everywhere this ships.
     */
    private const SENIORITY_MONTHS = 120;

    private const SENIORITY_DAYS = 30;

    /**
     * @return array{
     *     year: int, entitlement_days: int, carried_over_days: int,
     *     total_days: int, used_days: int, remaining_days: int
     * }
     */
    public static function forEmployee(int $employeeId, int $tenantId, int $year): array
    {
        $entitlement = self::entitlementDays($employeeId, $tenantId);
        $carried = Value::int(
            DB::table('leave_year_balances')
                ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)->where('year', $year)
                ->value('carried_over_days')
        );

        // Counted from the leave records themselves, inclusive of both ends: a
        // one-day leave is one day, not zero.
        $used = Value::int(
            DB::table('leaves')
                ->where('employee_id', $employeeId)
                ->where('tenant_id', $tenantId)
                ->where('type', 'annual')
                ->where('status', 'approved')
                ->whereRaw('YEAR(date) = ?', [$year])
                ->selectRaw('COALESCE(SUM(DATEDIFF(end_date, start_date) + 1), 0) as used')
                ->value('used')
        );

        $total = $entitlement + $carried;

        return [
            'year' => $year,
            'entitlement_days' => $entitlement,
            'carried_over_days' => $carried,
            'total_days' => $total,
            'used_days' => $used,
            // Never negative: an over-taken balance is a payroll question, not a
            // number to show somebody as minus three days.
            'remaining_days' => max(0, $total - $used),
        ];
    }

    private static function entitlementDays(int $employeeId, int $tenantId): int
    {
        $row = DB::table('employees as e')
            ->join('tenants as t', 't.id', '=', 'e.tenant_id')
            ->where('e.id', $employeeId)
            ->where('e.tenant_id', $tenantId)
            ->first([
                DB::raw('COALESCE(e.annual_leave_days, t.default_annual_leave_days, 0) as entitlement_days'),
                'e.hire_date',
                't.apply_legal_seniority_entitlement',
            ]);

        if ($row === null) {
            return 21;
        }

        $days = Value::int($row->entitlement_days, 21);

        if (Value::int($row->apply_legal_seniority_entitlement) === 1
            && self::tenureMonths(Value::nullableString($row->hire_date)) >= self::SENIORITY_MONTHS) {
            // A floor, not a replacement: a company already granting more keeps
            // granting more.
            $days = max($days, self::SENIORITY_DAYS);
        }

        return $days;
    }

    private static function tenureMonths(?string $hireDate): int
    {
        if ($hireDate === null || $hireDate === '') {
            return 0;
        }

        $hiredAt = strtotime($hireDate);
        if ($hiredAt === false) {
            return 0;
        }

        return (int) floor((time() - $hiredAt) / (30.44 * 86400));
    }
}
