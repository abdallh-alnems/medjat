<?php

final class AnalyticsModel {

    private static function branchWhere(?int $branchId, array &$params, string $alias = 'e'): string {
        if ($branchId === null) {
            return '';
        }
        $params[] = $branchId;
        return " AND {$alias}.branch_id = ?";
    }

    private static function departmentWhere(?string $department, array &$params, string $alias = 'e'): string {
        if ($department === null) {
            return '';
        }
        if ($department === '') {
            $params[] = '';
            return " AND ({$alias}.department IS NULL OR {$alias}.department = ?)";
        }
        $params[] = $department;
        return " AND {$alias}.department = ?";
    }

    public static function headcountAsOf(int $tenantId, string $asOf, ?int $branchId = null, ?string $department = null): int {
        $params = [$tenantId, $asOf, $asOf];
        $sql = "SELECT COUNT(*) AS c FROM employees
                WHERE tenant_id = ?
                  AND status <> 'pending_activation'
                  AND hire_date <= ?
                  AND (terminated_at IS NULL OR terminated_at > ?)";
        $sql .= self::branchWhere($branchId, $params);
        $sql .= self::departmentWhere($department, $params);
        return (int) (Database::fetchOne($sql, $params)['c'] ?? 0);
    }

    public static function turnover(int $tenantId, string $start, string $end, ?int $branchId = null, ?string $department = null): array {
        $series = [];
        $period = new DatePeriod(
            new DateTime(substr($start, 0, 7) . '-01'),
            new DateInterval('P1M'),
            (new DateTime(substr($end, 0, 7) . '-01'))->modify('+1 month')
        );

        $totalHires = 0;
        $totalTerminations = 0;
        $turnoverSum = 0.0;
        $monthCount = 0;

        foreach ($period as $dt) {
            $month = $dt->format('Y-m');
            $firstDay = $month . '-01';
            $lastDay = $dt->format('Y-m-t');

            $hcStart = self::headcountAsOf($tenantId, $firstDay, $branchId, $department);
            $hcEnd = self::headcountAsOf($tenantId, $lastDay, $branchId, $department);

            $hiresParams = [$tenantId, $firstDay, $lastDay];
            $hiresSql = "SELECT COUNT(*) AS c FROM employees
                         WHERE tenant_id = ? AND status <> 'pending_activation'
                           AND hire_date BETWEEN ? AND ?";
            $hiresSql .= self::branchWhere($branchId, $hiresParams);
            $hiresSql .= self::departmentWhere($department, $hiresParams);
            $hires = (int) (Database::fetchOne($hiresSql, $hiresParams)['c'] ?? 0);

            $termParams = [$tenantId, $firstDay, $lastDay];
            $termSql = "SELECT COUNT(*) AS c FROM employees
                        WHERE tenant_id = ?
                          AND terminated_at BETWEEN ? AND ?";
            $termSql .= self::branchWhere($branchId, $termParams);
            $termSql .= self::departmentWhere($department, $termParams);
            $terminations = (int) (Database::fetchOne($termSql, $termParams)['c'] ?? 0);

            $avgHc = ($hcStart + $hcEnd) / 2;
            $turnoverRate = $avgHc > 0 ? round(($terminations / $avgHc) * 100, 2) : 0;

            $series[] = [
                'month' => $month,
                'headcount_start' => $hcStart,
                'headcount_end' => $hcEnd,
                'hires' => $hires,
                'terminations' => $terminations,
                'turnover_rate' => $turnoverRate,
            ];

            $totalHires += $hires;
            $totalTerminations += $terminations;
            $turnoverSum += $turnoverRate;
            $monthCount++;
        }

        $byBranch = self::turnoverBreakdown($tenantId, $start, $end, 'branch', $branchId);
        $byDepartment = self::turnoverBreakdown($tenantId, $start, $end, 'department', null, $department);

        return [
            'start_date' => $start,
            'end_date' => $end,
            'series' => $series,
            'by_branch' => $byBranch,
            'by_department' => $byDepartment,
            'summary' => [
                'avg_turnover_rate' => $monthCount > 0 ? round($turnoverSum / $monthCount, 2) : 0,
                'total_hires' => $totalHires,
                'total_terminations' => $totalTerminations,
            ],
        ];
    }

