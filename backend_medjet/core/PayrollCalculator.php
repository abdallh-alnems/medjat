<?php

final class PayrollCalculator {
    /**
     * Compute a payroll slip for an employee over a cycle.
     *
     * @param string|null $asOfDate When provided ("YYYY-MM-DD"), attendance is
     *  fetched only up to this date and the base salary is prorated by days
     *  elapsed in the cycle. When null, the full cycle window is used (the
     *  shape used by payroll generation and any other completed-cycle view).
     */
    public static function calculate(int $employeeId, string $month, int $tenantId, ?string $asOfDate = null): array {
        $employee = EmployeeModel::findById($employeeId, $tenantId);
        if (!$employee) {
            return [];
        }

        $branchId = isset($employee['branch_id']) && $employee['branch_id'] !== null
            ? (int) $employee['branch_id'] : null;
        $window = self::resolveCycleWindow($tenantId, $branchId, $month);
        $cycleStart = $window['start'];
        $cycleEnd = $window['end'];

        // Date range over which attendance counts. For past/complete cycles
        // this is the full window; for the in-progress cycle it stops at
        // asOfDate; for future cycles it's empty.
        $effectiveEnd = $cycleEnd;
        if ($asOfDate !== null) {
            if ($asOfDate < $cycleStart) {
                $effectiveEnd = null;
            } elseif ($asOfDate < $cycleEnd) {
                $effectiveEnd = $asOfDate;
            }
        }

        $baseSalary = (float) $employee['base_salary'];
        $deductions = self::calculateDeductions($employeeId, $month, $tenantId, $baseSalary, $cycleStart, $effectiveEnd);
        $bonuses = self::calculateBonuses($employeeId, $month, $tenantId, $cycleStart, $effectiveEnd, $baseSalary);

        $totalBonuses = array_sum(array_column($bonuses, 'amount'));

        $statutory = self::applyStatutory($baseSalary, $deductions, $tenantId);

        $totalDeductions = array_sum(array_column($deductions, 'amount'));
        $netSalary = $baseSalary - $totalDeductions + $totalBonuses;

        $daysInCycle = self::daysBetween($cycleStart, $cycleEnd) + 1;
        $daysElapsed = $effectiveEnd === null
            ? 0
            : min($daysInCycle, self::daysBetween($cycleStart, $effectiveEnd) + 1);
        $proratedBase = $daysInCycle > 0
            ? round($baseSalary * $daysElapsed / $daysInCycle, 2)
            : 0.0;
        // Negative results are kept (no clamp at 0) so HR sees when an
        // employee's deductions exceeded what they earned — same applies
        // to the full-cycle projection below.
        $earnedToDate = round($proratedBase - $totalDeductions + $totalBonuses, 2);

        $result = [
            'employee_id' => $employeeId,
            'month' => $month,
            'base_salary' => $baseSalary,
            'total_deductions' => round($totalDeductions, 2),
            'total_bonuses' => round($totalBonuses, 2),
            'net_salary' => round($netSalary, 2),
            'cycle_start' => $cycleStart,
            'cycle_end' => $cycleEnd,
            'effective_end' => $effectiveEnd ?? $cycleStart,
            'days_in_cycle' => $daysInCycle,
            'days_elapsed' => $daysElapsed,
            'prorated_base_salary' => $proratedBase,
            'earned_to_date' => $earnedToDate,
            'deductions_breakdown' => $deductions,
            'bonuses_breakdown' => $bonuses,
        ];

        if (!empty($statutory)) {
            $result['statutory_breakdown'] = $statutory;
        }

        return $result;
    }

    /**
     * Resolve the cycle window (inclusive YYYY-MM-DD dates) for a given month
     * label, honouring the per-branch override of `cycle_start_day` and
     * falling back to the tenant default. A cycle is named after whichever
     * month holds most of its days (matching the attendance tab):
     *   D <= 1       → plain calendar month
     *   D in 2..16   → cycle starts in label month, ends in next month
     *   D in 17..28  → cycle starts in prior month, ends in label month
     */
    public static function resolveCycleWindow(int $tenantId, ?int $branchId, string $month): array {
        $row = Database::fetchOne(
            "SELECT COALESCE(b.cycle_start_day, t.cycle_start_day, 1) AS d
             FROM tenants t
             LEFT JOIN branches b ON b.id = ? AND b.tenant_id = t.id
             WHERE t.id = ? LIMIT 1",
            [$branchId ?? 0, $tenantId]
        );
        $startDay = max(1, min(28, (int) ($row['d'] ?? 1)));

        $year = (int) substr($month, 0, 4);
        $mon = (int) substr($month, 5, 2);

        if ($startDay <= 1) {
            $start = sprintf('%04d-%02d-01', $year, $mon);
            $lastDay = (int) date('t', mktime(0, 0, 0, $mon, 1, $year));
            $end = sprintf('%04d-%02d-%02d', $year, $mon, $lastDay);
        } else {
            $labeledByEndMonth = $startDay >= 17;
            $anchor = new DateTime(sprintf('%04d-%02d-%02d', $year, $mon, $startDay));
            $startDt = $labeledByEndMonth
                ? (clone $anchor)->modify('-1 month')
                : clone $anchor;
            $endDt = $labeledByEndMonth
                ? (clone $anchor)->modify('-1 day')
                : (clone $anchor)->modify('+1 month')->modify('-1 day');
            $start = $startDt->format('Y-m-d');
            $end = $endDt->format('Y-m-d');
        }

        return ['start' => $start, 'end' => $end];
    }

