<?php

final class ShiftSwapModel {
    public const STATUSES = ['pending_target', 'pending_manager', 'approved', 'rejected', 'cancelled'];

    public static function create(int $tenantId, array $data): int {
        $requesterId = (int) $data['requester_employee_id'];
        $targetId = (int) $data['target_employee_id'];
        $requesterDate = $data['requester_date'];
        $targetDate = $data['target_date'];

        if ($requesterId === $targetId) Response::fail('Cannot swap with yourself', 400);

        $reqCell = Database::fetchOne(
            "SELECT ess.shift_id, ess.status FROM employee_shift_schedule ess
             WHERE ess.employee_id = ? AND ess.tenant_id = ? AND ess.work_date = ? AND ess.status = 'published'",
            [$requesterId, $tenantId, $requesterDate]
        );
        if (!$reqCell || $reqCell['shift_id'] === null) {
            Response::fail('You do not have a published shift on the requester date', 400);
        }

        $tgtCell = Database::fetchOne(
            "SELECT ess.shift_id, ess.status FROM employee_shift_schedule ess
             WHERE ess.employee_id = ? AND ess.tenant_id = ? AND ess.work_date = ? AND ess.status = 'published'",
            [$targetId, $tenantId, $targetDate]
        );
        if (!$tgtCell || $tgtCell['shift_id'] === null) {
            Response::fail('Target employee does not have a published shift on the target date', 400);
        }

        $targetEmp = Database::fetchOne(
            "SELECT id FROM employees WHERE id = ? AND tenant_id = ?",
            [$targetId, $tenantId]
        );
        if (!$targetEmp) Response::notFound('Target employee');

        Database::execute(
            "INSERT INTO shift_swap_requests
                (tenant_id, requester_employee_id, requester_date, target_employee_id, target_date, status, requester_note)
             VALUES (?, ?, ?, ?, ?, 'pending_target', ?)",
            [$tenantId, $requesterId, $requesterDate, $targetId, $targetDate, $data['note'] ?? null]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT ssr.*,
                    r.name AS requester_name, t.name AS target_name,
                    r.branch_id AS requester_branch_id, t.branch_id AS target_branch_id,
                    rs.name AS requester_shift_name, ts.name AS target_shift_name
             FROM shift_swap_requests ssr
             JOIN employees r ON r.id = ssr.requester_employee_id
             JOIN employees t ON t.id = ssr.target_employee_id
             LEFT JOIN employee_shift_schedule ess_r
                ON ess_r.employee_id = ssr.requester_employee_id AND ess_r.work_date = ssr.requester_date AND ess_r.tenant_id = ssr.tenant_id
             LEFT JOIN shifts rs ON rs.id = ess_r.shift_id
             LEFT JOIN employee_shift_schedule ess_t
                ON ess_t.employee_id = ssr.target_employee_id AND ess_t.work_date = ssr.target_date AND ess_t.tenant_id = ssr.tenant_id
             LEFT JOIN shifts ts ON ts.id = ess_t.shift_id
             WHERE ssr.id = ? AND ssr.tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function listForEmployee(int $tenantId, int $employeeId): array {
        return Database::fetchAll(
            "SELECT ssr.*,
                    r.name AS requester_name, t.name AS target_name
             FROM shift_swap_requests ssr
             JOIN employees r ON r.id = ssr.requester_employee_id
             JOIN employees t ON t.id = ssr.target_employee_id
             WHERE ssr.tenant_id = ? AND (ssr.requester_employee_id = ? OR ssr.target_employee_id = ?)
             ORDER BY ssr.created_at DESC",
            [$tenantId, $employeeId, $employeeId]
        );
    }

    public static function listPendingManager(int $tenantId, ?int $branchId = null): array {
        $params = [$tenantId];
        $branchFilter = '';
        if ($branchId !== null) {
            $branchFilter = ' AND (r.branch_id = ? OR t.branch_id = ?)';
            $params[] = $branchId;
            $params[] = $branchId;
        }
        return Database::fetchAll(
            "SELECT ssr.*,
                    r.name AS requester_name, t.name AS target_name,
                    r.branch_id AS requester_branch_id, t.branch_id AS target_branch_id
             FROM shift_swap_requests ssr
             JOIN employees r ON r.id = ssr.requester_employee_id
             JOIN employees t ON t.id = ssr.target_employee_id
             WHERE ssr.tenant_id = ? AND ssr.status = 'pending_manager'
             {$branchFilter}
             ORDER BY ssr.updated_at ASC",
            $params
        );
    }

    public static function respondTarget(int $tenantId, int $id, int $targetEmployeeId, bool $accept): void {
        $swap = Database::fetchOne(
            "SELECT id, status FROM shift_swap_requests WHERE id = ? AND tenant_id = ? AND target_employee_id = ?",
            [$id, $tenantId, $targetEmployeeId]
        );
        if (!$swap) Response::notFound('Swap request');
        if ($swap['status'] !== 'pending_target') Response::fail('Swap request is not awaiting your response', 400);

        if ($accept) {
            Database::execute(
                "UPDATE shift_swap_requests SET status = 'pending_manager', target_responded_at = NOW()
                 WHERE id = ?",
                [$id]
            );
        } else {
            Database::execute(
                "UPDATE shift_swap_requests SET status = 'rejected', target_responded_at = NOW()
                 WHERE id = ?",
                [$id]
            );
        }
    }

    public static function cancel(int $tenantId, int $id, int $requesterEmployeeId): void {
        $swap = Database::fetchOne(
            "SELECT id, status FROM shift_swap_requests
             WHERE id = ? AND tenant_id = ? AND requester_employee_id = ?",
            [$id, $tenantId, $requesterEmployeeId]
        );
        if (!$swap) Response::notFound('Swap request');
        if (!in_array($swap['status'], ['pending_target', 'pending_manager'], true)) {
            Response::fail('Cannot cancel a request that is already processed', 400);
        }
        Database::execute(
            "UPDATE shift_swap_requests SET status = 'cancelled' WHERE id = ?",
            [$id]
        );
    }

    public static function approve(int $tenantId, int $id, int $adminId, ?string $note = null): void {
        $pdo = Database::getInstance();
        $pdo->beginTransaction();
        try {
            $swap = Database::fetchOne(
                "SELECT * FROM shift_swap_requests WHERE id = ? AND tenant_id = ? FOR UPDATE",
                [$id, $tenantId]
            );
            if (!$swap) {
                $pdo->rollBack();
                Response::notFound('Swap request');
            }
            if ($swap['status'] !== 'pending_manager') {
                $pdo->rollBack();
                Response::fail('Swap request is not pending manager approval', 400);
            }

            $reqCell = Database::fetchOne(
                "SELECT id, shift_id, status FROM employee_shift_schedule
                 WHERE employee_id = ? AND tenant_id = ? AND work_date = ? FOR UPDATE",
                [(int) $swap['requester_employee_id'], $tenantId, $swap['requester_date']]
            );
            $tgtCell = Database::fetchOne(
                "SELECT id, shift_id, status FROM employee_shift_schedule
                 WHERE employee_id = ? AND tenant_id = ? AND work_date = ? FOR UPDATE",
                [(int) $swap['target_employee_id'], $tenantId, $swap['target_date']]
            );

            if (!$reqCell || $reqCell['status'] !== 'published') {
                $pdo->rollBack();
                Response::fail('Requester shift cell no longer exists or is not published', 409);
            }
            if (!$tgtCell || $tgtCell['status'] !== 'published') {
                $pdo->rollBack();
                Response::fail('Target shift cell no longer exists or is not published', 409);
            }

            $reqShiftId = $reqCell['shift_id'];
            $tgtShiftId = $tgtCell['shift_id'];

            Database::execute(
                "UPDATE employee_shift_schedule SET shift_id = ?, created_by = ? WHERE id = ?",
                [$tgtShiftId, $adminId, $reqCell['id']]
            );
            Database::execute(
                "UPDATE employee_shift_schedule SET shift_id = ?, created_by = ? WHERE id = ?",
                [$reqShiftId, $adminId, $tgtCell['id']]
            );

            Database::execute(
                "UPDATE shift_swap_requests SET status = 'approved', decided_by = ?, decided_at = NOW(), decision_note = ?
                 WHERE id = ?",
                [$adminId, $note, $id]
            );

            $pdo->commit();
        } catch (Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    public static function reject(int $tenantId, int $id, int $adminId, ?string $note = null): void {
        Database::execute(
            "UPDATE shift_swap_requests SET status = 'rejected', decided_by = ?, decided_at = NOW(), decision_note = ?
             WHERE id = ? AND tenant_id = ? AND status = 'pending_manager'",
            [$adminId, $note, $id, $tenantId]
        );
    }
}
