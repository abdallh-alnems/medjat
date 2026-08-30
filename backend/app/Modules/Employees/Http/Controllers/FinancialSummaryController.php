<?php

declare(strict_types=1);

namespace App\Modules\Employees\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Modules\Payroll\Domain\PayrollCalculator;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/employees/get_financial_summary.php.
 *
 * Everything the financial tab shows about one person for one month: the
 * figures, the attendance those figures came from, the rules that produced
 * them, their outstanding loans, and the history of both their slips and their
 * salary.
 *
 * The governing rule is what "current" means. A draft month shows the live
 * estimate, recomputed and clamped to today. An approved or paid month shows
 * the snapshot frozen at approval, because what HR is looking at then is a
 * decision that was already made — recalculating it would quietly disagree with
 * the payslip the employee is holding.
 */
final class FinancialSummaryController
{
    public function __construct(private readonly PayrollCalculator $calculator) {}

    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->query('employee_id'));
        $month = Value::string($request->query('month'), '') ?: substr(TenantClock::date($tenantId), 0, 7);

        if ($employeeId <= 0) {
            throw new ApiFailure('Employee ID required', 422, 'employee_id_required');
        }
        if (preg_match('/^\d{4}-\d{2}$/', $month) !== 1) {
            throw new ApiFailure('Invalid month format (expected YYYY-MM)', 422, 'invalid_month_format_expected_yyyy');
        }

        $employee = DB::table('employees')
            ->where('id', $employeeId)->where('tenant_id', $tenantId)
            ->first(['id', 'name', 'base_salary', 'branch_id']);

        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        $live = $this->calculator->calculate($employeeId, $month, $tenantId, TenantClock::date($tenantId));
        $slip = $this->slip($employeeId, $month, $tenantId);

        $status = $slip === null ? 'draft' : Value::string($slip['status'] ?? null, 'draft');
        $locked = in_array($status, ['approved', 'paid'], true);
        $frozen = $locked ? self::decode($slip['breakdown'] ?? null) : null;
        $figures = $frozen ?? $live;

        // The attendance window follows the live cycle even for a locked month:
        // it explains how the days were spent, and the frozen snapshot does not
        // carry that detail.
        $from = Value::string($live['cycle_start'] ?? null) ?: $month.'-01';
        $to = Value::string($live['effective_end'] ?? null) ?: $from;

        return ApiResponse::success([
            'month' => $month,
            'employee' => [
                'id' => Value::int($employee->id),
                'name' => $employee->name,
                'base_salary' => Value::float($employee->base_salary),
            ],
            'current' => [
                'base_salary' => $figures['base_salary'] ?? 0,
                'total_deductions' => $figures['total_deductions'] ?? 0,
                'total_bonuses' => $figures['total_bonuses'] ?? 0,
                'net_salary' => $figures['net_salary'] ?? 0,
                'deductions' => $figures['deductions_breakdown'] ?? [],
                'bonuses' => $figures['bonuses_breakdown'] ?? [],
                'statutory' => $figures['statutory_breakdown'] ?? null,
                'status' => $status,
                'locked' => $locked,
                'payroll_id' => $slip === null ? null : Value::int($slip['id'] ?? null),
                'approved_at' => $slip['approved_at'] ?? null,
                'approved_by_name' => $slip['approved_by_name'] ?? null,
                'paid_at' => $slip['paid_at'] ?? null,
                'cycle_start_day' => $this->cycleStartDay($tenantId, Value::nullableInt($employee->branch_id)),
                'cycle_from' => $figures['cycle_start'] ?? null,
                'cycle_to' => $figures['cycle_end'] ?? null,
                'days_in_month' => $figures['days_in_cycle'] ?? 0,
                'days_elapsed' => $figures['days_elapsed'] ?? 0,
                'prorated_base_salary' => $figures['prorated_base_salary'] ?? 0,
                'earned_to_date' => $figures['earned_to_date'] ?? 0,
                'attendance' => $this->attendance($employeeId, $tenantId, $from, $to),
                'rules' => $this->publicRules($tenantId),
            ],
            'loans' => $this->loans($employeeId, $tenantId),
            'salary_history' => $this->salaryHistory($employeeId, $tenantId),
            'history' => $this->slipHistory($employeeId, $tenantId),
        ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    private function slip(int $employeeId, string $month, int $tenantId): ?array
    {
        $row = DB::table('payroll as p')
            ->leftJoin('admins as a', 'a.id', '=', 'p.approved_by')
            ->where('p.employee_id', $employeeId)->where('p.month', $month)->where('p.tenant_id', $tenantId)
            ->first(['p.*', 'a.name as approved_by_name']);

        return $row === null ? null : self::toArray($row);
    }

    private function cycleStartDay(int $tenantId, ?int $branchId): int
    {
        if ($branchId !== null) {
            $branch = DB::table('branches')
                ->where('id', $branchId)->where('tenant_id', $tenantId)->value('cycle_start_day');

            if ($branch !== null) {
                return Value::int($branch, 1);
            }
        }

        return Value::int(DB::table('tenants')->where('id', $tenantId)->value('cycle_start_day'), 1);
    }

    /**
     * How the days in the window were spent.
     *
     * A late arrival counts as late rather than present: the tab exists to show
     * why the money looks the way it does, and folding lateness into "present"
     * hides the very thing the deduction came from.
     *
     * @return array<string, int>
     */
    private function attendance(int $employeeId, int $tenantId, string $from, string $to): array
    {
        $counts = [
            'present' => 0, 'late' => 0, 'absent' => 0, 'leave' => 0,
            'holiday' => 0, 'weekly_off' => 0,
            'worked_minutes' => 0, 'overtime_minutes' => 0, 'late_minutes' => 0,
        ];

        $rows = DB::table('attendance')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->whereBetween('date', [$from, $to])
            ->get(['status', 'late_minutes', 'overtime_minutes', 'worked_minutes']);

        foreach ($rows as $row) {
            $lateMinutes = Value::int($row->late_minutes);

            match (Value::string($row->status)) {
                'present' => $lateMinutes > 0 ? $counts['late']++ : $counts['present']++,
                'absent' => $counts['absent']++,
                'leave' => $counts['leave']++,
                'holiday' => $counts['holiday']++,
                'weekly_off' => $counts['weekly_off']++,
                default => null,
            };

            $counts['worked_minutes'] += Value::int($row->worked_minutes);
            $counts['overtime_minutes'] += Value::int($row->overtime_minutes);
            $counts['late_minutes'] += $lateMinutes;
        }

        return $counts;
    }

    /**
     * The settings behind the arithmetic, so the tab can answer "how is this
     * calculated?" without the reader taking it on trust.
     *
     * @return array<string, mixed>
     */
    private function publicRules(int $tenantId): array
    {
        $values = [];

        foreach (['deduction_rules', 'bonus_rules'] as $table) {
            $rules = DB::table($table)->where('tenant_id', $tenantId)->where('is_active', 1)
                ->get(['rule_key', 'rule_value']);

            foreach ($rules as $rule) {
                $values[Value::string($rule->rule_key)] = $rule->rule_value;
            }
        }

        $numeric = static fn (string $key): ?float => isset($values[$key]) ? Value::float($values[$key]) : null;

        return [
            'late_type' => $values['late_type'] ?? null,
            'late_unit_minutes' => $numeric('late_unit_minutes'),
            'late_deduction_per_unit' => $numeric('late_deduction_per_unit'),
            'late_fixed_amount' => $numeric('late_fixed_amount'),
            'absence_multiplier' => $numeric('absence_multiplier'),
            'overtime_multiplier' => $numeric('overtime_multiplier'),
        ];
    }

    /**
     * Outstanding loans with what is left to pay on each.
     *
     * @return list<array<string, mixed>>
     */
    private function loans(int $employeeId, int $tenantId): array
    {
        $loans = DB::table('employee_loans')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->whereIn('status', ['pending', 'active'])
            ->orderByDesc('created_at')
            ->get([
                'id', 'type', 'total_amount', 'installment_amount', 'installments_count',
                'installments_paid', 'start_month', 'reason', 'status', 'created_at', 'approved_at',
            ]);

        $out = [];

        foreach ($loans as $loan) {
            $loanId = Value::int($loan->id);

            $sums = DB::table('loan_installments')
                ->where('loan_id', $loanId)->where('tenant_id', $tenantId)
                ->selectRaw(
                    "COALESCE(SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END), 0) AS paid_amount,"
                    ."COALESCE(SUM(CASE WHEN status = 'pending' THEN amount ELSE 0 END), 0) AS remaining_amount,"
                    ."MIN(CASE WHEN status = 'pending' THEN month END) AS next_due_month,"
                    ."COUNT(CASE WHEN status = 'pending' THEN 1 END) AS remaining_installments"
                )
                ->first();

            $out[] = self::toArray($loan) + [
                'paid_amount' => $sums === null ? 0.0 : Value::float($sums->paid_amount),
                'remaining_amount' => $sums === null ? 0.0 : Value::float($sums->remaining_amount),
                'next_due_month' => $sums === null ? null : Value::nullableString($sums->next_due_month),
                'remaining_installments' => $sums === null ? 0 : Value::int($sums->remaining_installments),
            ];
        }

        return $out;
    }

    /**
     * Every recorded change to the base salary, read back out of the audit
     * trail — there is no separate history table, and the trail already holds
     * who changed it and when.
     *
     * @return list<array<string, mixed>>
     */
    private function salaryHistory(int $employeeId, int $tenantId): array
    {
        $rows = DB::table('audit_log as al')
            ->leftJoin('admins as a', 'a.id', '=', 'al.admin_id')
            ->where('al.tenant_id', $tenantId)
            ->where('al.action', 'employee.update')
            ->where('al.target_type', 'employee')
            ->where('al.target_id', (string) $employeeId)
            ->where('al.payload', 'like', '%base_salary%')
            ->orderByDesc('al.created_at')
            ->limit(20)
            ->get(['al.created_at', 'al.payload', 'a.name as admin_name']);

        $history = [];

        foreach ($rows as $row) {
            $payload = self::decode($row->payload);

            // The LIKE matches the word anywhere in the payload, including in
            // some other field's text; only a real base_salary key counts.
            if ($payload === null || ! array_key_exists('base_salary', $payload)) {
                continue;
            }

            $history[] = [
                'created_at' => $row->created_at,
                'admin_name' => $row->admin_name,
                'base_salary' => Value::float($payload['base_salary']),
            ];
        }

        return $history;
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function slipHistory(int $employeeId, int $tenantId): array
    {
        $rows = DB::table('payroll')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->orderByDesc('month')
            ->limit(24)
            ->get([
                'id', 'month', 'base_salary', 'total_deductions', 'total_bonuses',
                'net_salary', 'status', 'approved_at', 'paid_at',
            ])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * @return array<string, mixed>|null
     */
    private static function decode(mixed $raw): ?array
    {
        if (! is_string($raw) || $raw === '') {
            return null;
        }

        $decoded = json_decode($raw, true);

        if (! is_array($decoded)) {
            return null;
        }

        /** @var array<string, mixed> $payload */
        $payload = $decoded;

        return $payload;
    }

    /**
     * @return array<string, mixed>
     */
    private static function toArray(mixed $row): array
    {
        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }
}