    private static function daysBetween(string $a, string $b): int {
        return (int) (new DateTime($a))->diff(new DateTime($b))->days;
    }

    private static function calculateDeductions(int $employeeId, string $month, int $tenantId, float $baseSalary, string $cycleStart, ?string $effectiveEnd): array {
        $deductions = [];
        $rules = DeductionRuleModel::getActiveByTenant($tenantId);
        $attendances = $effectiveEnd === null
            ? []
            : AttendanceModel::getByEmployeeDateRange($employeeId, $cycleStart, $effectiveEnd, $tenantId);

        $dailyRate = $baseSalary / 30;
        $hourlyRate = $dailyRate / 8;

        foreach ($attendances as $att) {
            if ($att['status'] === 'absent') {
                // Per-day override: 'amount' = fixed money, 'days' = value × daily
                // rate, 'auto' (default) = company absence_multiplier rule.
                $mode = $att['deduction_mode'] ?? 'auto';
                $value = $att['deduction_value'];
                if ($mode === 'amount' && $value !== null) {
                    $amount = round((float) $value, 2);
                    $desc = "خصم غياب مخصص يوم {$att['date']}";
                } elseif ($mode === 'days' && $value !== null) {
                    $amount = round($dailyRate * (float) $value, 2);
                    $desc = "غياب {$value} يوم ({$att['date']})";
                } else {
                    $multiplier = self::getRuleValue($rules, 'absence_multiplier', 1.5);
                    $amount = round($dailyRate * $multiplier, 2);
                    $desc = "غياب يوم {$att['date']}";
                }
                $deductions[] = [
                    'type' => 'absence',
                    'date' => $att['date'],
                    'amount' => $amount,
                    'description' => $desc,
                ];
            }

            if ($att['late_minutes'] > 0) {
                $lateType = self::getRuleValue($rules, 'late_type', 'proportional');
                if ($lateType === 'proportional') {
                    $unitMinutes = self::getRuleValue($rules, 'late_unit_minutes', 15);
                    $deductionPerUnit = self::getRuleValue($rules, 'late_deduction_per_unit', $dailyRate / 4);
                    $units = ceil($att['late_minutes'] / $unitMinutes);
                    $deductions[] = [
                        'type' => 'late',
                        'date' => $att['date'],
                        'amount' => round($deductionPerUnit * $units, 2),
                        'description' => "تأخير {$att['late_minutes']} دقيقة",
                    ];
                } else {
                    $fixedAmount = self::getRuleValue($rules, 'late_fixed_amount', 50);
                    $deductions[] = [
                        'type' => 'late',
                        'date' => $att['date'],
                        'amount' => round($fixedAmount, 2),
                        'description' => "تأخير يوم {$att['date']}",
                    ];
                }
            }
        }

        $manualDeductions = DeductionRuleModel::getManualByEmployeeMonth($employeeId, $month, $tenantId);
        foreach ($manualDeductions as $md) {
            $deductions[] = [
                'id' => (int) $md['id'],
                'type' => 'manual',
                'date' => $md['created_at'],
                'amount' => (float) $md['amount'],
                'description' => $md['reason'],
                'created_by_name' => $md['created_by_name'] ?? null,
            ];
        }

        // Loan / advance installments due this month are deducted automatically.
        $loanInstallments = LoanModel::dueInstallmentsForMonth($employeeId, $month, $tenantId);
        foreach ($loanInstallments as $inst) {
            $label = $inst['loan_type'] === 'advance' ? 'سلفة' : 'قسط قرض';
            $deductions[] = [
                'type' => 'loan',
                'date' => $month,
                'amount' => (float) $inst['amount'],
                'description' => "{$label} (قسط {$inst['seq']})",
            ];
        }

        return $deductions;
    }

