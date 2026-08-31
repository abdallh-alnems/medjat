<?php

declare(strict_types=1);

namespace App\Modules\Leave\Domain;

use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * How much annual leave somebody has left.
 *
 * Entitlement is the employee's own figure, or the company default. Egyptian
 * labour law then raises it to at least thirty days after ten years of service,
 * which companies opt into — the law applies to them whether or not they tick
 * the box, but the system will not impose another country's statute on a
 * company that is not in Egypt.
 *
 * Carried days sit on top, and used days come off. The result never goes below
 * zero: an over-drawn balance is a payroll question, not a leave one.
 */
final class LeaveBalanceCalculator
{
    private const SENIORITY_MONTHS = 120;

    private const SENIORITY_DAYS = 30;

    /**
     * @return array<string, mixed>
     */
    public function forYear(int $employeeId, int $tenantId, int $year): array
    {
        $row = DB::table('employees as e')
            ->join('tenants as t', 't.id', '=', 'e.tenant_id')
            ->where('e.id', $employeeId)->where('e.tenant_id', $tenantId)
            ->first([
                DB::raw('COALESCE(e.annual_leave_days, t.default_annual_leave_days, 0) AS entitlement_days'),
                'e.hire_date',
                't.apply_legal_seniority_entitlement',
            ]);

        // 21 rather than 0 when the employee cannot be found: showing somebody
        // a zero entitlement reads as "you have no leave", which is a claim.
        $entitlement = $row === null ? 21 : Value::int($row->entitlement_days);

        if ($row !== null && Value::int($row->apply_legal_seniority_entitlement) === 1) {
            $tenure = CarryoverPolicy::tenureMonths(Value::nullableString($row->hire_date));

            if ($tenure >= self::SENIORITY_MONTHS) {
                $entitlement = max($entitlement, self::SENIORITY_DAYS);
            }
        }

        $carried = Value::int(
            DB::table('leave_year_balances')
                ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)->where('year', $year)
                ->value('carried_over_days')
        );

        // Inclusive day count, in SQL so the arithmetic runs where the dates
        // live rather than being reconstructed from strings.
        $used = Value::int(
            DB::table('leaves')
                ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
                ->where('type', 'annual')->where('status', 'approved')
                ->whereRaw('YEAR(date) = ?', [$year])
                ->selectRaw('COALESCE(SUM(DATEDIFF(end_date, start_date) + 1), 0) AS used_days')
                ->value('used_days')
        );

        $total = $entitlement + $carried;

        return [
            'year' => $year,
            'entitlement_days' => $entitlement,
            'carried_over_days' => $carried,
            'total_days' => $total,
            'used_days' => $used,
            'remaining_days' => max(0, $total - $used),
            // Carried days no longer expire; the field stays so older clients
            // that read it keep working.
            'carryover_expired' => false,
        ];
    }
}