    private static function turnoverBreakdown(int $tenantId, string $start, string $end, string $dimension, ?int $branchId = null, ?string $department = null): array {
        $col = $dimension === 'branch' ? 'b.name' : 'COALESCE(e.department, \'—\')';
        $join = $dimension === 'branch' ? ' LEFT JOIN branches b ON b.id = e.branch_id' : '';

        $hiresParams = [$tenantId, $start, $end];
        $hiresSql = "SELECT {$col} AS dim, COUNT(*) AS hires
                     FROM employees e{$join}
                     WHERE e.tenant_id = ? AND e.status <> 'pending_activation'
                       AND e.hire_date BETWEEN ? AND ?";
        $hiresSql .= self::branchWhere($branchId, $hiresParams, 'e');
        if ($dimension !== 'department') {
            $hiresSql .= self::departmentWhere($department, $hiresParams, 'e');
        }
        $hiresSql .= " GROUP BY dim ORDER BY dim";
        $hiresRows = Database::fetchAll($hiresSql, $hiresParams);

        $termParams = [$tenantId, $start, $end];
        $termSql = "SELECT {$col} AS dim, COUNT(*) AS terminations
                    FROM employees e{$join}
                    WHERE e.tenant_id = ?
                      AND e.terminated_at BETWEEN ? AND ?";
        $termSql .= self::branchWhere($branchId, $termParams, 'e');
        if ($dimension !== 'department') {
            $termSql .= self::departmentWhere($department, $termParams, 'e');
        }
        $termSql .= " GROUP BY dim ORDER BY dim";
        $termRows = Database::fetchAll($termSql, $termParams);

        $result = [];
        foreach ($hiresRows as $r) {
            $d = $r['dim'] ?? '—';
            $result[$d] = ['dimension' => $d, 'hires' => (int) $r['hires'], 'terminations' => 0];
        }
        foreach ($termRows as $r) {
            $d = $r['dim'] ?? '—';
            if (!isset($result[$d])) {
                $result[$d] = ['dimension' => $d, 'hires' => 0, 'terminations' => 0];
            }
            $result[$d]['terminations'] = (int) $r['terminations'];
        }
        return array_values($result);
    }

    public static function headcountSeries(int $tenantId, string $start, string $end, ?int $branchId = null, ?string $department = null): array {
        $series = [];
        $period = new DatePeriod(
            new DateTime(substr($start, 0, 7) . '-01'),
            new DateInterval('P1M'),
            (new DateTime(substr($end, 0, 7) . '-01'))->modify('+1 month')
        );

        $firstHc = null;
        $lastHc = null;

        foreach ($period as $dt) {
            $month = $dt->format('Y-m');
            $lastDay = $dt->format('Y-m-t');
            $hc = self::headcountAsOf($tenantId, $lastDay, $branchId, $department);
            $series[] = ['month' => $month, 'headcount' => $hc];
            if ($firstHc === null) {
                $firstHc = $hc;
            }
            $lastHc = $hc;
        }

        return [
            'start_date' => $start,
            'end_date' => $end,
            'series' => $series,
            'summary' => [
                'current_headcount' => $lastHc ?? 0,
                'net_growth' => ($firstHc !== null && $lastHc !== null) ? $lastHc - $firstHc : 0,
            ],
        ];
    }