    private static function calculateBonuses(int $employeeId, string $month, int $tenantId, string $cycleStart, ?string $effectiveEnd, float $baseSalary): array {
        $bonuses = [];
        $rules = BonusRuleModel::getActiveByTenant($tenantId);
        $attendances = $effectiveEnd === null
            ? []
            : AttendanceModel::getByEmployeeDateRange($employeeId, $cycleStart, $effectiveEnd, $tenantId);

        $hourlyRate = ($baseSalary / 30) / 8;
        $overtimeMultiplier = self::getRuleValue($rules, 'overtime_multiplier', 1.5);

        foreach ($attendances as $att) {
            if ($att['overtime_minutes'] > 0) {
                $overtimeHours = $att['overtime_minutes'] / 60;
                $bonuses[] = [
                    'type' => 'overtime',
                    'date' => $att['date'],
                    'amount' => round($hourlyRate * $overtimeMultiplier * $overtimeHours, 2),
                    'description' => "إضافي {$att['overtime_minutes']} دقيقة",
                ];
            }
        }

        $manualBonuses = BonusRuleModel::getManualByEmployeeMonth($employeeId, $month, $tenantId);
        foreach ($manualBonuses as $mb) {
            $bonuses[] = [
                'id' => (int) $mb['id'],
                'type' => 'manual',
                'date' => $mb['created_at'],
                'amount' => (float) $mb['amount'],
                'description' => $mb['reason'],
                'created_by_name' => $mb['created_by_name'] ?? null,
            ];
        }

        // Recurring monthly allowances active this month (housing, transport…).
        // Emitted as bonus lines with type='allowance' so the existing math
        // path picks them up; the financial tab filters them into its own
        // dedicated section.
        $allowances = AllowanceModel::getActiveForEmployeeMonth($employeeId, $month, $tenantId);
        foreach ($allowances as $a) {
            $bonuses[] = [
                'id' => (int) $a['id'],
                'type' => 'allowance',
                'allowance_type' => $a['type'],
                'date' => null,
                'amount' => (float) $a['amount'],
                'description' => AllowanceModel::displayLabel($a),
            ];
        }

        return $bonuses;
    }

    private static function applyStatutory(float $baseSalary, array &$deductions, int $tenantId): array {
        $settings = PayrollStatutoryModel::get($tenantId);
        if (!$settings) {
            return [];
        }

        $anyEnabled = (
            ($settings['social_insurance_enabled'] ?? 0) ||
            ($settings['income_tax_enabled'] ?? 0)
        );

        if (!$anyEnabled) {
            return [];
        }

        $statutory = [
            'insurance_employee' => 0,
            'insurance_employer' => 0,
            'income_tax' => 0,
            'taxable_income' => 0,
        ];

        $insuranceEmployee = 0.0;

        if ($settings['social_insurance_enabled'] ?? 0) {
            $minWage = $settings['si_min_wage'] !== null ? (float) $settings['si_min_wage'] : 0;
            $maxWage = $settings['si_max_wage'] !== null ? (float) $settings['si_max_wage'] : PHP_FLOAT_MAX;
            $employeeRate = (float) ($settings['si_employee_rate'] ?? 0);
            $employerRate = (float) ($settings['si_employer_rate'] ?? 0);

            $insurableWage = max($minWage, min($baseSalary, $maxWage));

            $insuranceEmployee = round($insurableWage * ($employeeRate / 100), 2);
            $insuranceEmployer = round($insurableWage * ($employerRate / 100), 2);

            $deductions[] = [
                'type' => 'social_insurance',
                'date' => null,
                'amount' => $insuranceEmployee,
                'description' => "تأمينات اجتماعية (حصة الموظف {$employeeRate}%)",
            ];

            $statutory['insurance_employee'] = $insuranceEmployee;
            $statutory['insurance_employer'] = $insuranceEmployer;
        }

        if ($settings['income_tax_enabled'] ?? 0) {
            $exemption = $settings['tax_personal_exemption'] !== null ? (float) $settings['tax_personal_exemption'] : 0;
            $taxableIncome = $baseSalary - $insuranceEmployee - $exemption;
            $taxableIncome = max(0, $taxableIncome);
            $statutory['taxable_income'] = round($taxableIncome, 2);

            $brackets = $settings['income_tax_brackets'];
            if (is_string($brackets)) {
                $brackets = json_decode($brackets, true);
            }

            $taxAmount = 0.0;
            if (is_array($brackets) && $taxableIncome > 0) {
                $taxAmount = self::calculateProgressiveTax($taxableIncome, $brackets);
            }

            $taxAmount = round($taxAmount, 2);
            $statutory['income_tax'] = $taxAmount;

            if ($taxAmount > 0) {
                $deductions[] = [
                    'type' => 'income_tax',
                    'date' => null,
                    'amount' => $taxAmount,
                    'description' => "ضريبة دخل",
                ];
            }
        }

        return $statutory;
    }

    private static function calculateProgressiveTax(float $monthlyTaxableIncome, array $brackets): float {
        $annualTaxable = $monthlyTaxableIncome * 12;
        $tax = 0.0;
        $prevLimit = 0.0;

        foreach ($brackets as $bracket) {
            $upTo = $bracket['up_to'] !== null ? (float) $bracket['up_to'] : PHP_FLOAT_MAX;
            $rate = (float) ($bracket['rate'] ?? 0);

            if ($annualTaxable <= $prevLimit) {
                break;
            }

            $taxableInThisBracket = min($annualTaxable, $upTo) - $prevLimit;
            if ($taxableInThisBracket > 0) {
                $tax += $taxableInThisBracket * ($rate / 100);
            }

            $prevLimit = $upTo;

            if ($annualTaxable <= $upTo) {
                break;
            }
        }

        return round($tax / 12, 2);
    }

    private static function getRuleValue(array $rules, string $key, $default = null) {
        foreach ($rules as $rule) {
            if ($rule['rule_key'] === $key) {
                return $rule['rule_type'] === 'numeric' ? (float) $rule['rule_value'] : $rule['rule_value'];
            }
        }
        return $default;
    }
}
