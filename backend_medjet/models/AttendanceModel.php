<?php

final class AttendanceModel {
    /**
     * Overrides an employee's shift_start/shift_end with the published rotating-shift
     * schedule for $date, when one exists. Falls back silently (no change) when the
     * employee has no published row that day, so fixed-shift staff behave as before.
     */
    public static function withScheduledShift(?array $employee, int $tenantId, string $date): ?array {
        if (empty($employee['id'])) {
            return $employee;
        }
        $sched = EmployeeShiftScheduleModel::findEffective((int) $employee['id'], $tenantId, $date);
        if ($sched && !empty($sched['start_time'])) {
            $employee['shift_start'] = $sched['start_time'];
            $employee['shift_end'] = $sched['end_time'];
        }
        return $employee;
    }

    public static function checkIn(int $employeeId, int $branchId, int $tenantId, string $method, ?string $checkInTime = null, ?float $lat = null, ?float $lng = null, bool $isVpn = false, ?string $recognitionMethod = null, ?float $recognitionConfidence = null): int {
        // Stamped in the tenant's timezone, which is what every read path (and
        // the shift times we compare against below) already uses. A bare date()
        // here would record UTC and no arrival would ever count as late.
        $now = TenantClock::now($tenantId);
        $today = $now->format('Y-m-d');
        $time = $checkInTime ?? $now->format('H:i:s');

        $existing = Database::fetchOne(
            "SELECT id, check_in_time FROM attendance WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $today, $tenantId]
        );

        // A genuine duplicate has an actual check-in time. A row with a NULL
        // check_in_time is just a placeholder (e.g. an 'absent' row written by
        // markAbsentSmart once the shift ended) — that must convert into a real
        // check-in, not block it, otherwise the employee can never check in.
        if ($existing && !empty($existing['check_in_time'])) {
            Response::fail('Already checked in today', 400);
        }

        $employee = EmployeeModel::findById($employeeId, $tenantId);
        $employee = self::withScheduledShift($employee, $tenantId, $today);
        $expectedStart = $employee['shift_start'] ?? $employee['work_start_time'] ?? '09:00:00';
        $lateMinutes = max(0, (strtotime($time) - strtotime($expectedStart)) / 60);

        if ($existing) {
            Database::execute(
                "UPDATE attendance
                 SET branch_id = ?, check_in_time = ?, check_in_method = ?, late_minutes = ?,
                     status = 'present', check_in_latitude = ?, check_in_longitude = ?, is_vpn = ?,
                     recognition_method = ?, recognition_confidence = ?
                 WHERE id = ?",
                [$branchId, $time, $method, (int) $lateMinutes, $lat, $lng, $isVpn ? 1 : 0, $recognitionMethod, $recognitionConfidence, $existing['id']]
            );
            return (int) $existing['id'];
        }

        Database::execute(
            "INSERT INTO attendance (tenant_id, branch_id, employee_id, date, check_in_time, check_in_method, late_minutes, status, check_in_latitude, check_in_longitude, is_vpn, recognition_method, recognition_confidence)
             VALUES (?, ?, ?, ?, ?, ?, ?, 'present', ?, ?, ?, ?, ?)",
            [$tenantId, $branchId, $employeeId, $today, $time, $method, (int) $lateMinutes, $lat, $lng, $isVpn ? 1 : 0, $recognitionMethod, $recognitionConfidence]
        );

        return (int) Database::lastInsertId();
    }

    /**
     * Stamps which channel a punch came from, and the evidence captured with it.
     *
     * Kept separate from checkIn()/checkOut() rather than widening their
     * signatures: checkIn() already takes ten positional arguments and is on the
     * path every employee in the field uses from the app. Adding two more
     * would make an already-fragile call site worse for the sake of a column
     * only one channel writes.
     *
     * @param string $which 'check_in' or 'check_out'
     * @param string $origin 'app' or 'web'
     */
    public static function recordChannel(
        int $tenantId,
        int $employeeId,
        string $date,
        string $which,
        string $origin,
        ?string $photoPath = null
    ): void {
        if (!in_array($which, ['check_in', 'check_out'], true)) {
            return;
        }

        Database::execute(
            "UPDATE attendance
             SET {$which}_origin = ?, {$which}_photo = COALESCE(?, {$which}_photo)
             WHERE tenant_id = ? AND employee_id = ? AND date = ?",
            [$origin, $photoPath, $tenantId, $employeeId, $date]
        );
    }

    /**
     * True when the employee has already checked in today (tenant clock) and has
     * not checked out yet.
     *
     * Used to let someone close a day they legitimately opened even after the
     * company has withdrawn the channel underneath them. Anything else strands
     * the day half-recorded and turns a policy change into a payroll dispute.
     */
    public static function hasOpenDay(int $employeeId, int $tenantId): bool {
        $today = TenantClock::now($tenantId)->format('Y-m-d');
        $row = Database::fetchOne(
            "SELECT 1 AS ok FROM attendance
             WHERE employee_id = ? AND tenant_id = ? AND date = ?
               AND check_in_time IS NOT NULL AND check_out_time IS NULL
             LIMIT 1",
            [$employeeId, $tenantId, $today]
        );
        return $row !== null;
    }

