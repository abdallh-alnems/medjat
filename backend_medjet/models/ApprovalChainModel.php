<?php

final class ApprovalChainModel {
    public const REQUEST_TYPES = ['leave','loan','bonus','warning','document','generic'];
    public const APPROVER_TYPES = ['role','admin'];
    public const APPROVER_ROLES = ['general_manager','hr','branch_manager','attendance','viewer'];

    public static function create(int $tenantId, array $data, int $adminId): int {
        Database::execute(
            "INSERT INTO approval_chains (tenant_id, name, name_ar, request_type, is_active, min_amount, max_amount, branch_id, priority, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['name'],
                $data['name_ar'] ?? null,
                $data['request_type'],
                isset($data['is_active']) ? (int) $data['is_active'] : 1,
                $data['min_amount'] ?? null,
                $data['max_amount'] ?? null,
                $data['branch_id'] ?? null,
                (int) ($data['priority'] ?? 0),
                $adminId,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        $chain = Database::fetchOne(
            "SELECT * FROM approval_chains WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
        if (!$chain) {
            return null;
        }
        $chain['steps'] = self::getSteps($tenantId, $id);
        return $chain;
    }

    public static function listByTenant(int $tenantId, ?string $requestType = null): array {
        $sql = "SELECT c.*,
                       (SELECT COUNT(*) FROM approval_chain_steps s WHERE s.chain_id = c.id) AS total_steps
                FROM approval_chains c
                WHERE c.tenant_id = ?";
        $params = [$tenantId];
        if ($requestType !== null) {
            $sql .= " AND c.request_type = ?";
            $params[] = $requestType;
        }
        $sql .= " ORDER BY c.request_type ASC, c.priority DESC, c.id DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $allowed = ['name', 'name_ar', 'is_active', 'min_amount', 'max_amount', 'branch_id', 'priority'];
        $fields = [];
        $values = [];
        foreach ($allowed as $key) {
            if (array_key_exists($key, $data)) {
                $fields[] = "`{$key}` = ?";
                $values[] = $data[$key];
            }
        }
        if (empty($fields)) {
            return;
        }
        $values[] = $id;
        $values[] = $tenantId;
        Database::execute(
            "UPDATE approval_chains SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function delete(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM approval_chains WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function setSteps(int $tenantId, int $chainId, array $steps): void {
        if (empty($steps)) {
            Response::fail('Chain must have at least one step', 422);
        }

        $chain = Database::fetchOne(
            "SELECT id FROM approval_chains WHERE id = ? AND tenant_id = ?",
            [$chainId, $tenantId]
        );
        if (!$chain) {
            Response::notFound('Approval chain');
        }

        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            Database::execute(
                "DELETE FROM approval_chain_steps WHERE chain_id = ? AND tenant_id = ?",
                [$chainId, $tenantId]
            );

            $order = 1;
            foreach ($steps as $step) {
                $approverType = $step['approver_type'] ?? 'role';
                if (!in_array($approverType, self::APPROVER_TYPES, true)) {
                    $con->rollBack();
                    Response::fail("Invalid approver_type at step {$order}", 422);
                }

                $approverRole = null;
                $approverAdminId = null;

                if ($approverType === 'role') {
                    $approverRole = $step['approver_role'] ?? null;
                    if (!in_array($approverRole, self::APPROVER_ROLES, true)) {
                        $con->rollBack();
                        Response::fail("Invalid approver_role at step {$order}", 422);
                    }
                } else {
                    $approverAdminId = $step['approver_admin_id'] ?? null;
                    if (!$approverAdminId) {
                        $con->rollBack();
                        Response::fail("approver_admin_id required for admin type at step {$order}", 422);
                    }
                    $admin = Database::fetchOne(
                        "SELECT id FROM admins WHERE id = ? AND tenant_id = ?",
                        [(int) $approverAdminId, $tenantId]
                    );
                    if (!$admin) {
                        $con->rollBack();
                        Response::fail("Admin not found at step {$order}", 422);
                    }
                    $approverAdminId = (int) $approverAdminId;
                }

                Database::execute(
                    "INSERT INTO approval_chain_steps (tenant_id, chain_id, step_order, approver_type, approver_role, approver_admin_id, label)
                     VALUES (?, ?, ?, ?, ?, ?, ?)",
                    [$tenantId, $chainId, $order, $approverType, $approverRole, $approverAdminId, $step['label'] ?? null]
                );
                $order++;
            }

            $con->commit();
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }
    }

    public static function getSteps(int $tenantId, int $chainId): array {
        return Database::fetchAll(
            "SELECT s.*, a.name AS approver_admin_name
             FROM approval_chain_steps s
             LEFT JOIN admins a ON a.id = s.approver_admin_id
             WHERE s.chain_id = ? AND s.tenant_id = ?
             ORDER BY s.step_order ASC",
            [$chainId, $tenantId]
        );
    }

    public static function resolveChain(int $tenantId, string $requestType, ?float $amount, ?int $branchId): ?array {
        $sql = "SELECT c.* FROM approval_chains c
                WHERE c.tenant_id = ? AND c.request_type = ? AND c.is_active = 1";
        $params = [$tenantId, $requestType];

        if ($amount !== null) {
            $sql .= " AND (c.min_amount IS NULL OR c.min_amount <= ?)";
            $params[] = $amount;
            $sql .= " AND (c.max_amount IS NULL OR c.max_amount >= ?)";
            $params[] = $amount;
        } else {
            $sql .= " AND c.min_amount IS NULL AND c.max_amount IS NULL";
        }

        if ($branchId !== null) {
            $sql .= " AND (c.branch_id IS NULL OR c.branch_id = ?)";
            $params[] = $branchId;
        } else {
            $sql .= " AND c.branch_id IS NULL";
        }

        $sql .= " ORDER BY c.priority DESC, c.id DESC";

        $candidates = Database::fetchAll($sql, $params);

        foreach ($candidates as $chain) {
            $stepCount = Database::fetchOne(
                "SELECT COUNT(*) AS c FROM approval_chain_steps WHERE chain_id = ? AND tenant_id = ?",
                [(int) $chain['id'], $tenantId]
            );
            if ((int) ($stepCount['c'] ?? 0) > 0) {
                $chain['steps'] = self::getSteps($tenantId, (int) $chain['id']);
                return $chain;
            }
        }

        return null;
    }
}
