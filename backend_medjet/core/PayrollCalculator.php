<?php

final class PayrollCalculator {
    public static function calculate(int $employeeId, string $month, int $tenantId): array {
        $employee = EmployeeModel::findById($employeeId, $tenantId);
        if (!$employee) {
            return [];
        }

        $baseSalary = (float) $employee['base_salary'];
        $deductions = self::calculateDeductions($employeeId, $month, $tenantId, $baseSalary);
        $bonuses = self::calculateBonuses($employeeId, $month, $tenantId);

        $totalDeductions = array_sum(array_column($deductions, 'amount'));
        $totalBonuses = array_sum(array_column($bonuses, 'amount'));

        $statutory = self::applyStatutory($baseSalary, $deductions, $tenantId);

        $totalDeductions = array_sum(array_column($deductions, 'amount'));
        $netSalary = $baseSalary - $totalDeductions + $totalBonuses;

        $result = [
            'employee_id' => $employeeId,
            'month' => $month,
            'base_salary' => $baseSalary,
            'total_deductions' => round($totalDeductions, 2),
            'total_bonuses' => round($totalBonuses, 2),
            'net_salary' => round(max(0, $netSalary), 2),
            'deductions_breakdown' => $deductions,
            'bonuses_breakdown' => $bonuses,
        ];

        if (!empty($statutory)) {
            $result['statutory_breakdown'] = $statutory;
        }

        return $result;
    }

    private static function calculateDeductions(int $employeeId, string $month, int $tenantId, float $baseSalary): array {
        $deductions = [];
        $rules = DeductionRuleModel::getActiveByTenant($tenantId);
        $attendances = AttendanceModel::getByEmployeeMonth($employeeId, $month, $tenantId);

        $dailyRate = $baseSalary / 30;
        $hourlyRate = $dailyRate / 8;

        foreach ($attendances as $att) {
            if ($att['status'] === 'absent') {
                $multiplier = self::getRuleValue($rules, 'absence_multiplier', 1.5);
                $deductions[] = [
                    'type' => 'absence',
                    'date' => $att['date'],
                    'amount' => round($dailyRate * $multiplier, 2),
                    'description' => "غياب يوم {$att['date']}",
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
                'type' => 'manual',
                'date' => $md['created_at'],
                'amount' => (float) $md['amount'],
                'description' => $md['reason'],
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

    private static function calculateBonuses(int $employeeId, string $month, int $tenantId): array {
        $bonuses = [];
        $rules = BonusRuleModel::getActiveByTenant($tenantId);
        $attendances = AttendanceModel::getByEmployeeMonth($employeeId, $month, $tenantId);

        $baseSalary = (float) EmployeeModel::findById($employeeId, $tenantId)['base_salary'];
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
                'type' => 'manual',
                'date' => $mb['created_at'],
                'amount' => (float) $mb['amount'],
                'description' => $mb['reason'],
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
