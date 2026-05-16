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
        $netSalary = $baseSalary - $totalDeductions + $totalBonuses;

        return [
            'employee_id' => $employeeId,
            'month' => $month,
            'base_salary' => $baseSalary,
            'total_deductions' => round($totalDeductions, 2),
            'total_bonuses' => round($totalBonuses, 2),
            'net_salary' => round(max(0, $netSalary), 2),
            'deductions_breakdown' => $deductions,
            'bonuses_breakdown' => $bonuses,
        ];
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

    private static function getRuleValue(array $rules, string $key, $default = null) {
        foreach ($rules as $rule) {
            if ($rule['rule_key'] === $key) {
                return $rule['rule_type'] === 'numeric' ? (float) $rule['rule_value'] : $rule['rule_value'];
            }
        }
        return $default;
    }
}
