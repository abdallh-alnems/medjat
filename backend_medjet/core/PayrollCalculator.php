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

        $statutory = self::applyStatutory($baseSalary, $deductions, $tenantId);

        // Manual per-line overrides: edit the amount of, or remove, ANY computed
        // line (absence, late, loan, insurance, tax, overtime…) for this
        // employee+month. Applied to the final line sets so totals + net follow.
        $overrides = PayrollLineOverrideModel::getMap($employeeId, $month, $tenantId);
        if (!empty($overrides)) {
            $deductions = self::applyLineOverrides($deductions, 'deduction', $overrides);
            $bonuses = self::applyLineOverrides($bonuses, 'bonus', $overrides);
            if (!empty($statutory)) {
                $statutory = self::reconcileStatutory($statutory, $deductions);
            }
        }

        $totalBonuses = array_sum(array_column($bonuses, 'amount'));
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
     * Apply per-line overrides to a computed line list. Drops waived lines and
     * replaces the amount of overridden ones (annotating them so the client can
     * badge them). Lines are matched by sha1(type|date|description); manual
     * lines are skipped (they have their own edit/delete path).
     */
    private static function applyLineOverrides(array $lines, string $kind, array $overrides): array {
        $out = [];
        foreach ($lines as $line) {
            if (($line['type'] ?? '') === 'manual') {
                $out[] = $line;
                continue;
            }
            $hash = PayrollLineOverrideModel::hash(
                (string) ($line['type'] ?? ''),
                $line['date'] ?? null,
                (string) ($line['description'] ?? '')
            );
            $ov = $overrides[$kind . '|' . $hash] ?? null;
            if ($ov === null) {
                $out[] = $line;
                continue;
            }
            if ($ov['waived']) {
                continue; // line removed for this month
            }
            if ($ov['amount'] !== null) {
                $line['original_amount'] = $line['amount'] ?? 0;
                $line['amount'] = round((float) $ov['amount'], 2);
                $line['overridden'] = true;
            }
            $out[] = $line;
        }
        return $out;
    }

    /**
     * Keep the statutory_breakdown card consistent with overridden/waived
     * social_insurance & income_tax lines so the displayed figures match the
     * deductions actually applied.
     */
    private static function reconcileStatutory(array $statutory, array $deductions): array {
        $byType = [];
        foreach ($deductions as $d) {
            $byType[$d['type'] ?? ''] = $d['amount'] ?? 0;
        }
        $statutory['insurance_employee'] = (float) ($byType['social_insurance'] ?? 0);
        $statutory['income_tax'] = (float) ($byType['income_tax'] ?? 0);
        return $statutory;
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

        // Work suspensions overlapping this cycle. Their days are handled by a
        // dedicated suspension deduction below, so attendance-based absence/late
        // deductions are skipped for any day inside a suspension to avoid double
        // counting.
        $suspensions = $effectiveEnd === null
            ? []
            : EmployeeSuspensionModel::getOverlappingForPayroll($employeeId, $tenantId, $cycleStart, $effectiveEnd);
        $isSuspendedOn = static function (string $date) use ($suspensions, $effectiveEnd): bool {
            foreach ($suspensions as $sp) {
                $end = $sp['end_date'] ?? $effectiveEnd;
                if ($date >= $sp['start_date'] && $date <= $end) {
                    return true;
                }
            }
            return false;
        };

        foreach ($attendances as $att) {
            if ($isSuspendedOn($att['date'])) {
                continue;
            }
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

        // Approved permissions (any type) flagged for hourly deduction. Each
        // window is deducted at the hourly rate for its minutes.
        $hourlyDeductions = $effectiveEnd === null
            ? []
            : BreakRequestModel::approvedHourlyDeductions($employeeId, $tenantId, $cycleStart, $effectiveEnd);
        foreach ($hourlyDeductions as $el) {
            $minutes = (int) $el['duration_minutes'];
            if ($minutes <= 0) {
                continue;
            }
            $amount = round($hourlyRate * ($minutes / 60), 2);
            if ($amount <= 0) {
                continue;
            }
            $label = trim((string) ($el['type'] ?? '')) !== '' ? $el['type'] : 'إذن';
            $deductions[] = [
                'type' => 'permission_hourly',
                'date' => $el['date'],
                'amount' => $amount,
                'description' => "{$label} {$minutes} دقيقة ({$el['date']})",
            ];
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

        // Work-suspension deduction. For each day within a suspension that falls
        // in this cycle, deduct the unpaid fraction of the daily rate:
        //   unpaid  → full daily rate            (factor 1)
        //   partial → (100 - pay_percentage)%    (factor 1 - pct/100)
        //   full    → nothing                    (factor 0, precautionary)
        foreach ($suspensions as $sp) {
            $spStart = $sp['start_date'] > $cycleStart ? $sp['start_date'] : $cycleStart;
            $spEnd = ($sp['end_date'] === null || $sp['end_date'] > $effectiveEnd)
                ? $effectiveEnd : $sp['end_date'];
            if ($spEnd < $spStart) {
                continue;
            }
            $days = self::daysBetween($spStart, $spEnd) + 1;
            $mode = $sp['pay_mode'];
            if ($mode === 'full') {
                $factor = 0.0;
            } elseif ($mode === 'partial') {
                $pct = max(0.0, min(100.0, (float) ($sp['pay_percentage'] ?? 0)));
                $factor = 1 - $pct / 100;
            } else {
                $factor = 1.0;
            }
            $amount = round($dailyRate * $days * $factor, 2);
            if ($amount <= 0) {
                continue;
            }
            $desc = $mode === 'partial'
                ? "إيقاف عن العمل ({$days} يوم) براتب جزئي"
                : "إيقاف عن العمل ({$days} يوم) بدون راتب";
            $deductions[] = [
                'type' => 'suspension',
                'date' => $spStart,
                'amount' => $amount,
                'description' => $desc,
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
