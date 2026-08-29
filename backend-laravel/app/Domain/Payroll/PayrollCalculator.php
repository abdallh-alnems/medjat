<?php

declare(strict_types=1);

namespace App\Domain\Payroll;

use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * What somebody is owed for a month.
 *
 * The most consequential code in the system: every number it produces ends up
 * on a payslip somebody checks against their bank statement. Two properties are
 * worth stating up front.
 *
 * A negative net is kept rather than clamped at zero. When deductions exceed
 * what was earned, HR has to see that — a floor at zero hides the situation and
 * makes the following month's arithmetic wrong.
 *
 * And a live figure never charges for days that have not happened. Everything
 * is bounded by the cycle's effective end, so opening the screen mid-month
 * shows what has been earned so far rather than a full month's deductions
 * against a partial month's work.
 */
final class PayrollCalculator
{
    /** A month is thirty days for rate purposes, whatever the calendar says. */
    private const DAYS_PER_MONTH = 30;

    private const HOURS_PER_DAY = 8;

    /**
     * @return array<string, mixed> Empty when the employee does not exist.
     */
    public function calculate(int $employeeId, string $month, int $tenantId, ?string $asOf = null): array
    {
        $employee = DB::table('employees')
            ->where('id', $employeeId)->where('tenant_id', $tenantId)
            ->first(['id', 'branch_id', 'base_salary']);

        if ($employee === null) {
            return [];
        }

        $cycle = PayCycle::resolve($tenantId, Value::nullableInt($employee->branch_id), $month);
        $effectiveEnd = $cycle->effectiveEnd($asOf);

        $baseSalary = Value::float($employee->base_salary);

        $deductions = $this->deductions($employeeId, $month, $tenantId, $baseSalary, $cycle, $effectiveEnd);
        $bonuses = $this->bonuses($employeeId, $month, $tenantId, $baseSalary, $cycle, $effectiveEnd);

        $statutory = StatutoryDeductions::apply($baseSalary, $deductions, $tenantId);

        $overrides = PayLineOverrides::forMonth($employeeId, $month, $tenantId);
        if ($overrides !== []) {
            $deductions = PayLineOverrides::apply($deductions, 'deduction', $overrides);
            $bonuses = PayLineOverrides::apply($bonuses, 'bonus', $overrides);

            if ($statutory !== []) {
                $statutory = $this->reconcileStatutory($statutory, $deductions);
            }
        }

        $totalDeductions = array_sum(array_column($deductions, 'amount'));
        $totalBonuses = array_sum(array_column($bonuses, 'amount'));

        $daysInCycle = $cycle->days();
        $daysElapsed = $cycle->daysElapsed($effectiveEnd);

        $proratedBase = $daysInCycle > 0
            ? round($baseSalary * $daysElapsed / $daysInCycle, 2)
            : 0.0;

        $result = [
            'employee_id' => $employeeId,
            'month' => $month,
            'base_salary' => $baseSalary,
            'total_deductions' => round($totalDeductions, 2),
            'total_bonuses' => round($totalBonuses, 2),
            'net_salary' => round($baseSalary - $totalDeductions + $totalBonuses, 2),
            'cycle_start' => $cycle->start,
            'cycle_end' => $cycle->end,
            'effective_end' => $effectiveEnd ?? $cycle->start,
            'days_in_cycle' => $daysInCycle,
            'days_elapsed' => $daysElapsed,
            'prorated_base_salary' => $proratedBase,
            'earned_to_date' => round($proratedBase - $totalDeductions + $totalBonuses, 2),
            'deductions_breakdown' => $deductions,
            'bonuses_breakdown' => $bonuses,
        ];

        if ($statutory !== []) {
            $result['statutory_breakdown'] = $statutory;
        }

        return $result;
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function deductions(
        int $employeeId,
        string $month,
        int $tenantId,
        float $baseSalary,
        PayCycle $cycle,
        ?string $effectiveEnd,
    ): array {
        $lines = [];
        $rules = $this->rules('deduction_rules', $tenantId);
        $dailyRate = $baseSalary / self::DAYS_PER_MONTH;
        $hourlyRate = $dailyRate / self::HOURS_PER_DAY;

        $suspensions = $effectiveEnd === null
            ? []
            : $this->overlappingSuspensions($employeeId, $tenantId, $cycle->start, $effectiveEnd);

        foreach ($this->attendance($employeeId, $tenantId, $cycle->start, $effectiveEnd) as $day) {
            $date = Value::string($day['date'] ?? null);

            // A day inside a suspension is charged once, by the suspension line
            // below. Counting the absence as well would deduct the same day
            // twice for the same reason.
            if ($this->isSuspended($date, $suspensions, $effectiveEnd)) {
                continue;
            }

            if (Value::string($day['status'] ?? null) === 'absent') {
                $lines[] = $this->absenceLine($day, $date, $dailyRate, $rules);
            }

            $lateMinutes = Value::int($day['late_minutes'] ?? null);
            if ($lateMinutes > 0) {
                $line = $this->lateLine($date, $lateMinutes, $dailyRate, $rules, $tenantId);
                if ($line !== null) {
                    $lines[] = $line;
                }
            }
        }

        foreach ($this->hourlyPermissions($employeeId, $tenantId, $cycle->start, $effectiveEnd) as $permission) {
            $minutes = Value::int($permission['duration_minutes'] ?? null);
            $amount = round($hourlyRate * ($minutes / 60), 2);

            if ($minutes <= 0 || $amount <= 0) {
                continue;
            }

            $label = trim(Value::string($permission['type'] ?? null)) ?: 'إذن';
            $date = Value::string($permission['date'] ?? null);

            $lines[] = [
                'type' => 'permission_hourly',
                'date' => $date,
                'amount' => $amount,
                'description' => "{$label} {$minutes} دقيقة ({$date})",
                'label_key' => 'payline_permission_minutes',
                // The label is the permission type as the company typed it, so
                // it travels untranslated inside the localised sentence.
                'label_params' => ['label' => $label, 'minutes' => (string) $minutes, 'date' => $date],
            ];
        }

        foreach ($this->manualLines('manual_deductions', $employeeId, $month, $tenantId) as $manual) {
            $lines[] = [
                'id' => Value::int($manual['id'] ?? null),
                'type' => 'manual',
                'date' => $manual['created_at'] ?? null,
                'amount' => Value::float($manual['amount'] ?? null),
                'description' => $manual['reason'] ?? null,
                'created_by_name' => $manual['created_by_name'] ?? null,
            ];
        }

        foreach ($this->dueLoanInstallments($employeeId, $month, $tenantId) as $installment) {
            $isAdvance = Value::string($installment['loan_type'] ?? null) === 'advance';
            $label = $isAdvance ? 'سلفة' : 'قسط قرض';
            $seq = Value::int($installment['seq'] ?? null);

            $lines[] = [
                'type' => 'loan',
                'date' => $month,
                'amount' => Value::float($installment['amount'] ?? null),
                'description' => "{$label} (قسط {$seq})",
                'label_key' => $isAdvance ? 'payline_advance_installment' : 'payline_loan_installment',
                'label_params' => ['seq' => (string) $seq],
            ];
        }

        foreach ($this->suspensionLines($suspensions, $cycle, $effectiveEnd, $dailyRate) as $line) {
            $lines[] = $line;
        }

        return $lines;
    }

    /**
     * The unpaid part of a suspension, one line per suspension.
     *
     * @param  list<array<string, mixed>>  $suspensions
     * @return list<array<string, mixed>>
     */
    private function suspensionLines(array $suspensions, PayCycle $cycle, ?string $effectiveEnd, float $dailyRate): array
    {
        if ($effectiveEnd === null) {
            return [];
        }

        $lines = [];

        foreach ($suspensions as $suspension) {
            $start = max(Value::string($suspension['start_date'] ?? null), $cycle->start);
            $end = Value::nullableString($suspension['end_date'] ?? null);
            $end = ($end === null || $end > $effectiveEnd) ? $effectiveEnd : $end;

            if ($end < $start) {
                continue;
            }

            $days = PayCycle::daysBetween($start, $end) + 1;
            $mode = Value::string($suspension['pay_mode'] ?? null, 'unpaid');

            // The unpaid fraction of each day. 'full' deducts nothing and is
            // spelled out rather than left to fall through — a fully-paid
            // suspension producing a deduction would be the worst kind of quiet
            // error.
            $factor = match ($mode) {
                'full' => 0.0,
                'partial' => 1 - max(0.0, min(100.0, Value::float($suspension['pay_percentage'] ?? null))) / 100,
                default => 1.0,
            };

            $amount = round($dailyRate * $days * $factor, 2);
            if ($amount <= 0) {
                continue;
            }

            $isPartial = $mode === 'partial';

            $lines[] = [
                'type' => 'suspension',
                'date' => $start,
                'amount' => $amount,
                'description' => $isPartial
                    ? "إيقاف عن العمل ({$days} يوم) براتب جزئي"
                    : "إيقاف عن العمل ({$days} يوم) بدون راتب",
                'label_key' => $isPartial ? 'payline_suspension_partial' : 'payline_suspension_unpaid',
                'label_params' => ['days' => (string) $days],
            ];
        }

        return $lines;
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function bonuses(
        int $employeeId,
        string $month,
        int $tenantId,
        float $baseSalary,
        PayCycle $cycle,
        ?string $effectiveEnd,
    ): array {
        $lines = [];
        $rules = $this->rules('bonus_rules', $tenantId);
        $hourlyRate = ($baseSalary / self::DAYS_PER_MONTH) / self::HOURS_PER_DAY;
        $multiplier = Value::float($this->ruleValue($rules, 'overtime_multiplier', 1.5), 1.5);

        foreach ($this->attendance($employeeId, $tenantId, $cycle->start, $effectiveEnd) as $day) {
            $minutes = Value::int($day['overtime_minutes'] ?? null);
            if ($minutes <= 0) {
                continue;
            }

            $lines[] = [
                'type' => 'overtime',
                'date' => Value::string($day['date'] ?? null),
                'amount' => round($hourlyRate * $multiplier * ($minutes / 60), 2),
                'description' => "إضافي {$minutes} دقيقة",
                'label_key' => 'payline_overtime_minutes',
                'label_params' => ['minutes' => (string) $minutes],
            ];
        }

        foreach ($this->manualLines('manual_bonuses', $employeeId, $month, $tenantId) as $manual) {
            $lines[] = [
                'id' => Value::int($manual['id'] ?? null),
                'type' => 'manual',
                'date' => $manual['created_at'] ?? null,
                'amount' => Value::float($manual['amount'] ?? null),
                'description' => $manual['reason'] ?? null,
                'created_by_name' => $manual['created_by_name'] ?? null,
            ];
        }

        // Recurring allowances are emitted as bonus lines so the existing
        // arithmetic picks them up; the financial tab filters them into their
        // own section by type.
        foreach ($this->activeAllowances($employeeId, $month, $tenantId) as $allowance) {
            $custom = trim(Value::string($allowance['label'] ?? null));
            $type = Value::string($allowance['type'] ?? null);

            $lines[] = [
                'id' => Value::int($allowance['id'] ?? null),
                'type' => 'allowance',
                'allowance_type' => $type,
                'date' => null,
                'amount' => Value::float($allowance['amount'] ?? null),
                'description' => $custom !== '' ? $custom : self::allowanceLabel($type),
                // A company-typed label is shown as written; only the built-in
                // types have a translation to look up.
                'label_key' => $custom !== '' ? null : 'payline_allowance_'.$type,
                'label_params' => [],
            ];
        }

        // Cashed-out annual leave, flipped to 'paid' when payroll is approved.
        foreach ($this->pendingEncashments($employeeId, $tenantId) as $encashment) {
            $year = Value::int($encashment['source_year'] ?? null);
            $days = Value::int($encashment['days'] ?? null);

            $lines[] = [
                'id' => Value::int($encashment['id'] ?? null),
                'type' => 'leave_encashment',
                'date' => null,
                'amount' => Value::float($encashment['amount'] ?? null),
                'description' => "تصفية رصيد إجازات {$year} ({$days} يوم)",
                'label_key' => 'payline_leave_encashment',
                'label_params' => ['year' => (string) $year, 'days' => (string) $days],
            ];
        }

        return $lines;
    }

    /**
     * @param  array<string, mixed>  $statutory
     * @param  list<array<string, mixed>>  $deductions
     * @return array<string, mixed>
     */
    private function reconcileStatutory(array $statutory, array $deductions): array
    {
        // An override can waive or change a statutory line, and the summary
        // block has to agree with the lines rather than with what was computed
        // before the override was applied.
        foreach (['social_insurance' => 'insurance_employee', 'income_tax' => 'income_tax'] as $type => $key) {
            $matching = array_filter($deductions, static fn (array $l): bool => ($l['type'] ?? '') === $type);
            $statutory[$key] = $matching === [] ? 0.0 : round(array_sum(array_column($matching, 'amount')), 2);
        }

        return $statutory;
    }

    /**
     * @param  array<string, mixed>  $day
     * @param  array<string, mixed>  $rules
     * @return array<string, mixed>
     */
    private function absenceLine(array $day, string $date, float $dailyRate, array $rules): array
    {
        $mode = Value::string($day['deduction_mode'] ?? null, 'auto');
        $value = $day['deduction_value'] ?? null;

        // A per-day override: a fixed sum, or a number of days at the daily
        // rate. Anything else falls back to the company's absence multiplier.
        if ($mode === 'amount' && $value !== null) {
            return [
                'type' => 'absence', 'date' => $date,
                'amount' => round(Value::float($value), 2),
                'description' => "خصم غياب مخصص يوم {$date}",
                'label_key' => 'payline_absence_custom',
                'label_params' => ['date' => $date],
            ];
        }

        if ($mode === 'days' && $value !== null) {
            $days = Value::string($value);

            return [
                'type' => 'absence', 'date' => $date,
                'amount' => round($dailyRate * Value::float($value), 2),
                'description' => "غياب {$days} يوم ({$date})",
                'label_key' => 'payline_absence_days',
                'label_params' => ['days' => $days, 'date' => $date],
            ];
        }

        $multiplier = Value::float($this->ruleValue($rules, 'absence_multiplier', 1.5), 1.5);

        return [
            'type' => 'absence', 'date' => $date,
            'amount' => round($dailyRate * $multiplier, 2),
            'description' => "غياب يوم {$date}",
            'label_key' => 'payline_absence_day',
            'label_params' => ['date' => $date],
        ];
    }

    /**
     * @param  array<string, mixed>  $rules
     * @return array<string, mixed>|null
     */
    private function lateLine(string $date, int $minutes, float $dailyRate, array $rules, int $tenantId): ?array
    {
        $type = Value::string($this->ruleValue($rules, 'late_type', 'proportional'), 'proportional');

        if ($type === 'tiered') {
            $tier = $this->matchLateTier($tenantId, $minutes);

            // No tier matched: the company's ladder does not reach down this
            // far, and inventing a charge it never configured would be worse
            // than charging nothing.
            if ($tier === null) {
                return null;
            }

            return [
                'type' => 'late', 'date' => $date,
                'amount' => round($dailyRate * Value::float($tier['deduction_days'] ?? null), 2),
                'description' => "تأخير {$minutes} دقيقة",
                'label_key' => 'payline_late_minutes',
                'label_params' => ['minutes' => (string) $minutes],
            ];
        }

        if ($type === 'proportional') {
            $unit = max(1.0, Value::float($this->ruleValue($rules, 'late_unit_minutes', 15), 15));
            $perUnit = Value::float($this->ruleValue($rules, 'late_deduction_per_unit', $dailyRate / 4), $dailyRate / 4);

            // Rounded up: a company charging per fifteen minutes means any part
            // of one, which is what the setting says and what staff expect.
            return [
                'type' => 'late', 'date' => $date,
                'amount' => round($perUnit * ceil($minutes / $unit), 2),
                'description' => "تأخير {$minutes} دقيقة",
                'label_key' => 'payline_late_minutes',
                'label_params' => ['minutes' => (string) $minutes],
            ];
        }

        return [
            'type' => 'late', 'date' => $date,
            'amount' => round(Value::float($this->ruleValue($rules, 'late_fixed_amount', 50), 50), 2),
            'description' => "تأخير يوم {$date}",
            'label_key' => 'payline_late_day',
            'label_params' => ['date' => $date],
        ];
    }

    /**
     * The heaviest tier the lateness reaches.
     *
     * The ladder is a list of floors with no ceilings, so the match is the last
     * threshold at or below the minutes recorded.
     *
     * @return array<string, mixed>|null
     */
    private function matchLateTier(int $tenantId, int $minutes): ?array
    {
        $tier = DB::table('late_deduction_tiers')
            ->where('tenant_id', $tenantId)
            ->where('threshold_minutes', '<=', $minutes)
            ->orderByDesc('threshold_minutes')
            ->first(['deduction_days']);

        return $tier === null ? null : self::toArray($tier);
    }

    /**
     * @return array<string, mixed> rule_key => value
     */
    private function rules(string $table, int $tenantId): array
    {
        $rules = [];

        foreach (DB::table($table)->where('tenant_id', $tenantId)->where('is_active', 1)->get() as $row) {
            $rule = self::toArray($row);
            $key = Value::string($rule['rule_key'] ?? null);
            $rules[$key] = Value::string($rule['rule_type'] ?? null) === 'numeric'
                ? Value::float($rule['rule_value'] ?? null)
                : $rule['rule_value'] ?? null;
        }

        return $rules;
    }

    /**
     * @param  array<string, mixed>  $rules
     */
    private function ruleValue(array $rules, string $key, mixed $default): mixed
    {
        return $rules[$key] ?? $default;
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function attendance(int $employeeId, int $tenantId, string $from, ?string $to): array
    {
        if ($to === null) {
            return [];
        }

        $rows = DB::table('attendance')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->whereBetween('date', [$from, $to])
            ->orderBy('date')
            ->get()->all();

        return self::rows($rows);
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function overlappingSuspensions(int $employeeId, int $tenantId, string $from, string $to): array
    {
        $rows = DB::table('employee_suspensions')
            ->where('employee_id', $employeeId)
            ->where('tenant_id', $tenantId)
            ->where('start_date', '<=', $to)
            ->where(function (QueryBuilder $open) use ($from): void {
                $open->whereNull('end_date')->orWhere('end_date', '>=', $from);
            })
            ->orderBy('start_date')
            ->get(['start_date', 'end_date', 'pay_mode', 'pay_percentage'])
            ->all();

        return self::rows($rows);
    }

    /**
     * @param  list<array<string, mixed>>  $suspensions
     */
    private function isSuspended(string $date, array $suspensions, ?string $effectiveEnd): bool
    {
        foreach ($suspensions as $suspension) {
            // An open-ended suspension runs to wherever the cycle stops.
            $end = Value::nullableString($suspension['end_date'] ?? null) ?? $effectiveEnd;

            if ($end !== null && $date >= Value::string($suspension['start_date'] ?? null) && $date <= $end) {
                return true;
            }
        }

        return false;
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function hourlyPermissions(int $employeeId, int $tenantId, string $from, ?string $to): array
    {
        if ($to === null) {
            return [];
        }

        $rows = DB::table('break_requests')
            ->where('employee_id', $employeeId)
            ->where('tenant_id', $tenantId)
            ->where('status', 'approved')
            ->where('deduct_from_salary', 1)
            ->whereBetween('date', [$from, $to])
            ->orderBy('date')->orderBy('start_time')
            ->get(['date', 'type', 'duration_minutes'])
            ->all();

        return self::rows($rows);
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function manualLines(string $table, int $employeeId, string $month, int $tenantId): array
    {
        $rows = DB::table($table.' as x')
            ->leftJoin('admins as a', 'a.id', '=', 'x.created_by')
            ->where('x.employee_id', $employeeId)
            ->where('x.tenant_id', $tenantId)
            ->where('x.month', $month)
            ->orderByDesc('x.created_at')
            ->get(['x.id', 'x.amount', 'x.reason', 'x.created_at', 'a.name as created_by_name'])
            ->all();

        return self::rows($rows);
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function dueLoanInstallments(int $employeeId, string $month, int $tenantId): array
    {
        $rows = DB::table('loan_installments as li')
            ->join('employee_loans as el', 'el.id', '=', 'li.loan_id')
            ->where('li.employee_id', $employeeId)
            ->where('li.tenant_id', $tenantId)
            ->where('li.month', $month)
            ->where('li.status', 'pending')
            // A cancelled or completed loan stops charging even if a row was
            // left behind pending.
            ->where('el.status', 'active')
            ->get(['li.amount', 'li.seq', 'el.type as loan_type'])
            ->all();

        return self::rows($rows);
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function activeAllowances(int $employeeId, string $month, int $tenantId): array
    {
        $rows = DB::table('employee_allowances')
            ->where('employee_id', $employeeId)
            ->where('tenant_id', $tenantId)
            ->where('start_month', '<=', $month)
            ->where(function (QueryBuilder $open) use ($month): void {
                $open->whereNull('end_month')->orWhere('end_month', '>=', $month);
            })
            ->orderBy('type')->orderBy('id')
            ->get(['id', 'type', 'label', 'amount'])
            ->all();

        return self::rows($rows);
    }

    /**
     * Every pending encashment, not only this month's.
     *
     * Deliberately unfiltered by month: a payout sits pending until some
     * payroll is approved, and attaching it to a particular month would leave
     * it stranded if that month were never run.
     *
     * @return list<array<string, mixed>>
     */
    private function pendingEncashments(int $employeeId, int $tenantId): array
    {
        $rows = DB::table('leave_encashments')
            ->where('employee_id', $employeeId)
            ->where('tenant_id', $tenantId)
            ->where('status', 'pending')
            ->orderBy('source_year')
            ->get(['id', 'source_year', 'days', 'amount'])
            ->all();

        return self::rows($rows);
    }

    /**
     * @param  array<int, mixed>  $rows
     * @return list<array<string, mixed>>
     */
    private static function rows(array $rows): array
    {
        return array_values(array_map(self::toArray(...), $rows));
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

    public static function allowanceLabel(string $type): string
    {
        return match ($type) {
            'housing' => 'بدل سكن',
            'transport' => 'بدل مواصلات',
            'food' => 'بدل مأكل',
            'communication' => 'بدل اتصالات',
            'other' => 'بدل',
            default => $type,
        };
    }
}
