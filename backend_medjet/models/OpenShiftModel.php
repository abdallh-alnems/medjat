<?php

final class OpenShiftModel {
    public const STATUSES = ['open', 'filled', 'cancelled'];
    public const CLAIM_STATUSES = ['pending', 'approved', 'rejected', 'withdrawn'];

    public static function create(int $tenantId, array $data, int $adminId): int {
        Database::execute(
            "INSERT INTO open_shifts (tenant_id, branch_id, shift_id, work_date, slots, notes, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['branch_id'] ?? null,
                $data['shift_id'],
                $data['work_date'],
                $data['slots'] ?? 1,
                $data['notes'] ?? null,
                $adminId,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT os.*, s.name AS shift_name, s.start_time, s.end_time
             FROM open_shifts os
             JOIN shifts s ON s.id = os.shift_id
             WHERE os.id = ? AND os.tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function listOpen(int $tenantId, ?int $branchId = null): array {
        $params = [$tenantId];
        $branchFilter = '';
        if ($branchId !== null) {
            $branchFilter = ' AND (os.branch_id = ? OR os.branch_id IS NULL)';
            $params[] = $branchId;
        }
        $shifts = Database::fetchAll(
            "SELECT os.*, s.name AS shift_name, s.start_time, s.end_time
             FROM open_shifts os
             JOIN shifts s ON s.id = os.shift_id
             WHERE os.tenant_id = ? AND os.status IN ('open','filled')
               {$branchFilter}
             ORDER BY os.work_date ASC, s.start_time ASC",
            $params
        );
        foreach ($shifts as &$shift) {
            $shift['claims_count'] = (int) Database::fetchOne(
                "SELECT COUNT(*) AS cnt FROM open_shift_claims WHERE open_shift_id = ? AND status = 'pending'",
                [$shift['id']]
            )['cnt'];
        }
        unset($shift);
        return $shifts;
    }

    public static function cancel(int $id, int $tenantId): void {
        Database::execute(
            "UPDATE open_shift_claims SET status = 'rejected', decided_at = NOW()
             WHERE open_shift_id = ? AND tenant_id = ? AND status = 'pending'",
            [$id, $tenantId]
        );
        Database::execute(
            "UPDATE open_shifts SET status = 'cancelled' WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function browseForEmployee(int $tenantId, int $employeeId, int $employeeBranchId): array {
        return Database::fetchAll(
            "SELECT os.*, s.name AS shift_name, s.start_time, s.end_time
             FROM open_shifts os
             JOIN shifts s ON s.id = os.shift_id
             WHERE os.tenant_id = ?
               AND os.status = 'open'
               AND os.work_date >= CURDATE()
               AND (os.branch_id IS NULL OR os.branch_id = ?)
               AND NOT EXISTS (
                   SELECT 1 FROM employee_shift_schedule ess
                   WHERE ess.employee_id = ? AND ess.tenant_id = ? AND ess.work_date = os.work_date
               )
             ORDER BY os.work_date ASC, s.start_time ASC",
            [$tenantId, $employeeBranchId, $employeeId, $tenantId]
        );
    }

    public static function claim(int $tenantId, int $openShiftId, int $employeeId): int {
        $shift = Database::fetchOne(
            "SELECT id, status, work_date FROM open_shifts WHERE id = ? AND tenant_id = ?",
            [$openShiftId, $tenantId]
        );
        if (!$shift) Response::notFound('Open shift');
        if ($shift['status'] !== 'open') Response::fail('This shift is no longer open', 400);

        $conflict = Database::fetchOne(
            "SELECT id FROM employee_shift_schedule WHERE employee_id = ? AND tenant_id = ? AND work_date = ?",
            [$employeeId, $tenantId, $shift['work_date']]
        );
        if ($conflict) Response::fail('You already have a scheduled shift on this day', 409);

        $existing = Database::fetchOne(
            "SELECT id FROM open_shift_claims WHERE open_shift_id = ? AND employee_id = ?",
            [$openShiftId, $employeeId]
        );
        if ($existing) Response::fail('You already claimed this shift', 409);

        Database::execute(
            "INSERT INTO open_shift_claims (tenant_id, open_shift_id, employee_id, status) VALUES (?, ?, ?, 'pending')",
            [$tenantId, $openShiftId, $employeeId]
        );
        return (int) Database::lastInsertId();
    }

    public static function withdrawClaim(int $tenantId, int $claimId, int $employeeId): bool {
        return Database::execute(
            "UPDATE open_shift_claims SET status = 'withdrawn'
             WHERE id = ? AND tenant_id = ? AND employee_id = ? AND status = 'pending'",
            [$claimId, $tenantId, $employeeId]
        ) > 0;
    }

    public static function listClaims(int $tenantId, int $openShiftId): array {
        return Database::fetchAll(
            "SELECT osc.*, e.name AS employee_name
             FROM open_shift_claims osc
             JOIN employees e ON e.id = osc.employee_id
             WHERE osc.tenant_id = ? AND osc.open_shift_id = ?
             ORDER BY osc.created_at ASC",
            [$tenantId, $openShiftId]
        );
    }

    public static function findClaim(int $claimId, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT osc.*, os.shift_id, os.work_date, os.status AS shift_status, os.slots, os.slots_filled
             FROM open_shift_claims osc
             JOIN open_shifts os ON os.id = osc.open_shift_id
             WHERE osc.id = ? AND osc.tenant_id = ?",
            [$claimId, $tenantId]
        );
    }

    public static function approveClaim(int $tenantId, int $claimId, int $adminId): array {
        $pdo = Database::getInstance();
        $pdo->beginTransaction();
        try {
            $claim = Database::fetchOne(
                "SELECT osc.*, os.shift_id, os.work_date, os.status AS shift_status, os.slots, os.slots_filled, os.id AS open_shift_id
                 FROM open_shift_claims osc
                 JOIN open_shifts os ON os.id = osc.open_shift_id
                 WHERE osc.id = ? AND osc.tenant_id = ?
                 FOR UPDATE",
                [$claimId, $tenantId]
            );
            if (!$claim) {
                $pdo->rollBack();
                Response::notFound('Claim');
            }
            if ($claim['status'] !== 'pending') {
                $pdo->rollBack();
                Response::fail('Claim is no longer pending', 400);
            }
            if ($claim['shift_status'] !== 'open') {
                $pdo->rollBack();
                Response::fail('Open shift is no longer open', 400);
            }

            $schedConflict = Database::fetchOne(
                "SELECT id FROM employee_shift_schedule
                 WHERE employee_id = ? AND tenant_id = ? AND work_date = ?
                 FOR UPDATE",
                [$claim['employee_id'], $tenantId, $claim['work_date']]
            );
            if ($schedConflict) {
                $pdo->rollBack();
                Response::fail('Employee already has a scheduled shift on this day', 409);
            }

            Database::execute(
                "UPDATE open_shift_claims SET status = 'approved', decided_by = ?, decided_at = NOW()
                 WHERE id = ?",
                [$adminId, $claimId]
            );

            Database::execute(
                "INSERT INTO employee_shift_schedule (tenant_id, employee_id, shift_id, work_date, status, created_by)
                 VALUES (?, ?, ?, ?, 'published', ?)
                 ON DUPLICATE KEY UPDATE shift_id = VALUES(shift_id), status = 'published', created_by = VALUES(created_by)",
                [$tenantId, $claim['employee_id'], $claim['shift_id'], $claim['work_date'], $adminId]
            );

            $newFilled = (int) $claim['slots_filled'] + 1;
            if ($newFilled >= (int) $claim['slots']) {
                Database::execute(
                    "UPDATE open_shifts SET slots_filled = ?, status = 'filled' WHERE id = ?",
                    [$newFilled, $claim['open_shift_id']]
                );
                Database::execute(
                    "UPDATE open_shift_claims SET status = 'rejected', decided_by = ?, decided_at = NOW()
                     WHERE open_shift_id = ? AND id != ? AND status = 'pending'",
                    [$adminId, $claim['open_shift_id'], $claimId]
                );
            } else {
                Database::execute(
                    "UPDATE open_shifts SET slots_filled = ? WHERE id = ?",
                    [$newFilled, $claim['open_shift_id']]
                );
            }

            $pdo->commit();
            return ['claim_id' => $claimId, 'employee_id' => $claim['employee_id'], 'work_date' => $claim['work_date']];
        } catch (Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    public static function rejectClaim(int $tenantId, int $claimId, int $adminId): void {
        Database::execute(
            "UPDATE open_shift_claims SET status = 'rejected', decided_by = ?, decided_at = NOW()
             WHERE id = ? AND tenant_id = ? AND status = 'pending'",
            [$adminId, $claimId, $tenantId]
        );
    }
}
