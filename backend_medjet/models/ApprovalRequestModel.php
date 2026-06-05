<?php

final class ApprovalRequestModel {
    public const STATUSES = ['pending','approved','rejected','cancelled'];
    public const STEP_STATUSES = ['pending','approved','rejected','skipped'];

    public static function open(int $tenantId, array $chain, array $steps, string $entityType,
                                int $entityId, ?int $byAdminId, ?int $byEmployeeId, ?float $amount): int {
        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            $totalSteps = count($steps);

            Database::execute(
                "INSERT INTO approval_requests (tenant_id, chain_id, entity_type, entity_id, requested_by_admin_id, requested_by_employee_id, context_amount, current_step, total_steps, status)
                 VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, 'pending')",
                [$tenantId, (int) $chain['id'], $entityType, $entityId, $byAdminId, $byEmployeeId, $amount, $totalSteps]
            );
            $requestId = (int) Database::lastInsertId();

            $order = 1;
            foreach ($steps as $step) {
                Database::execute(
                    "INSERT INTO approval_request_steps (tenant_id, request_id, step_order, approver_type, approver_role, approver_admin_id, label, status)
                     VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')",
                    [
                        $tenantId,
                        $requestId,
                        $order,
                        $step['approver_type'],
                        $step['approver_role'] ?? null,
                        $step['approver_admin_id'] ?? null,
                        $step['label'] ?? null,
                    ]
                );
                $order++;
            }

            $con->commit();
            return $requestId;
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }
    }

    public static function findById(int $id, int $tenantId): ?array {
        $req = Database::fetchOne(
            "SELECT r.*, c.name AS chain_name
             FROM approval_requests r
             LEFT JOIN approval_chains c ON c.id = r.chain_id
             WHERE r.id = ? AND r.tenant_id = ?",
            [$id, $tenantId]
        );
        if (!$req) {
            return null;
        }
        $req['steps'] = self::getStepsWithDetails((int) $req['id'], $tenantId);
        return $req;
    }

    public static function findOpenForEntity(int $tenantId, string $entityType, int $entityId): ?array {
        return Database::fetchOne(
            "SELECT * FROM approval_requests
             WHERE tenant_id = ? AND entity_type = ? AND entity_id = ? AND status = 'pending'
             LIMIT 1",
            [$tenantId, $entityType, $entityId]
        );
    }

    public static function currentStep(int $requestId, int $tenantId): ?array {
        $req = Database::fetchOne(
            "SELECT current_step FROM approval_requests WHERE id = ? AND tenant_id = ?",
            [$requestId, $tenantId]
        );
        if (!$req) {
            return null;
        }
        return Database::fetchOne(
            "SELECT * FROM approval_request_steps
             WHERE request_id = ? AND tenant_id = ? AND step_order = ?",
            [$requestId, $tenantId, (int) $req['current_step']]
        );
    }

    public static function inboxFor(int $tenantId, int $adminId, string $role): array {
        $sql = "SELECT r.*, c.name AS chain_name
                FROM approval_requests r
                LEFT JOIN approval_chains c ON c.id = r.chain_id
                INNER JOIN approval_request_steps s ON s.request_id = r.id AND s.tenant_id = r.tenant_id
                WHERE r.tenant_id = ? AND r.status = 'pending' AND s.step_order = r.current_step AND s.status = 'pending'";

        $params = [$tenantId];

        if ($role === 'general_manager') {
            // sees all pending
        } else {
            $sql .= " AND (
                (s.approver_type = 'admin' AND s.approver_admin_id = ?)
                OR (s.approver_type = 'role' AND s.approver_role = ?)
            )";
            $params[] = $adminId;
            $params[] = $role;
        }

        $sql .= " ORDER BY r.created_at DESC";

        return Database::fetchAll($sql, $params);
    }

    public static function listByTenant(int $tenantId, ?string $status, ?string $entityType): array {
        $sql = "SELECT r.*, c.name AS chain_name
                FROM approval_requests r
                LEFT JOIN approval_chains c ON c.id = r.chain_id
                WHERE r.tenant_id = ?";
        $params = [$tenantId];

        if ($status !== null) {
            $sql .= " AND r.status = ?";
            $params[] = $status;
        }
        if ($entityType !== null) {
            $sql .= " AND r.entity_type = ?";
            $params[] = $entityType;
        }

        $sql .= " ORDER BY r.created_at DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function decide(int $tenantId, int $requestId, array $stepRow, int $adminId,
                                 string $decision, ?string $note): array {
        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            $req = Database::fetchOne(
                "SELECT * FROM approval_requests WHERE id = ? AND tenant_id = ? FOR UPDATE",
                [$requestId, $tenantId]
            );
            if (!$req || $req['status'] !== 'pending') {
                $con->rollBack();
                Response::fail('Request already finalized', 409);
            }

            $currentStepOrder = (int) $req['current_step'];
            $totalSteps = (int) $req['total_steps'];

            if ((int) $stepRow['step_order'] !== $currentStepOrder || $stepRow['status'] !== 'pending') {
                $con->rollBack();
                Response::fail('Step is not the current active step', 409);
            }

            $stepStatus = $decision === 'approve' ? 'approved' : 'rejected';

            Database::execute(
                "UPDATE approval_request_steps SET status = ?, decided_by = ?, decided_at = NOW(), note = ?
                 WHERE id = ? AND tenant_id = ?",
                [$stepStatus, $adminId, $note, (int) $stepRow['id'], $tenantId]
            );

            if ($decision === 'reject') {
                Database::execute(
                    "UPDATE approval_requests SET status = 'rejected', decided_at = NOW() WHERE id = ? AND tenant_id = ?",
                    [$requestId, $tenantId]
                );
                $con->commit();
                return ['final' => 'rejected'];
            }

            if ($currentStepOrder >= $totalSteps) {
                Database::execute(
                    "UPDATE approval_requests SET status = 'approved', decided_at = NOW() WHERE id = ? AND tenant_id = ?",
                    [$requestId, $tenantId]
                );
                $con->commit();
                return ['final' => 'approved'];
            }

            $nextStep = $currentStepOrder + 1;
            Database::execute(
                "UPDATE approval_requests SET current_step = ? WHERE id = ? AND tenant_id = ?",
                [$nextStep, $requestId, $tenantId]
            );
            $con->commit();
            return ['final' => null, 'next_step' => $nextStep];
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }
    }

    public static function cancel(int $tenantId, int $requestId): void {
        Database::execute(
            "UPDATE approval_requests SET status = 'cancelled', decided_at = NOW()
             WHERE id = ? AND tenant_id = ? AND status = 'pending'",
            [$requestId, $tenantId]
        );
    }

    private static function getStepsWithDetails(int $requestId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT s.*, a.name AS decided_by_name
             FROM approval_request_steps s
             LEFT JOIN admins a ON a.id = s.decided_by
             WHERE s.request_id = ? AND s.tenant_id = ?
             ORDER BY s.step_order ASC",
            [$requestId, $tenantId]
        );
    }
}