    public static function checkOut(int $employeeId, int $tenantId, ?string $checkOutTime = null): void {
        // Same tenant clock as checkIn: the row this looks up was keyed on the
        // tenant's date, and the overtime maths below compares against shift
        // times expressed in that same zone.
        $now = TenantClock::now($tenantId);
        $today = $now->format('Y-m-d');
        $time = $checkOutTime ?? $now->format('H:i:s');

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

            $employee = EmployeeModel::findById($employeeId, $tenantId);
            $employee = self::withScheduledShift($employee, $tenantId, $today);
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

    /**
     * Records arrival for a whole crew in one pass.
     *
     * Deliberately NOT a loop over checkIn(). That method answers a duplicate
     * with Response::fail(), which ends the request — acceptable for one person
     * tapping a button, ruinous here: a foreman marking thirty labourers whose
     * third name already has a row would abort the batch and lose the other
     * twenty-seven, having written some of them. A batch has to survive its
     * individual failures and report them.
     *
     * Every row is stamped with the supervisor, so "who said this person was
     * here" is answerable from the attendance row itself.
     *
     * @param int[] $employeeIds Already authorised by the caller.
     * @return array{recorded: int[], skipped: array<int, string>}
     */
    public static function crewCheckIn(
        array $employeeIds,
        int $branchId,
        int $tenantId,
        int $supervisorId,
        ?float $lat,
        ?float $lng,
        ?string $photoPath
    ): array {
        $now = TenantClock::now($tenantId);
        $today = $now->format('Y-m-d');
        $time = $now->format('H:i:s');

        $recorded = [];
        $skipped = [];

        foreach ($employeeIds as $rawId) {
            $employeeId = (int) $rawId;

            $existing = Database::fetchOne(
                "SELECT id, check_in_time FROM attendance
                 WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
                [$employeeId, $today, $tenantId]
            );

            // A row with no check_in_time is a placeholder (markAbsentSmart
            // writes one once a shift ends). That converts into a real arrival;
            // only a row that already has a time is a genuine duplicate.
            if ($existing && !empty($existing['check_in_time'])) {
                $skipped[$employeeId] = 'already_checked_in';
                continue;
            }

            $employee = EmployeeModel::findById($employeeId, $tenantId);
            if (!$employee) {
                $skipped[$employeeId] = 'not_found';
                continue;
            }

            $employee = self::withScheduledShift($employee, $tenantId, $today);
            $expectedStart = $employee['shift_start'] ?? $employee['work_start_time'] ?? '09:00:00';
            $lateMinutes = max(0, (strtotime($time) - strtotime($expectedStart)) / 60);

            if ($existing) {
                Database::execute(
                    "UPDATE attendance
                     SET branch_id = ?, check_in_time = ?, check_in_method = 'crew_gps',
                         late_minutes = ?, status = 'present',
                         check_in_latitude = ?, check_in_longitude = ?,
                         recorded_by_employee_id = ?, crew_photo = COALESCE(?, crew_photo)
                     WHERE id = ?",
                    [$branchId, $time, (int) $lateMinutes, $lat, $lng, $supervisorId, $photoPath, $existing['id']]
                );
            } else {
                Database::execute(
                    "INSERT INTO attendance
                        (tenant_id, branch_id, employee_id, date, check_in_time, check_in_method,
                         late_minutes, status, check_in_latitude, check_in_longitude,
                         recorded_by_employee_id, crew_photo)
                     VALUES (?, ?, ?, ?, ?, 'crew_gps', ?, 'present', ?, ?, ?, ?)",
                    [$tenantId, $branchId, $employeeId, $today, $time, (int) $lateMinutes, $lat, $lng, $supervisorId, $photoPath]
                );
            }

            $recorded[] = $employeeId;
        }

        return ['recorded' => $recorded, 'skipped' => $skipped];
    }

    /**
     * Closes the day for a crew. Same batch-survives-failures rule as above:
     * checkOut() ends the request when somebody has no open day, which here
     * would be one absent labourer costing the other twenty-nine their
     * check-out.
     *
     * @param int[] $employeeIds Already authorised by the caller.
     * @return array{recorded: int[], skipped: array<int, string>}
     */
    public static function crewCheckOut(
        array $employeeIds,
        int $tenantId,
        int $supervisorId,
        ?string $photoPath
    ): array {
        $now = TenantClock::now($tenantId);
        $today = $now->format('Y-m-d');
        $time = $now->format('H:i:s');

        $recorded = [];
        $skipped = [];

        foreach ($employeeIds as $rawId) {
            $employeeId = (int) $rawId;

            $record = Database::fetchOne(
                "SELECT id, check_in_time, check_out_time FROM attendance
                 WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
                [$employeeId, $today, $tenantId]
            );

            if (!$record || empty($record['check_in_time'])) {
                $skipped[$employeeId] = 'not_checked_in';
                continue;
            }
            if (!empty($record['check_out_time'])) {
                $skipped[$employeeId] = 'already_checked_out';
                continue;
            }

            $employee = EmployeeModel::findById($employeeId, $tenantId);
            if (!$employee) {
                $skipped[$employeeId] = 'not_found';
                continue;
            }

            $employee = self::withScheduledShift($employee, $tenantId, $today);
            $workEnd = $employee['shift_end'] ?? $employee['work_end_time'] ?? '17:00:00';

            $checkIn = strtotime($record['check_in_time']);
            $checkOut = strtotime($time);
            $workedMinutes = max(0, ($checkOut - $checkIn) / 60);
            $overtimeMinutes = max(0, ($checkOut - strtotime($workEnd)) / 60);

            Database::execute(
                "UPDATE attendance
                 SET check_out_time = ?, check_out_method = 'crew_gps',
                     worked_minutes = ?, overtime_minutes = ?,
                     recorded_by_employee_id = COALESCE(recorded_by_employee_id, ?),
                     crew_photo = COALESCE(?, crew_photo)
                 WHERE id = ?",
                [$time, (int) $workedMinutes, (int) $overtimeMinutes, $supervisorId, $photoPath, $record['id']]
            );

            $recorded[] = $employeeId;
        }

        return ['recorded' => $recorded, 'skipped' => $skipped];
    }

    public static function manualCheckIn(int $employeeId, int $branchId, int $tenantId, string $date, string $checkInTime, string $checkOutTime, int $recordedBy): int {
        $employee = EmployeeModel::findById($employeeId, $tenantId);
        $employee = self::withScheduledShift($employee, $tenantId, $date);
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
        $employee = self::withScheduledShift($employee, $tenantId, $date);
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

    public static function updateNote(int $tenantId, int $employeeId, string $date, ?string $note): int {
        $clean = $note === null ? null : substr(trim($note), 0, 2000);
        return Database::execute(
            "UPDATE attendance SET notes = ? WHERE employee_id = ? AND date = ? AND tenant_id = ?",
            [$clean, $employeeId, $date, $tenantId]
        );
    }

    public static function updateNoteById(int $tenantId, int $attendanceId, ?string $note): int {
        $clean = $note === null ? null : substr(trim($note), 0, 2000);
        return Database::execute(
            "UPDATE attendance SET notes = ? WHERE id = ? AND tenant_id = ?",
            [$clean, $attendanceId, $tenantId]
        );
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
        $employee = self::withScheduledShift($employee, $tenantId, $date);
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

    /**
     * Unified day-status editor. Sets one calendar day to present/absent/leave,
     * creating the attendance row when it doesn't exist, and keeps the `leaves`
     * table in sync so the annual-leave balance stays correct in both directions.
     *
     * @param array       $employee   Employee row (already tenant-scoped).
     * @param string      $status     'present' | 'absent' | 'leave'
     * @param string|null $checkIn    'HH:MM[:SS]' — present only, optional.
     * @param string|null $checkOut   'HH:MM[:SS]' — present only, optional.
     * @param string|null $leaveType  'annual' | 'sick' | 'personal' | 'unpaid' — leave only.
     * @param string|null $reason     Optional note / leave reason.
     * @param string      $deductionMode  'auto' | 'days' | 'amount' — absent only.
     * @param float|null  $deductionValue Days count (mode=days) or money (mode=amount).
     * @return array  The resulting attendance row.
     */
    public static function setDayStatus(
        array $employee,
        int $tenantId,
        string $date,
        string $status,
        ?string $checkIn,
        ?string $checkOut,
        ?string $leaveType,
        ?string $reason,
        int $recordedBy,
        string $deductionMode = 'auto',
        ?float $deductionValue = null
    ): array {
        // Deduction override only applies to absent days; reset otherwise.
        if ($status !== 'absent') {
            $deductionMode = 'auto';
            $deductionValue = null;
        }
        if ($deductionMode === 'auto') {
            $deductionValue = null;
        }
        $employeeId = (int) $employee['id'];

        $existing = Database::fetchOne(
            "SELECT id, branch_id, status FROM attendance
             WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $date, $tenantId]
        );
        $wasLeave = $existing && $existing['status'] === 'leave';
        $branchId = $existing['branch_id'] ?? $employee['branch_id'] ?? null;

        // Compute the per-status column values.
        $checkInVal = null;
        $checkOutVal = null;
        $lateMinutes = 0;
        $workedMinutes = 0;
        $overtimeMinutes = 0;

        if ($status === 'present') {
            $shiftEmployee = self::withScheduledShift($employee, $tenantId, $date);
            $workStart = $shiftEmployee['shift_start'] ?? $shiftEmployee['work_start_time'] ?? '09:00:00';
            $workEnd   = $shiftEmployee['shift_end']   ?? $shiftEmployee['work_end_time']   ?? '17:00:00';

            $checkInVal  = $checkIn;
            $checkOutVal = $checkOut;
            if ($checkInVal !== null) {
                $lateMinutes = max(0, (int) ((strtotime($checkInVal) - strtotime($workStart)) / 60));
            }
            if ($checkInVal !== null && $checkOutVal !== null) {
                $workedMinutes = max(0, (int) ((strtotime($checkOutVal) - strtotime($checkInVal)) / 60));
            }
            if ($checkOutVal !== null) {
                $overtimeMinutes = max(0, (int) ((strtotime($checkOutVal) - strtotime($workEnd)) / 60));
            }
        }

        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            if ($existing) {
                Database::execute(
                    "UPDATE attendance SET
                        status = ?,
                        check_in_time = ?,
                        check_out_time = ?,
                        check_in_method = 'manual',
                        check_out_method = CASE WHEN ? IS NOT NULL THEN 'manual' ELSE NULL END,
                        late_minutes = ?,
                        worked_minutes = ?,
                        overtime_minutes = ?,
                        early_leave_minutes = 0,
                        notes = ?,
                        recorded_by = ?,
                        deduction_mode = ?,
                        deduction_value = ?,
                        branch_id = COALESCE(branch_id, ?)
                     WHERE id = ?",
                    [
                        $status, $checkInVal, $checkOutVal, $checkOutVal,
                        $lateMinutes, $workedMinutes, $overtimeMinutes,
                        $reason, $recordedBy, $deductionMode, $deductionValue,
                        $branchId, $existing['id'],
                    ]
                );
                $attendanceId = (int) $existing['id'];
            } else {
                if (!$branchId) {
                    Response::fail('Employee has no branch — cannot create an attendance record', 422);
                }
                Database::execute(
                    "INSERT INTO attendance
                        (tenant_id, branch_id, employee_id, date, status,
                         check_in_time, check_out_time, check_in_method, check_out_method,
                         late_minutes, worked_minutes, overtime_minutes, notes, recorded_by,
                         deduction_mode, deduction_value)
                     VALUES (?, ?, ?, ?, ?, ?, ?, 'manual',
                             CASE WHEN ? IS NOT NULL THEN 'manual' ELSE NULL END,
                             ?, ?, ?, ?, ?, ?, ?)",
                    [
                        $tenantId, $branchId, $employeeId, $date, $status,
                        $checkInVal, $checkOutVal, $checkOutVal,
                        $lateMinutes, $workedMinutes, $overtimeMinutes, $reason, $recordedBy,
                        $deductionMode, $deductionValue,
                    ]
                );
                $attendanceId = (int) Database::lastInsertId();
            }

            // Sync the leaves table so the balance stays correct both ways.
            if ($status === 'leave') {
                // Replace any existing approved single-day leave for this date.
                Database::execute(
                    "DELETE FROM leaves
                     WHERE employee_id = ? AND tenant_id = ? AND date = ? AND start_date = end_date",
                    [$employeeId, $tenantId, $date]
                );
                Database::execute(
                    "INSERT INTO leaves
                        (tenant_id, employee_id, date, start_date, end_date, type, reason, status, approved_by, approved_at)
                     VALUES (?, ?, ?, ?, ?, ?, ?, 'approved', ?, NOW())",
                    [$tenantId, $employeeId, $date, $date, $date, $leaveType ?? 'annual', $reason, $recordedBy]
                );
            } elseif ($wasLeave) {
                // Leaving the leave state — free up the single-day approved leave.
                Database::execute(
                    "DELETE FROM leaves
                     WHERE employee_id = ? AND tenant_id = ? AND date = ? AND start_date = end_date",
                    [$employeeId, $tenantId, $date]
                );
            }

            $con->commit();
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }

        return Database::fetchOne(
            "SELECT id, employee_id,
                    DATE_FORMAT(date, '%Y-%m-%d') AS date,
                    status, check_in_time, check_out_time,
                    late_minutes, worked_minutes, overtime_minutes, notes,
                    deduction_mode, deduction_value
             FROM attendance WHERE id = ?",
            [$attendanceId]
        ) ?? [];
    }

    public static function getByEmployeeMonth(int $employeeId, string $month, int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM attendance WHERE employee_id = ? AND DATE_FORMAT(date, '%Y-%m') = ? AND tenant_id = ? ORDER BY date ASC",
            [$employeeId, $month, $tenantId]
        );
    }