    public static function absenceTrend(int $tenantId, string $start, string $end, ?int $branchId = null, ?string $department = null): array {
        $params = [$tenantId, $start, $end];
        $sql = "SELECT DATE_FORMAT(a.date, '%Y-%m') AS month,
                       SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) AS absent_days,
                       SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) AS present_days
                FROM attendance a
                JOIN employees e ON e.id = a.employee_id
                WHERE a.tenant_id = ?
                  AND a.date BETWEEN ? AND ?
                  AND a.status IN ('present','absent')";
        $sql .= self::branchWhere($branchId, $params, 'a');
        $sql .= self::departmentWhere($department, $params, 'e');
        $sql .= " GROUP BY month ORDER BY month";

        $rows = Database::fetchAll($sql, $params);
        $series = [];
        $totalAbsent = 0;
        $totalPresent = 0;
        foreach ($rows as $r) {
            $absent = (int) $r['absent_days'];
            $present = (int) $r['present_days'];
            $total = $absent + $present;
            $rate = $total > 0 ? round(($absent / $total) * 100, 2) : 0;
            $series[] = [
                'month' => $r['month'],
                'absent_days' => $absent,
                'present_days' => $present,
                'absence_rate' => $rate,
            ];
            $totalAbsent += $absent;
            $totalPresent += $present;
        }

        $grandTotal = $totalAbsent + $totalPresent;
        return [
            'start_date' => $start,
            'end_date' => $end,
            'series' => $series,
            'summary' => [
                'total_absent_days' => $totalAbsent,
                'total_present_days' => $totalPresent,
                'avg_absence_rate' => $grandTotal > 0 ? round(($totalAbsent / $grandTotal) * 100, 2) : 0,
            ],
        ];
    }

    public static function absenceByWeekday(int $tenantId, string $start, string $end, ?int $branchId = null, ?string $department = null): array {
        $params = [$tenantId, $start, $end];
        $sql = "SELECT DAYOFWEEK(a.date) AS weekday,
                       SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) AS absent_count,
                       SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) AS present_count
                FROM attendance a
                JOIN employees e ON e.id = a.employee_id
                WHERE a.tenant_id = ?
                  AND a.date BETWEEN ? AND ?
                  AND a.status IN ('present','absent')";
        $sql .= self::branchWhere($branchId, $params, 'a');
        $sql .= self::departmentWhere($department, $params, 'e');
        $sql .= " GROUP BY weekday ORDER BY weekday";

        $rows = Database::fetchAll($sql, $params);
        $dayNames = [1 => 'Sunday', 2 => 'Monday', 3 => 'Tuesday', 4 => 'Wednesday', 5 => 'Thursday', 6 => 'Friday', 7 => 'Saturday'];
        $result = [];
        foreach ($rows as $r) {
            $wd = (int) $r['weekday'];
            $absent = (int) $r['absent_count'];
            $present = (int) $r['present_count'];
            $total = $absent + $present;
            $result[] = [
                'weekday' => $wd,
                'weekday_name' => $dayNames[$wd] ?? '',
                'absent_count' => $absent,
                'present_count' => $present,
                'absence_rate' => $total > 0 ? round(($absent / $total) * 100, 2) : 0,
            ];
        }
        return $result;
    }

    public static function topAbsentees(int $tenantId, string $start, string $end, int $limit = 10, ?int $branchId = null, ?string $department = null): array {
        $params = [$tenantId, $start, $end, $limit];
        $sql = "SELECT e.id AS employee_id, e.name AS employee_name,
                       SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) AS absent_days,
                       SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) AS present_days
                FROM attendance a
                JOIN employees e ON e.id = a.employee_id
                WHERE a.tenant_id = ?
                  AND a.date BETWEEN ? AND ?
                  AND a.status IN ('present','absent')";
        $sql .= self::branchWhere($branchId, $params, 'a');
        $sql .= self::departmentWhere($department, $params, 'e');
        $sql .= " GROUP BY e.id ORDER BY absent_days DESC LIMIT ?";
        return Database::fetchAll($sql, $params);
    }

    public static function laborCost(int $tenantId, string $startMonth, string $endMonth, ?int $branchId = null, ?string $department = null, bool $includeDraft = false): array {
        $statusFilter = $includeDraft
            ? "p.status IN ('draft','approved','paid')"
            : "p.status IN ('approved','paid')";

        $params = [$tenantId, $startMonth, $endMonth];
        $sql = "SELECT p.month,
                       COUNT(*) AS employee_count,
                       ROUND(SUM(p.net_salary), 2) AS total_net_salary,
                       ROUND(SUM(p.total_bonuses), 2) AS total_bonuses,
                       ROUND(SUM(p.total_deductions), 2) AS total_deductions,
                       SUM(p.overtime_total_minutes) AS total_overtime_minutes,
                       ROUND(SUM(p.net_salary) / NULLIF(COUNT(*), 0), 2) AS avg_cost_per_employee
                FROM payroll p
                JOIN employees e ON e.id = p.employee_id
                WHERE p.tenant_id = ?
                  AND {$statusFilter}
                  AND p.month BETWEEN ? AND ?";
        $sql .= self::branchWhere($branchId, $params, 'p');
        $sql .= self::departmentWhere($department, $params, 'e');
        $sql .= " GROUP BY p.month ORDER BY p.month";

        $rows = Database::fetchAll($sql, $params);
        $series = [];
        $totalNet = 0;
        $totalBonuses = 0;
        $totalDeductions = 0;
        foreach ($rows as $r) {
            $series[] = [
                'month' => $r['month'],
                'employee_count' => (int) $r['employee_count'],
                'total_net_salary' => (float) $r['total_net_salary'],
                'total_bonuses' => (float) $r['total_bonuses'],
                'total_deductions' => (float) $r['total_deductions'],
                'total_overtime_minutes' => (int) $r['total_overtime_minutes'],
                'avg_cost_per_employee' => (float) $r['avg_cost_per_employee'],
            ];
            $totalNet += (float) $r['total_net_salary'];
            $totalBonuses += (float) $r['total_bonuses'];
            $totalDeductions += (float) $r['total_deductions'];
        }

        return [
            'start_month' => $startMonth,
            'end_month' => $endMonth,
            'include_draft' => $includeDraft,
            'series' => $series,
            'summary' => [
                'total_net_salary' => round($totalNet, 2),
                'total_bonuses' => round($totalBonuses, 2),
                'total_deductions' => round($totalDeductions, 2),
            ],
        ];
    }

    public static function laborCostBreakdown(int $tenantId, string $month, string $dimension, bool $includeDraft = false): array {
        $statusFilter = $includeDraft
            ? "p.status IN ('draft','approved','paid')"
            : "p.status IN ('approved','paid')";

        if ($dimension === 'branch') {
            $sql = "SELECT COALESCE(b.name, '—') AS dimension_label,
                           COUNT(*) AS employee_count,
                           ROUND(SUM(p.net_salary), 2) AS total_net_salary
                    FROM payroll p
                    LEFT JOIN branches b ON b.id = p.branch_id
                    WHERE p.tenant_id = ?
                      AND {$statusFilter}
                      AND p.month = ?
                    GROUP BY p.branch_id ORDER BY total_net_salary DESC";
        } else {
            $sql = "SELECT COALESCE(e.department, '—') AS dimension_label,
                           COUNT(*) AS employee_count,
                           ROUND(SUM(p.net_salary), 2) AS total_net_salary
                    FROM payroll p
                    JOIN employees e ON e.id = p.employee_id
                    WHERE p.tenant_id = ?
                      AND {$statusFilter}
                      AND p.month = ?
                    GROUP BY e.department ORDER BY total_net_salary DESC";
        }

        return Database::fetchAll($sql, [$tenantId, $month]);
    }

    public static function overview(int $tenantId, string $start, string $end, ?int $branchId = null, ?string $department = null): array {
        $currentHeadcount = self::headcountAsOf($tenantId, date('Y-m-d'), $branchId, $department);

        $turnoverData = self::turnover($tenantId, $start, $end, $branchId, $department);

        $absenceData = self::absenceTrend($tenantId, $start, $end, $branchId, $department);

        $lastMonth = date('Y-m', strtotime('last month'));
        $laborData = self::laborCost($tenantId, $lastMonth, $lastMonth, $branchId, $department);

        $headcountData = self::headcountSeries($tenantId, $start, $end, $branchId, $department);

        $lastLaborMonth = !empty($laborData['series']) ? $laborData['series'][count($laborData['series']) - 1] : null;

        return [
            'start_date' => $start,
            'end_date' => $end,
            'current_headcount' => $currentHeadcount,
            'turnover_rate' => $turnoverData['summary']['avg_turnover_rate'],
            'absence_rate' => $absenceData['summary']['avg_absence_rate'],
            'labor_cost_last_month' => $lastLaborMonth ? $lastLaborMonth['total_net_salary'] : 0,
            'net_growth' => $headcountData['summary']['net_growth'],
        ];
    }
}
