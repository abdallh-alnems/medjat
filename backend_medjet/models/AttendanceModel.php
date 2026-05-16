<?php

final class AttendanceModel {
    public static function checkIn(int $employeeId, int $branchId, int $tenantId, string $method, ?string $checkInTime = null): int {
        $today = date('Y-m-d');
        $time = $checkInTime ?? date('H:i:s');

        $existing = Database::fetchOne(
            "SELECT id FROM attendance WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $today, $tenantId]
        );

        if ($existing) {
            Response::fail('Already checked in today', 400);
        }

        Database::execute(
            "INSERT INTO attendance (tenant_id, branch_id, employee_id, date, check_in_time, check_in_method, status)
             VALUES (?, ?, ?, ?, ?, ?, 'present')",
            [$tenantId, $branchId, $employeeId, $today, $time, $method]
        );

        return (int) Database::lastInsertId();
    }

    public static function checkOut(int $employeeId, int $tenantId, ?string $checkOutTime = null): void {
        $today = date('Y-m-d');
        $time = $checkOutTime ?? date('H:i:s');

        $record = Database::fetchOne(
            "SELECT id, check_in_time, branch_id FROM attendance WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $today, $tenantId]
        );

        if (!$record) {
            Response::fail('No check-in record found for today', 404);
        }

        if ($record['check_in_time']) {
            $checkIn = strtotime($record['check_in_time']);
            $checkOut = strtotime($time);
            $workedMinutes = max(0, ($checkOut - $checkIn) / 60);

            $branch = BranchModel::findById($record['branch_id'], $tenantId);
            $workEndTime = $branch['work_end_time'] ?? '17:00:00';
            $overtimeMinutes = max(0, ($checkOut - strtotime($workEndTime)) / 60);

            Database::execute(
                "UPDATE attendance SET check_out_time = ?, worked_minutes = ?, overtime_minutes = ? WHERE id = ?",
                [$time, (int) $workedMinutes, (int) $overtimeMinutes, $record['id']]
            );
        } else {
            Database::execute(
                "UPDATE attendance SET check_out_time = ? WHERE id = ?",
                [$time, $record['id']]
            );
        }
    }

    public static function manualCheckIn(int $employeeId, int $branchId, int $tenantId, string $date, string $checkInTime, string $checkOutTime, int $recordedBy): int {
        Database::execute(
            "INSERT INTO attendance (tenant_id, branch_id, employee_id, date, check_in_time, check_out_time, check_in_method, status, recorded_by)
             VALUES (?, ?, ?, ?, ?, ?, 'manual', 'present', ?)
             ON DUPLICATE KEY UPDATE check_in_time = VALUES(check_in_time), check_out_time = VALUES(check_out_time), check_in_method = 'manual', recorded_by = VALUES(recorded_by)",
            [$tenantId, $branchId, $employeeId, $date, $checkInTime, $checkOutTime, $recordedBy]
        );
        return (int) Database::lastInsertId();
    }

    public static function getByEmployeeMonth(int $employeeId, string $month, int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM attendance WHERE employee_id = ? AND DATE_FORMAT(date, '%Y-%m') = ? AND tenant_id = ? ORDER BY date ASC",
            [$employeeId, $month, $tenantId]
        );
    }

    public static function getByDate(int $tenantId, string $date, ?int $branchId = null): array {
        $sql = "SELECT a.*, e.name as employee_name, e.job_title
                FROM attendance a
                JOIN employees e ON e.id = a.employee_id
                WHERE a.tenant_id = ? AND a.date = ?";
        $params = [$tenantId, $date];

        if ($branchId) {
            $sql .= " AND a.branch_id = ?";
            $params[] = $branchId;
        }

        $sql .= " ORDER BY e.name ASC";
        return Database::fetchAll($sql, $params);
    }

    public static function markAbsent(int $tenantId, string $date): int {
        $presentIds = Database::fetchAll(
            "SELECT employee_id FROM attendance WHERE tenant_id = ? AND date = ?",
            [$tenantId, $date]
        );
        $presentIds = array_column($presentIds, 'employee_id');

        $sql = "SELECT id FROM employees WHERE tenant_id = ? AND status = 'active'";
        $params = [$tenantId];

        $allEmployees = Database::fetchAll($sql, $params);

        $count = 0;
        foreach ($allEmployees as $emp) {
            if (!in_array($emp['id'], $presentIds)) {
                $onLeave = LeaveModel::isEmployeeOnLeave($emp['id'], $date, $tenantId);
                if (!$onLeave) {
                    Database::execute(
                        "INSERT IGNORE INTO attendance (tenant_id, branch_id, employee_id, date, status)
                         SELECT tenant_id, branch_id, id, ?, 'absent'
                         FROM employees WHERE id = ? AND tenant_id = ?",
                        [$date, $emp['id'], $tenantId]
                    );
                    $count++;
                }
            }
        }
        return $count;
    }

    public static function syncOffline(array $records, int $tenantId): array {
        $synced = 0;
        $failed = 0;
        foreach ($records as $rec) {
            try {
                Database::execute(
                    "INSERT INTO attendance (tenant_id, branch_id, employee_id, date, check_in_time, check_out_time, check_in_method, status, is_offline)
                     VALUES (?, ?, ?, ?, ?, ?, ?, 'present', 1)
                     ON DUPLICATE KEY UPDATE check_out_time = COALESCE(VALUES(check_out_time), check_out_time)",
                    [
                        $tenantId,
                        $rec['branch_id'],
                        $rec['employee_id'],
                        $rec['date'],
                        $rec['check_in_time'] ?? null,
                        $rec['check_out_time'] ?? null,
                        $rec['check_in_method'] ?? 'qr_gps',
                    ]
                );
                $synced++;
            } catch (Exception $e) {
                error_log("Offline sync failed: " . $e->getMessage());
                $failed++;
            }
        }
        return ['synced' => $synced, 'failed' => $failed];
    }
}