    public static function getByEmployeeDateRange(int $employeeId, string $startDate, string $endDate, int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM attendance WHERE employee_id = ? AND date BETWEEN ? AND ? AND tenant_id = ? ORDER BY date ASC",
            [$employeeId, $startDate, $endDate, $tenantId]
        );
    }

    /** Number of employees who checked in on a given date (for trend deltas). */
    public static function countPresentOnDate(int $tenantId, string $date, ?int $branchId = null): int {
        $sql = "SELECT COUNT(*) AS c FROM attendance
                WHERE tenant_id = ? AND date = ? AND check_in_time IS NOT NULL";
        $params = [$tenantId, $date];
        if ($branchId) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }
        return (int) (Database::fetchOne($sql, $params)['c'] ?? 0);
    }

    public static function getByDate(int $tenantId, string $date, ?int $branchId = null): array {
        // Start from active employees so those without an attendance row for
        // the day still appear as "not arrived yet" instead of being invisible.
        $sql = "SELECT
                    a.id,
                    e.id AS employee_id,
                    e.name AS employee_name,
                    e.job_title,
                    COALESCE(a.date, ?) AS date,
                    a.check_in_time,
                    a.check_out_time,
                    COALESCE(a.status, 'not_arrived') AS status,
                    a.late_minutes,
                    a.overtime_minutes,
                    a.notes,
                    a.deduction_mode,
                    a.deduction_value,
                    -- Channel and evidence for the review screen. The photo
                    -- columns carry the stored path, which is never a URL a
                    -- client can fetch: images come from punch_photo.php, which
                    -- checks the caller may review this employee first.
                    a.check_in_origin,
                    a.check_out_origin,
                    a.check_in_photo,
                    a.check_out_photo,
                    COALESCE(a.shared_device_flag, 0) AS shared_device_flag,
                    b.name AS branch_name,
                    COALESCE(ss.name, s.name) AS shift_name,
                    COALESCE(ss.start_time, s.start_time, e.work_start_time) AS shift_start,
                    COALESCE(ss.end_time,   s.end_time,   e.work_end_time)   AS shift_end
                FROM employees e
                LEFT JOIN attendance a
                    ON a.employee_id = e.id AND a.date = ? AND a.tenant_id = e.tenant_id
                LEFT JOIN branches b ON b.id = COALESCE(a.branch_id, e.branch_id)
                LEFT JOIN employee_shift_schedule sch
                    ON sch.employee_id = e.id AND sch.work_date = ?
                   AND sch.tenant_id = e.tenant_id
                LEFT JOIN shifts ss ON ss.id = sch.shift_id
                LEFT JOIN shifts s  ON s.id  = e.shift_id
                WHERE e.tenant_id = ? AND e.status = 'active'";
        $params = [$date, $date, $date, $tenantId];

        if ($branchId) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }

        $sql .= " ORDER BY e.name ASC";
        return Database::fetchAll($sql, $params);
    }

    public static function getLiveBoard(
        int $tenantId,
        string $date,
        ?int $branchId = null,
        ?int $shiftId = null,
        ?int $categoryId = null
    ): array {
        // Start from active employees so those with no attendance row today
        // still appear (derived as "not_in" or "pre_shift" by the caller).
        // Effective shift_start / shift_end for the date are resolved with the
        // same priority as everywhere else: rotating schedule → default shift →
        // per-employee work hours. The caller uses them to distinguish "shift
        // has not started yet" (pre_shift) from "no-show during shift" (not_in).
        $sql = "SELECT
                    e.id AS employee_id,
                    e.name,
                    e.job_title,
                    e.branch_id,
                    b.name AS branch_name,
                    a.check_in_time,
                    a.check_out_time,
                    a.status AS attendance_status,
                    a.notes AS attendance_notes,
                    a.late_minutes,
                    a.check_in_method,
                    a.is_offline,
                    COALESCE(ss.start_time, s.start_time, e.work_start_time) AS shift_start,
                    COALESCE(ss.end_time,   s.end_time,   e.work_end_time)   AS shift_end
                FROM employees e
                LEFT JOIN branches b ON b.id = e.branch_id
                LEFT JOIN attendance a
                    ON a.employee_id = e.id AND a.date = ? AND a.tenant_id = e.tenant_id
                LEFT JOIN employee_shift_schedule sch
                    ON sch.employee_id = e.id AND sch.work_date = ?
                   AND sch.tenant_id = e.tenant_id
                LEFT JOIN shifts ss ON ss.id = sch.shift_id
                LEFT JOIN shifts s  ON s.id  = e.shift_id
                WHERE e.tenant_id = ? AND e.status = 'active'";
        $params = [$date, $date, $tenantId];

        if ($branchId) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }

        if ($shiftId) {
            $sql .= " AND e.shift_id = ?";
            $params[] = $shiftId;
        }

        if ($categoryId) {
            $sql .= " AND EXISTS (
                        SELECT 1 FROM employee_category_assignments eca
                        WHERE eca.employee_id = e.id AND eca.category_id = ?
                      )";
            $params[] = $categoryId;
        }

        $sql .= " ORDER BY e.name ASC";
        return Database::fetchAll($sql, $params);
    }

    /**
     * Lazy, shift-aware absence writer used by the on-access catch-up (no cron).
     *
     * Inserts an 'absent' row for each active employee with no attendance row on
     * $date, skipping approved leave, weekly-off days, holidays, recurring
     * leaves, and rotating-schedule rest days (a schedule cell whose shift_id is
     * NULL).
     *
     * @param string|null $nowTime When null, $date is treated as a *completed*
     *   day and every remaining no-show is marked. When a 'HH:MM:SS' time (now,
     *   in the tenant timezone), only employees whose shift has already ended by
     *   that time are marked; overnight shifts (end <= start) are deferred to the
     *   next day's backfill. Idempotent via the unique (employee_id, date) key.
     */
    public static function markAbsentSmart(int $tenantId, string $date, ?string $nowTime = null): int {
        $weekday = strtolower(date('l', strtotime($date)));

        // Active employees with no row that day, plus their effective shift for
        // the day (rotating schedule cell overrides the default shift).
        $employees = Database::fetchAll(
            "SELECT e.id, e.branch_id, e.weekly_off_days, e.work_end_time,
                    sch.id AS sched_id, sch.shift_id AS sched_shift_id,
                    s.start_time AS shift_start, s.end_time AS shift_end
             FROM employees e
             LEFT JOIN employee_shift_schedule sch
                    ON sch.employee_id = e.id AND sch.work_date = ?
                   AND sch.tenant_id = e.tenant_id
             LEFT JOIN shifts s ON s.id = COALESCE(sch.shift_id, e.shift_id)
             WHERE e.tenant_id = ? AND e.status = 'active'
               AND NOT EXISTS (
                   SELECT 1 FROM attendance a
                   WHERE a.employee_id = e.id AND a.date = ? AND a.tenant_id = e.tenant_id
               )",
            [$date, $tenantId, $date]
        );
        if (!$employees) {
            return 0;
        }

        $onLeave = array_flip(array_column(
            Database::fetchAll(
                "SELECT employee_id FROM leaves WHERE tenant_id = ? AND date = ? AND status = 'approved'",
                [$tenantId, $date]
            ),
            'employee_id'
        ));
        [$holidayAll, $holidayBranches] = self::scopeFlags(Database::fetchAll(
            "SELECT branch_id FROM holidays WHERE tenant_id = ? AND date = ?",
            [$tenantId, $date]
        ));
        [$recurAll, $recurBranches] = self::scopeFlags(Database::fetchAll(
            "SELECT branch_id FROM recurring_leaves
             WHERE tenant_id = ? AND day_of_week = ? AND is_active = 1",
            [$tenantId, $weekday]
        ));

        $count = 0;
        foreach ($employees as $e) {
            $eid = (int) $e['id'];
            $bid = $e['branch_id'] !== null ? (int) $e['branch_id'] : null;

            if (isset($onLeave[$eid])) {
                continue;
            }
            $woff = (string) ($e['weekly_off_days'] ?? '');
            if ($woff !== '' && in_array($weekday, array_map('trim', explode(',', $woff)), true)) {
                continue;
            }
            if ($holidayAll || ($bid !== null && isset($holidayBranches[$bid]))) {
                continue;
            }
            if ($recurAll || ($bid !== null && isset($recurBranches[$bid]))) {
                continue;
            }
            // Rotating rest day: an explicit schedule cell with no shift.
            if ($e['sched_id'] !== null && $e['sched_shift_id'] === null) {
                continue;
            }

            // For the in-progress day, only confirm absence once the shift ends.
            if ($nowTime !== null) {
                $end = $e['shift_end'] ?? $e['work_end_time'];
                $start = $e['shift_start'];
                if ($end === null) {
                    continue; // can't tell when the day ends → wait
                }
                if ($start !== null && $end <= $start) {
                    continue; // overnight shift → ends next day, defer
                }
                if ($nowTime < $end) {
                    continue; // shift not over yet → still "not arrived"
                }
            }

            Database::execute(
                "INSERT IGNORE INTO attendance (tenant_id, branch_id, employee_id, date, status)
                 VALUES (?, ?, ?, ?, 'absent')",
                [$tenantId, $bid, $eid, $date]
            );
            $count++;
        }
        return $count;
    }

    /**
     * On-access catch-up that replaces the daily cron: persists absences without
     * a scheduler. Backfills every completed day since the tenant's last
     * materialized date (bounded by [maxBackfillDays]), advances the marker, then
     * runs a shift-aware pass for today (only shifts that have already ended).
     * Idempotent and cheap to call on every dashboard load.
     */
    public static function catchUpAbsences(int $tenantId, ?string $tz): array {
        $maxBackfillDays = 14;
        try {
            $now = new DateTime('now', $tz ? new DateTimeZone($tz) : null);
        } catch (Exception $e) {
            $now = new DateTime('now');
        }
        $today = (clone $now)->setTime(0, 0, 0);
        $yesterday = (clone $today)->modify('-1 day');
        $earliest = (clone $today)->modify('-' . $maxBackfillDays . ' days');

        $row = Database::fetchOne(
            "SELECT last_absence_date FROM tenants WHERE id = ?",
            [$tenantId]
        );
        $marker = !empty($row['last_absence_date'])
            ? new DateTime($row['last_absence_date'])
            : null;

        $start = $marker ? (clone $marker)->modify('+1 day') : $earliest;
        if ($start < $earliest) {
            $start = $earliest;
        }

        $days = 0;
        $marked = 0;
        if ($start <= $yesterday) {
            $cursor = clone $start;
            while ($cursor <= $yesterday) {
                $marked += self::markAbsentSmart($tenantId, $cursor->format('Y-m-d'));
                $days++;
                $cursor->modify('+1 day');
            }
            Database::execute(
                "UPDATE tenants SET last_absence_date = ? WHERE id = ?",
                [$yesterday->format('Y-m-d'), $tenantId]
            );
        }

        // In-progress day: confirm only the employees whose shift already ended.
        $todayMarked = self::markAbsentSmart(
            $tenantId,
            $today->format('Y-m-d'),
            $now->format('H:i:s')
        );

        return [
            'backfilled_days' => $days,
            'backfilled_marked' => $marked,
            'today_marked' => $todayMarked,
        ];
    }

    /**
     * Builds a complete, gap-free attendance calendar for one employee over a
     * date range — the data behind the employee-profile "attendance" tab.
     *
     * Materialized rows are returned as-is. For every working day in the range
     * that has no row, a *virtual* record is synthesized with the correct status
     * so the tab never shows blank days:
     *   - approved leave            → 'leave'   (with leave_type)
     *   - holiday (all/this branch) → 'holiday'
     *   - weekly-off / recurring leave / rotating rest day → 'weekly_off'
     *   - past working no-show      → 'absent'
     *   - today, shift already over → 'absent'
     *   - today, shift not over yet → 'not_arrived'  ("لم يحضر")
     *
     * Mirrors the exclusion logic of {@see markAbsentSmart} but is scoped to a
     * single employee and a whole range (a handful of queries, no per-day SQL).
     * Synthetic rows carry id = null and 'synthetic' => true. Future days (after
     * today) are not synthesized; existing rows for any date are always kept.
     */
    public static function getEmployeeAttendanceCalendar(
        int $employeeId,
        int $tenantId,
        string $from,
        string $to,
        ?string $tz
    ): array {
        try {
            $now = new DateTime('now', $tz ? new DateTimeZone($tz) : null);
        } catch (Exception $e) {
            $now = new DateTime('now');
        }
        $today = $now->format('Y-m-d');
        $nowTime = $now->format('H:i:s');

        // 1) Materialized rows (+ single-day approved leave type), keyed by date.
        $rows = Database::fetchAll(
            "SELECT
                a.id,
                a.employee_id,
                DATE_FORMAT(a.date, '%Y-%m-%d') AS date,
                CASE WHEN a.check_in_time IS NOT NULL
                     THEN CONCAT(DATE_FORMAT(a.date, '%Y-%m-%d'), 'T', a.check_in_time)
                END AS check_in,
                CASE WHEN a.check_out_time IS NOT NULL
                     THEN CONCAT(DATE_FORMAT(a.date, '%Y-%m-%d'), 'T', a.check_out_time)
                END AS check_out,
                a.status,
                a.late_minutes,
                a.overtime_minutes,
                a.worked_minutes,
                a.notes AS note,
                a.deduction_mode,
                a.deduction_value,
                l.type AS leave_type
             FROM attendance a
             LEFT JOIN leaves l
                    ON l.employee_id = a.employee_id
                   AND l.tenant_id = a.tenant_id
                   AND l.date = a.date
                   AND l.start_date = l.end_date
                   AND l.status = 'approved'
             WHERE a.employee_id = ?
               AND a.tenant_id = ?
               AND a.date BETWEEN ? AND ?",
            [$employeeId, $tenantId, $from, $to]
        );
        $byDate = [];
        $out = [];
        foreach ($rows as $r) {
            $byDate[$r['date']] = true;
            $r['synthetic'] = false;
            $out[] = $r;
        }

        // 2) Employee profile: branch, weekly-off days, default shift hours.
        $emp = Database::fetchOne(
            "SELECT e.branch_id, e.weekly_off_days, e.shift_id,
                    e.work_start_time, e.work_end_time,
                    s.start_time AS shift_start, s.end_time AS shift_end
             FROM employees e
             LEFT JOIN shifts s ON s.id = e.shift_id
             WHERE e.id = ? AND e.tenant_id = ?",
            [$employeeId, $tenantId]
        );
        if (!$emp) {
            usort($out, fn($a, $b) => strcmp($b['date'], $a['date']));
            return $out;
        }
        $branchId = $emp['branch_id'] !== null ? (int) $emp['branch_id'] : null;
        $weeklyOff = array_filter(array_map(
            'trim',
            explode(',', (string) ($emp['weekly_off_days'] ?? ''))
        ));

        // 3) Approved leaves (per-day rows, mirroring markAbsentSmart).
        $leaveByDate = [];
        foreach (Database::fetchAll(
            "SELECT DATE_FORMAT(date, '%Y-%m-%d') AS d, type
             FROM leaves
             WHERE tenant_id = ? AND employee_id = ? AND status = 'approved'
               AND date BETWEEN ? AND ?",
            [$tenantId, $employeeId, $from, $to]
        ) as $lr) {
            $leaveByDate[$lr['d']] = $lr['type'];
        }

        // 4) Holidays (all-branch or this employee's branch).
        $holidayDates = [];
        foreach (Database::fetchAll(
            "SELECT DATE_FORMAT(date, '%Y-%m-%d') AS d, branch_id
             FROM holidays
             WHERE tenant_id = ? AND date BETWEEN ? AND ?",
            [$tenantId, $from, $to]
        ) as $hr) {
            if ($hr['branch_id'] === null
                || ($branchId !== null && (int) $hr['branch_id'] === $branchId)) {
                $holidayDates[$hr['d']] = true;
            }
        }

        // 5) Recurring weekly leaves applicable to the employee's branch.
        $recurDays = [];
        foreach (Database::fetchAll(
            "SELECT day_of_week, branch_id FROM recurring_leaves
             WHERE tenant_id = ? AND is_active = 1",
            [$tenantId]
        ) as $rl) {
            if ($rl['branch_id'] === null
                || ($branchId !== null && (int) $rl['branch_id'] === $branchId)) {
                $recurDays[strtolower((string) $rl['day_of_week'])] = true;
            }
        }

        // 6) Rotating schedule cells in range (cell with NULL shift = rest day).
        $schedByDate = [];
        foreach (Database::fetchAll(
            "SELECT DATE_FORMAT(sch.work_date, '%Y-%m-%d') AS d, sch.shift_id,
                    s.start_time AS shift_start, s.end_time AS shift_end
             FROM employee_shift_schedule sch
             LEFT JOIN shifts s ON s.id = sch.shift_id
             WHERE sch.tenant_id = ? AND sch.employee_id = ?
               AND sch.work_date BETWEEN ? AND ?",
            [$tenantId, $employeeId, $from, $to]
        ) as $sr) {
            $schedByDate[$sr['d']] = $sr;
        }

        // Walk each day up to today and synthesize the gaps.
        $endDate = ($to <= $today) ? $to : $today;
        $cursor = new DateTime($from);
        $last = new DateTime($endDate);
        while ($cursor <= $last) {
            $d = $cursor->format('Y-m-d');
            if (isset($byDate[$d])) {
                $cursor->modify('+1 day');
                continue;
            }
            $weekday = strtolower($cursor->format('l'));
            $status = null;
            $leaveType = null;

            $sched = $schedByDate[$d] ?? null;
            if (isset($leaveByDate[$d])) {
                $status = 'leave';
                $leaveType = $leaveByDate[$d];
            } elseif (isset($holidayDates[$d])) {
                $status = 'holiday';
            } elseif (in_array($weekday, $weeklyOff, true) || isset($recurDays[$weekday])) {
                $status = 'weekly_off';
            } elseif ($sched !== null && $sched['shift_id'] === null) {
                $status = 'weekly_off'; // explicit rotating rest day
            } else {
                // Working day with no attendance row.
                if ($sched !== null && $sched['shift_id'] !== null) {
                    $shiftEnd = $sched['shift_end'];
                    $shiftStart = $sched['shift_start'];
                } else {
                    $shiftEnd = $emp['shift_end'] ?? $emp['work_end_time'];
                    $shiftStart = $emp['shift_start'] ?? $emp['work_start_time'];
                }

                if ($d < $today) {
                    $status = 'absent';
                } elseif ($shiftEnd === null) {
                    $status = 'not_arrived'; // can't tell when the day ends
                } elseif ($shiftStart !== null && $shiftEnd <= $shiftStart) {
                    $status = 'not_arrived'; // overnight shift → defer
                } elseif ($nowTime >= $shiftEnd) {
                    $status = 'absent';
                } else {
                    $status = 'not_arrived';
                }
            }

            $out[] = [
                'id' => null,
                'employee_id' => $employeeId,
                'date' => $d,
                'check_in' => null,
                'check_out' => null,
                'status' => $status,
                'late_minutes' => 0,
                'overtime_minutes' => 0,
                'worked_minutes' => 0,
                'note' => null,
                'deduction_mode' => null,
                'deduction_value' => null,
                'leave_type' => $leaveType,
                'synthetic' => true,
            ];
            $cursor->modify('+1 day');
        }

        usort($out, fn($a, $b) => strcmp($b['date'], $a['date']));
        return $out;
    }

    /** Splits branch-scoped rows into [appliesToAllBranches, {branchId: true}]. */
    private static function scopeFlags(array $rows): array {
        $all = false;
        $branches = [];
        foreach ($rows as $r) {
            if ($r['branch_id'] === null) {
                $all = true;
            } else {
                $branches[(int) $r['branch_id']] = true;
            }
        }
        return [$all, $branches];
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

                $recIsMock = !empty($rec['is_mock_location']) && (int) $rec['is_mock_location'] === 1;
                $recIsVpn = !empty($rec['is_vpn']) && (int) $rec['is_vpn'] === 1;

                if ($recIsMock) {
                    AttendanceSecurityModel::log($tenantId, $employeeId, $branchId, 'mock_location', 'blocked', $lat ?: null, $lng ?: null);
                    $results[] = ['client_record_id' => $clientRecordId, 'status' => 'rejected', 'reason' => 'MOCK_LOCATION'];
                    $failed++;
                    continue;
                }

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
                $employee = self::withScheduledShift($employee, $tenantId, $date);
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
                        check_in_latitude, check_in_longitude, check_in_method, status, is_offline, synced_at, late_minutes, worked_minutes, overtime_minutes, is_vpn)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'offline', 'present', 1, NOW(), ?, ?, ?, ?)
                     ON DUPLICATE KEY UPDATE
                        check_out_time = COALESCE(VALUES(check_out_time), check_out_time),
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
                        $recIsVpn ? 1 : 0,
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

    // ------------------------------------------------------------------
    // Overtime / lateness report
    // ------------------------------------------------------------------
    //
    // Both minute counters are written by the check-in / check-out path (see
    // checkIn/checkOut above) against the employee's shift, so the report only
    // has to aggregate them. Only `present` days carry minutes — an absence or
    // a leave day has none — so every query below is scoped to that status.
    //
    // `early_leave_minutes` exists in the table but nothing ever writes it, so
    // it is deliberately left out rather than shown as a permanent zero.

    /**
     * Per-employee overtime and lateness totals for a period.
     *
     * Employees with neither overtime nor lateness are dropped (HAVING): the
     * page exists to surface who is running over and who arrives late, and a
     * list padded with zero rows buries exactly that.
     */
    public static function getOvertimeLateReport(
        int $tenantId,
        string $startDate,
        string $endDate,
        ?int $branchId = null,
        string $sort = 'overtime'
    ): array {
        // Whitelisted — never interpolate a client-supplied sort into SQL.
        $orderBy = match ($sort) {
            'late' => 'late_minutes DESC, overtime_minutes DESC',
            'name' => 'e.name ASC',
            default => 'overtime_minutes DESC, late_minutes DESC',
        };

        $sql = "SELECT
                    e.id as employee_id,
                    e.name as employee_name,
                    e.job_title,
                    b.name as branch_name,
                    COALESCE(SUM(a.overtime_minutes), 0) as overtime_minutes,
                    COUNT(CASE WHEN a.overtime_minutes > 0 THEN 1 END) as overtime_days,
                    COALESCE(SUM(a.late_minutes), 0) as late_minutes,
                    COUNT(CASE WHEN a.late_minutes > 0 THEN 1 END) as late_days,
                    COALESCE(MAX(a.late_minutes), 0) as worst_late_minutes,
                    COALESCE(SUM(a.worked_minutes), 0) as worked_minutes,
                    COUNT(a.id) as days_present
                FROM employees e
                LEFT JOIN branches b ON b.id = e.branch_id
                JOIN attendance a ON a.employee_id = e.id
                    AND a.date BETWEEN ? AND ?
                    AND a.status = 'present'
                WHERE e.tenant_id = ? AND e.status != 'terminated'";
        $params = [$startDate, $endDate, $tenantId];
        if ($branchId !== null) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        $sql .= " GROUP BY e.id
                  HAVING overtime_minutes > 0 OR late_minutes > 0
                  ORDER BY {$orderBy}";
        return Database::fetchAll($sql, $params);
    }

    /** Company-wide overtime / lateness totals for the same period + filter. */
    public static function getOvertimeLateSummary(
        int $tenantId,
        string $startDate,
        string $endDate,
        ?int $branchId = null
    ): array {
        $sql = "SELECT
                    COALESCE(SUM(a.overtime_minutes), 0) as total_overtime_minutes,
                    COALESCE(SUM(a.late_minutes), 0) as total_late_minutes,
                    COUNT(CASE WHEN a.overtime_minutes > 0 THEN 1 END) as overtime_days,
                    COUNT(CASE WHEN a.late_minutes > 0 THEN 1 END) as late_days,
                    COUNT(DISTINCT CASE WHEN a.overtime_minutes > 0 THEN a.employee_id END) as employees_with_overtime,
                    COUNT(DISTINCT CASE WHEN a.late_minutes > 0 THEN a.employee_id END) as employees_late
                FROM attendance a
                JOIN employees e ON e.id = a.employee_id
                WHERE a.tenant_id = ?
                  AND a.date BETWEEN ? AND ?
                  AND a.status = 'present'
                  AND e.status != 'terminated'";
        $params = [$tenantId, $startDate, $endDate];
        if ($branchId !== null) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        $row = Database::fetchOne($sql, $params);
        return $row ?: [
            'total_overtime_minutes' => 0,
            'total_late_minutes' => 0,
            'overtime_days' => 0,
            'late_days' => 0,
            'employees_with_overtime' => 0,
            'employees_late' => 0,
        ];
    }

    /**
     * Day-by-day overtime / lateness for one employee — the drill-down behind a
     * row of the report. Only days that actually carry minutes are returned.
     */
    public static function getOvertimeLateDaily(
        int $tenantId,
        int $employeeId,
        string $startDate,
        string $endDate
    ): array {
        return Database::fetchAll(
            "SELECT a.date, a.check_in_time, a.check_out_time,
                    a.late_minutes, a.overtime_minutes, a.worked_minutes, a.notes
             FROM attendance a
             WHERE a.tenant_id = ?
               AND a.employee_id = ?
               AND a.date BETWEEN ? AND ?
               AND a.status = 'present'
               AND (a.late_minutes > 0 OR a.overtime_minutes > 0)
             ORDER BY a.date DESC
             LIMIT 366",
            [$tenantId, $employeeId, $startDate, $endDate]
        );
    }

    // ------------------------------------------------------------------
    // Biometric device punches
    // ------------------------------------------------------------------
    //
    // These deliberately do NOT call Response::fail. A terminal delivers its
    // punches in batches and deletes its local copy once we answer OK; a
    // Response::fail in the middle of a batch would exit the request, lose the
    // remaining punches, and make the device retry the same batch forever.
    // Every outcome here is a return value.

    /**
     * Applies a device punch as the day's check-in.
     *
     * An earlier punch wins over one already recorded: terminals buffer and
     * re-send out of order after a power cut, and the earliest tap of the day
     * is the one that actually happened at the door.
     */
    public static function deviceCheckIn(
        int $employeeId,
        int $branchId,
        int $tenantId,
        string $date,
        string $time,
        ?string $recognitionMethod = null
    ): array {
        $existing = Database::fetchOne(
            "SELECT id, check_in_time, check_out_time FROM attendance
             WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $date, $tenantId]
        );

        if ($existing && !empty($existing['check_in_time'])
            && strtotime($existing['check_in_time']) <= strtotime($time)) {
            return [
                'attendance_id' => (int) $existing['id'],
                'changed' => false,
                'note' => 'Later than the recorded check-in',
            ];
        }

        $employee = EmployeeModel::findById($employeeId, $tenantId);
        $employee = self::withScheduledShift($employee, $tenantId, $date);
        $expectedStart = $employee['shift_start'] ?? $employee['work_start_time'] ?? '09:00:00';
        $lateMinutes = (int) max(0, (strtotime($time) - strtotime($expectedStart)) / 60);

        if ($existing) {
            Database::execute(
                "UPDATE attendance
                 SET branch_id = ?, check_in_time = ?, check_in_method = 'device',
                     late_minutes = ?, status = 'present', recognition_method = ?
                 WHERE id = ?",
                [$branchId, $time, $lateMinutes, $recognitionMethod, $existing['id']]
            );
            $attendanceId = (int) $existing['id'];
        } else {
            Database::execute(
                "INSERT INTO attendance
                    (tenant_id, branch_id, employee_id, date, check_in_time, check_in_method,
                     late_minutes, status, recognition_method)
                 VALUES (?, ?, ?, ?, ?, 'device', ?, 'present', ?)",
                [$tenantId, $branchId, $employeeId, $date, $time, $lateMinutes, $recognitionMethod]
            );
            $attendanceId = (int) Database::lastInsertId();
        }

        if (!empty($existing['check_out_time'])) {
            self::recomputeWorkedMinutes($attendanceId, $employeeId, $tenantId, $date);
        }

        return ['attendance_id' => $attendanceId, 'changed' => true, 'note' => null];
    }

    /**
     * Applies a device punch as the day's check-out. The LAST tap wins, which
     * is what "he left, came back for his bag, left again" should record.
     */
    public static function deviceCheckOut(
        int $employeeId,
        int $tenantId,
        string $date,
        string $time,
        ?int $attendanceId = null
    ): array {
        $existing = $attendanceId !== null
            ? Database::fetchOne(
                "SELECT id, check_in_time, check_out_time FROM attendance
                 WHERE id = ? AND tenant_id = ? LIMIT 1",
                [$attendanceId, $tenantId]
            )
            : Database::fetchOne(
                "SELECT id, check_in_time, check_out_time FROM attendance
                 WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
                [$employeeId, $date, $tenantId]
            );

        if (!$existing) {
            return ['attendance_id' => null, 'changed' => false, 'note' => 'No open attendance row'];
        }

        if (!empty($existing['check_out_time'])
            && strtotime($existing['check_out_time']) >= strtotime($time)) {
            return [
                'attendance_id' => (int) $existing['id'],
                'changed' => false,
                'note' => 'Earlier than the recorded check-out',
            ];
        }

        Database::execute(
            "UPDATE attendance SET check_out_time = ?, check_out_method = 'device' WHERE id = ?",
            [$time, $existing['id']]
        );

        self::recomputeWorkedMinutes((int) $existing['id'], $employeeId, $tenantId, $date);

        return ['attendance_id' => (int) $existing['id'], 'changed' => true, 'note' => null];
    }

    /**
     * Recomputes worked/overtime/late from whatever times the row now holds.
     * Needed because device punches arrive one at a time and in any order, so
     * the totals cannot be computed at check-out the way the app path does.
     */
    public static function recomputeWorkedMinutes(int $attendanceId, int $employeeId, int $tenantId, string $date): void {
        $row = Database::fetchOne(
            "SELECT check_in_time, check_out_time FROM attendance WHERE id = ? LIMIT 1",
            [$attendanceId]
        );
        if (!$row || empty($row['check_in_time']) || empty($row['check_out_time'])) {
            return;
        }

        $employee = EmployeeModel::findById($employeeId, $tenantId);
        $employee = self::withScheduledShift($employee, $tenantId, $date);
        $workStart = $employee['shift_start'] ?? $employee['work_start_time'] ?? '09:00:00';
        $workEnd = $employee['shift_end'] ?? $employee['work_end_time'] ?? '17:00:00';

        $in = strtotime($row['check_in_time']);
        $out = strtotime($row['check_out_time']);
        // A check-out earlier in the clock than the check-in means the shift
        // crossed midnight; the punch belongs to the next calendar day.
        if ($out < $in) {
            $out += 86400;
        }

        $worked = (int) max(0, ($out - $in) / 60);
        $late = (int) max(0, ($in - strtotime($workStart)) / 60);
        $overtime = (int) max(0, ($out - strtotime($workEnd)) / 60);

        Database::execute(
            "UPDATE attendance SET worked_minutes = ?, overtime_minutes = ?, late_minutes = ? WHERE id = ?",
            [$worked, $overtime, $late, $attendanceId]
        );
    }

    /**
     * The most recent day whose check-in has no matching check-out, used to
     * catch a night shift: someone who clocked in at 22:00 yesterday and taps
     * at 06:00 today is leaving, not arriving.
     */
    public static function findOpenShiftRow(int $employeeId, int $tenantId, string $beforeDate): ?array {
        return Database::fetchOne(
            "SELECT id, date, check_in_time FROM attendance
             WHERE employee_id = ? AND tenant_id = ? AND date < ?
               AND check_in_time IS NOT NULL AND check_out_time IS NULL
             ORDER BY date DESC LIMIT 1",
            [$employeeId, $tenantId, $beforeDate]
        );
    }
}
