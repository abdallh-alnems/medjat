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

        $employee = EmployeeModel::findById($employeeId, $tenantId);
        $expectedStart = $employee['shift_start'] ?? $employee['work_start_time'] ?? '09:00:00';
        $lateMinutes = max(0, (strtotime($time) - strtotime($expectedStart)) / 60);

        Database::execute(
            "INSERT INTO attendance (tenant_id, branch_id, employee_id, date, check_in_time, check_in_method, late_minutes, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, 'present')",
            [$tenantId, $branchId, $employeeId, $today, $time, $method, (int) $lateMinutes]
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

            $employee = EmployeeModel::findById($record['employee_id'], $tenantId);
            $workEndTime = $employee['shift_end'] ?? $employee['work_end_time'] ?? '17:00:00';
            $overtimeMinutes = max(0, ($checkOut - strtotime($workEndTime)) / 60);

            $workStartTime = $employee['shift_start'] ?? $employee['work_start_time'] ?? '09:00:00';
            $lateMinutes = max(0, ($checkIn - strtotime($workStartTime)) / 60);

            Database::execute(
                "UPDATE attendance SET check_out_time = ?, worked_minutes = ?, overtime_minutes = ?, late_minutes = ? WHERE id = ?",
                [$time, (int) $workedMinutes, (int) $overtimeMinutes, (int) $lateMinutes, $record['id']]
            );
        } else {
            Database::execute(
                "UPDATE attendance SET check_out_time = ? WHERE id = ?",
                [$time, $record['id']]
            );
        }
    }

    public static function manualCheckIn(int $employeeId, int $branchId, int $tenantId, string $date, string $checkInTime, string $checkOutTime, int $recordedBy): int {
        $employee = EmployeeModel::findById($employeeId, $tenantId);
        $workStartTime = $employee['shift_start'] ?? $employee['work_start_time'] ?? '09:00:00';
        $workEndTime = $employee['shift_end'] ?? $employee['work_end_time'] ?? '17:00:00';

        $checkIn = strtotime($checkInTime);
        $checkOut = strtotime($checkOutTime);
        $workedMinutes = max(0, ($checkOut - $checkIn) / 60);
        $lateMinutes = max(0, ($checkIn - strtotime($workStartTime)) / 60);
        $overtimeMinutes = max(0, ($checkOut - strtotime($workEndTime)) / 60);

        Database::execute(
            "INSERT INTO attendance (tenant_id, branch_id, employee_id, date, check_in_time, check_out_time, check_in_method, status, recorded_by, late_minutes, worked_minutes, overtime_minutes)
             VALUES (?, ?, ?, ?, ?, ?, 'manual', 'present', ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                check_in_time = VALUES(check_in_time),
                check_out_time = VALUES(check_out_time),
                check_in_method = 'manual',
                recorded_by = VALUES(recorded_by),
                late_minutes = VALUES(late_minutes),
                worked_minutes = VALUES(worked_minutes),
                overtime_minutes = VALUES(overtime_minutes)",
            [$tenantId, $branchId, $employeeId, $date, $checkInTime, $checkOutTime, $recordedBy, (int) $lateMinutes, (int) $workedMinutes, (int) $overtimeMinutes]
        );
        return (int) Database::lastInsertId();
    }

    public static function manualCheckInOnly(int $employeeId, int $branchId, int $tenantId, string $date, string $checkInTime, int $recordedBy): int {
        $existing = Database::fetchOne(
            "SELECT id, check_in_time FROM attendance WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $date, $tenantId]
        );

        if ($existing && !empty($existing['check_in_time'])) {
            Response::fail('Employee already has check-in for this date', 400);
        }

        $employee = EmployeeModel::findById($employeeId, $tenantId);
        $workStartTime = $employee['shift_start'] ?? $employee['work_start_time'] ?? '09:00:00';
        $lateMinutes = max(0, (strtotime($checkInTime) - strtotime($workStartTime)) / 60);

        if ($existing) {
            Database::execute(
                "UPDATE attendance SET check_in_time = ?, check_in_method = 'manual', status = 'present', recorded_by = ?, late_minutes = ?, branch_id = COALESCE(branch_id, ?) WHERE id = ?",
                [$checkInTime, $recordedBy, (int) $lateMinutes, $branchId, $existing['id']]
            );
            return (int) $existing['id'];
        }

        Database::execute(
            "INSERT INTO attendance (tenant_id, branch_id, employee_id, date, check_in_time, check_in_method, status, recorded_by, late_minutes)
             VALUES (?, ?, ?, ?, ?, 'manual', 'present', ?, ?)",
            [$tenantId, $branchId, $employeeId, $date, $checkInTime, $recordedBy, (int) $lateMinutes]
        );
        return (int) Database::lastInsertId();
    }

    public static function manualCheckOutOnly(int $employeeId, int $tenantId, string $date, string $checkOutTime, int $recordedBy): void {
        $record = Database::fetchOne(
            "SELECT id, check_in_time FROM attendance WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $date, $tenantId]
        );

        if (!$record) {
            Response::fail('No check-in record for this date', 404);
        }

        if (empty($record['check_in_time'])) {
            Response::fail('No check-in time recorded for this date', 400);
        }

        $employee = EmployeeModel::findById($employeeId, $tenantId);
        $workEndTime = $employee['shift_end'] ?? $employee['work_end_time'] ?? '17:00:00';

        $checkIn = strtotime($record['check_in_time']);
        $checkOut = strtotime($checkOutTime);
        $workedMinutes = max(0, ($checkOut - $checkIn) / 60);
        $overtimeMinutes = max(0, ($checkOut - strtotime($workEndTime)) / 60);

        Database::execute(
            "UPDATE attendance SET check_out_time = ?, check_out_method = 'manual', worked_minutes = ?, overtime_minutes = ?, recorded_by = COALESCE(recorded_by, ?) WHERE id = ?",
            [$checkOutTime, (int) $workedMinutes, (int) $overtimeMinutes, $recordedBy, $record['id']]
        );
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

    public static function getLiveBoard(int $tenantId, string $date, ?int $branchId = null): array {
        // Start from active employees so those with no attendance row today
        // still appear (derived as "not_in" by the caller).
        $sql = "SELECT
                    e.id AS employee_id,
                    e.name,
                    e.job_title,
                    e.branch_id,
                    b.name AS branch_name,
                    a.check_in_time,
                    a.check_out_time,
                    a.status AS attendance_status,
                    a.late_minutes,
                    a.check_in_method,
                    a.is_offline
                FROM employees e
                LEFT JOIN branches b ON b.id = e.branch_id
                LEFT JOIN attendance a
                    ON a.employee_id = e.id AND a.date = ? AND a.tenant_id = e.tenant_id
                WHERE e.tenant_id = ? AND e.status = 'active'";
        $params = [$date, $tenantId];

        if ($branchId) {
            $sql .= " AND e.branch_id = ?";
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

    public static function syncOffline(array $records, int $employeeId, int $tenantId): array {
        $synced = 0;
        $failed = 0;
        $results = [];
        $now = time();

        foreach ($records as $rec) {
            $clientRecordId = $rec['client_record_id'] ?? 'unknown';

            try {
                $branchId = (int) ($rec['branch_id'] ?? 0);
                if ($branchId <= 0) {
                    $results[] = ['client_record_id' => $clientRecordId, 'status' => 'rejected', 'reason' => 'INVALID_BRANCH'];
                    $failed++;
                    continue;
                }

                $branch = BranchModel::findById($branchId, $tenantId);
                if (!$branch) {
                    $results[] = ['client_record_id' => $clientRecordId, 'status' => 'rejected', 'reason' => 'INVALID_BRANCH'];
                    $failed++;
                    continue;
                }

                $qrCode = $rec['qr_code'] ?? null;
                if ($qrCode !== null && $branch['qr_code'] !== $qrCode) {
                    $results[] = ['client_record_id' => $clientRecordId, 'status' => 'rejected', 'reason' => 'INVALID_QR'];
                    $failed++;
                    continue;
                }

                $capturedAt = $rec['captured_at'] ?? null;
                if ($capturedAt === null) {
                    $results[] = ['client_record_id' => $clientRecordId, 'status' => 'rejected', 'reason' => 'EXPIRED'];
                    $failed++;
                    continue;
                }
                $capturedTs = strtotime($capturedAt);
                if ($capturedTs === false) {
                    $results[] = ['client_record_id' => $clientRecordId, 'status' => 'rejected', 'reason' => 'EXPIRED'];
                    $failed++;
                    continue;
                }
                if ($capturedTs > $now) {
                    $results[] = ['client_record_id' => $clientRecordId, 'status' => 'rejected', 'reason' => 'FUTURE_DATE'];
                    $failed++;
                    continue;
                }
                if (($now - $capturedTs) > 86400) {
                    $results[] = ['client_record_id' => $clientRecordId, 'status' => 'rejected', 'reason' => 'EXPIRED'];
                    $failed++;
                    continue;
                }

                $lat = (float) ($rec['check_in_latitude'] ?? 0);
                $lng = (float) ($rec['check_in_longitude'] ?? 0);
                $gpsResult = GpsService::validateCheckIn($lat, $lng, $branchId, $tenantId);
                if (!$gpsResult['valid']) {
                    $results[] = ['client_record_id' => $clientRecordId, 'status' => 'rejected', 'reason' => 'GPS_OUT_OF_RANGE'];
                    $failed++;
                    continue;
                }

                $date = $rec['date'] ?? null;
                if ($date === null) {
                    $results[] = ['client_record_id' => $clientRecordId, 'status' => 'rejected', 'reason' => 'INVALID_DATA'];
                    $failed++;
                    continue;
                }

                $existingOnline = Database::fetchOne(
                    "SELECT id FROM attendance WHERE employee_id = ? AND date = ? AND tenant_id = ? AND (is_offline = 0 OR is_offline IS NULL) LIMIT 1",
                    [$employeeId, $date, $tenantId]
                );
                if ($existingOnline) {
                    $results[] = ['client_record_id' => $clientRecordId, 'status' => 'rejected', 'reason' => 'ONLINE_EXISTS'];
                    $failed++;
                    continue;
                }

                $checkInTime = $rec['check_in_time'] ?? null;
                $checkOutTime = $rec['check_out_time'] ?? null;

                $employee = EmployeeModel::findById($employeeId, $tenantId);
                $workStartTime = $employee['shift_start'] ?? $employee['work_start_time'] ?? '09:00:00';
                $workEndTime = $employee['shift_end'] ?? $employee['work_end_time'] ?? '17:00:00';

                $lateMinutes = 0;
                $workedMinutes = 0;
                $overtimeMinutes = 0;

                if ($checkInTime) {
                    $lateMinutes = max(0, (strtotime($checkInTime) - strtotime($workStartTime)) / 60);
                }
                if ($checkInTime && $checkOutTime) {
                    $workedMinutes = max(0, (strtotime($checkOutTime) - strtotime($checkInTime)) / 60);
                    $overtimeMinutes = max(0, (strtotime($checkOutTime) - strtotime($workEndTime)) / 60);
                }

                Database::execute(
                    "INSERT INTO attendance (tenant_id, branch_id, employee_id, date, check_in_time, check_out_time,
                        check_in_latitude, check_in_longitude, check_in_method, status, is_offline, synced_at, late_minutes, worked_minutes, overtime_minutes)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'offline', 'present', 1, NOW(), ?, ?, ?)
                     ON DUPLICATE KEY UPDATE
                        check_out_time = COALESCE(VALUES(check_out_time), check_out_time),
                        check_out_latitude = COALESCE(VALUES(check_in_latitude), check_out_latitude),
                        check_out_longitude = COALESCE(VALUES(check_in_longitude), check_out_longitude),
                        check_out_method = 'offline',
                        synced_at = NOW(),
                        worked_minutes = CASE WHEN VALUES(check_out_time) IS NOT NULL THEN VALUES(worked_minutes) ELSE worked_minutes END,
                        overtime_minutes = CASE WHEN VALUES(check_out_time) IS NOT NULL THEN VALUES(overtime_minutes) ELSE overtime_minutes END",
                    [
                        $tenantId,
                        $branchId,
                        $employeeId,
                        $date,
                        $checkInTime,
                        $checkOutTime,
                        $lat ?: null,
                        $lng ?: null,
                        (int) $lateMinutes,
                        (int) $workedMinutes,
                        (int) $overtimeMinutes,
                    ]
                );

                $results[] = ['client_record_id' => $clientRecordId, 'status' => 'synced'];
                $synced++;
            } catch (Exception $e) {
                error_log("Offline sync failed for record {$clientRecordId}: " . $e->getMessage());
                $results[] = ['client_record_id' => $clientRecordId, 'status' => 'rejected', 'reason' => 'SERVER_ERROR'];
                $failed++;
            }
        }

        return ['synced' => $synced, 'failed' => $failed, 'results' => $results];
    }

    public static function getReportByRange(
        int $tenantId,
        string $startDate,
        string $endDate,
        ?int $branchId = null
    ): array {
        $sql = "SELECT
                    e.id as employee_id,
                    e.name as employee_name,
                    e.job_title,
                    b.name as branch_name,
                    COUNT(CASE WHEN a.status = 'present' AND a.late_minutes = 0 THEN 1 END) as days_present,
                    COUNT(CASE WHEN a.status = 'present' AND a.late_minutes > 0 THEN 1 END) as days_late,
                    COUNT(CASE WHEN a.status = 'absent' THEN 1 END) as days_absent,
                    COUNT(CASE WHEN a.status = 'leave' THEN 1 END) as days_leave,
                    COUNT(a.id) as days_recorded,
                    COALESCE(SUM(a.worked_minutes), 0) as total_minutes_worked
                FROM employees e
                LEFT JOIN branches b ON b.id = e.branch_id
                LEFT JOIN attendance a ON a.employee_id = e.id
                    AND a.date BETWEEN ? AND ?
                WHERE e.tenant_id = ? AND e.status != 'terminated'";
        $params = [$startDate, $endDate, $tenantId];
        if ($branchId !== null) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        $sql .= " GROUP BY e.id ORDER BY e.name ASC";
        return Database::fetchAll($sql, $params);
    }

    public static function recordStationCheckInOut(int $employeeId, int $branchId, int $tenantId, int $stationId, string $method, ?float $confidence = null): array {
        $lastScan = Database::fetchOne(
            "SELECT created_at FROM station_recognition_logs
             WHERE matched_employee_id = ? AND tenant_id = ? AND result = 'success'
               AND created_at > DATE_SUB(NOW(), INTERVAL 5 MINUTE)
             LIMIT 1",
            [$employeeId, $tenantId]
        );
        if ($lastScan) {
            return ['action' => 'too_soon', 'message' => 'Double-scan protection: less than 5 minutes since last scan'];
        }

        $lastRecord = Database::fetchOne(
            "SELECT id, check_in_time, check_out_time FROM attendance
             WHERE employee_id = ? AND tenant_id = ?
             ORDER BY date DESC, id DESC LIMIT 1",
            [$employeeId, $tenantId]
        );

        $today = date('Y-m-d');
        $time = date('H:i:s');

        if (!$lastRecord || $lastRecord['check_out_time'] !== null) {
            $employee = EmployeeModel::findById($employeeId, $tenantId);
            $expectedStart = $employee['shift_start'] ?? $employee['work_start_time'] ?? '09:00:00';
            $lateMinutes = max(0, (strtotime($time) - strtotime($expectedStart)) / 60);

            Database::execute(
                "INSERT INTO attendance (tenant_id, branch_id, employee_id, date, check_in_time, check_in_method, recognition_method, recognition_confidence, station_id, late_minutes, status)
                 VALUES (?, ?, ?, ?, ?, 'kiosk', ?, ?, ?, ?, 'present')",
                [$tenantId, $branchId, $employeeId, $today, $time, $method, $confidence, $stationId, (int) $lateMinutes]
            );
            $attId = (int) Database::lastInsertId();
            return ['action' => 'check_in', 'attendance_id' => $attId, 'timestamp' => $time];
        }

        if ($lastRecord['check_in_time'] !== null && $lastRecord['check_out_time'] === null) {
            $checkIn = strtotime($lastRecord['check_in_time']);
            $checkOut = strtotime($time);
            $workedMinutes = max(0, ($checkOut - $checkIn) / 60);

            $employee = EmployeeModel::findById($employeeId, $tenantId);
            $workEndTime = $employee['shift_end'] ?? $employee['work_end_time'] ?? '17:00:00';
            $overtimeMinutes = max(0, ($checkOut - strtotime($workEndTime)) / 60);
            $workStartTime = $employee['shift_start'] ?? $employee['work_start_time'] ?? '09:00:00';
            $lateMinutes = max(0, ($checkIn - strtotime($workStartTime)) / 60);

            Database::execute(
                "UPDATE attendance SET
                    check_out_time = ?, check_out_method = 'kiosk',
                    recognition_method = ?, recognition_confidence = ?, station_id = ?,
                    worked_minutes = ?, overtime_minutes = ?, late_minutes = ?
                 WHERE id = ?",
                [$time, $method, $confidence, $stationId, (int) $workedMinutes, (int) $overtimeMinutes, (int) $lateMinutes, $lastRecord['id']]
            );
            return ['action' => 'check_out', 'attendance_id' => (int) $lastRecord['id'], 'timestamp' => $time];
        }

        return ['action' => 'error', 'message' => 'Unexpected attendance state'];
    }

    public static function getReportSummary(
        int $tenantId,
        string $startDate,
        string $endDate,
        ?int $branchId = null
    ): array {
        $sql = "SELECT
                    COUNT(CASE WHEN a.status = 'present' AND a.late_minutes = 0 THEN 1 END) as total_present,
                    COUNT(CASE WHEN a.status = 'present' AND a.late_minutes > 0 THEN 1 END) as total_late,
                    COUNT(CASE WHEN a.status = 'absent' THEN 1 END) as total_absent,
                    COUNT(CASE WHEN a.status = 'leave' THEN 1 END) as total_leave,
                    COUNT(DISTINCT a.employee_id) as employees_with_records
                FROM attendance a
                WHERE a.tenant_id = ? AND a.date BETWEEN ? AND ?";
        $params = [$tenantId, $startDate, $endDate];
        if ($branchId !== null) {
            $sql .= " AND a.branch_id = ?";
            $params[] = $branchId;
        }
        $row = Database::fetchOne($sql, $params);
        return $row ?: [
            'total_present' => 0,
            'total_late' => 0,
            'total_absent' => 0,
            'total_leave' => 0,
            'employees_with_records' => 0,
        ];
    }
}
