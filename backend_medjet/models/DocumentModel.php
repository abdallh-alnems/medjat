<?php

final class DocumentModel {
    public static function getRequiredByTenant(int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM required_documents WHERE tenant_id = ? AND is_active = 1 ORDER BY sort_order ASC, name ASC",
            [$tenantId]
        );
    }

    public static function getAllRequiredByTenant(int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM required_documents WHERE tenant_id = ? ORDER BY sort_order ASC, name ASC",
            [$tenantId]
        );
    }

    public static function getRequiredForEmployee(int $employeeId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT rd.* FROM required_documents rd
             JOIN employees e ON e.id = ? AND e.tenant_id = ?
             WHERE rd.tenant_id = ? AND rd.is_active = 1 AND (
                rd.scope_type = 'all'
                OR (rd.scope_type = 'branch' AND rd.scope_branch_id = e.branch_id)
                OR (rd.scope_type = 'employees' AND EXISTS (
                    SELECT 1 FROM required_document_employees rde
                    WHERE rde.required_document_id = rd.id AND rde.employee_id = e.id
                ))
                OR (rd.scope_type = 'category' AND EXISTS (
                    SELECT 1 FROM required_document_categories rdc
                    JOIN employee_category_assignments eca ON eca.category_id = rdc.category_id AND eca.tenant_id = rdc.tenant_id
                    WHERE rdc.required_document_id = rd.id AND eca.employee_id = e.id AND rdc.tenant_id = ?
                ))
             )
             ORDER BY rd.sort_order ASC, rd.name ASC",
            [$employeeId, $tenantId, $tenantId, $tenantId]
        );
    }

    public static function getRequiredById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM required_documents WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function addRequired(int $tenantId, string $name, ?string $description = null): int {
        Database::execute(
            "INSERT INTO required_documents (tenant_id, name, description) VALUES (?, ?, ?)",
            [$tenantId, $name, $description]
        );
        return (int) Database::lastInsertId();
    }

    public static function addRequiredFull(int $tenantId, array $fields): int {
        $cols = ['tenant_id'];
        $vals = [$tenantId];
        $placeholders = ['?'];

        $allowed = ['name', 'description', 'expiry_days', 'notification_days_before', 'category', 'sort_order', 'is_required', 'is_active', 'scope_type', 'scope_branch_id'];
        foreach ($allowed as $col) {
            if (array_key_exists($col, $fields)) {
                $cols[] = $col;
                $vals[] = $fields[$col];
                $placeholders[] = '?';
            }
        }

        $sql = "INSERT INTO required_documents (" . implode(', ', $cols) . ") VALUES (" . implode(', ', $placeholders) . ")";
        Database::execute($sql, $vals);
        return (int) Database::lastInsertId();
    }

    public static function updateRequired(int $id, int $tenantId, array $fields): bool {
        $allowed = ['name', 'description', 'expiry_days', 'notification_days_before', 'category', 'sort_order', 'is_required', 'is_active', 'scope_type', 'scope_branch_id'];
        $sets = [];
        $vals = [];
        foreach ($allowed as $col) {
            if (array_key_exists($col, $fields)) {
                $sets[] = "{$col} = ?";
                $vals[] = $fields[$col];
            }
        }
        if (empty($sets)) return false;

        $vals[] = $id;
        $vals[] = $tenantId;
        return Database::execute(
            "UPDATE required_documents SET " . implode(', ', $sets) . " WHERE id = ? AND tenant_id = ?",
            $vals
        ) > 0;
    }

    public static function setEmployeeScope(int $requiredDocumentId, int $tenantId, array $employeeIds): void {
        Database::execute(
            "DELETE FROM required_document_employees WHERE required_document_id = ? AND tenant_id = ?",
            [$requiredDocumentId, $tenantId]
        );
        foreach ($employeeIds as $empId) {
            $empId = (int) $empId;
            if ($empId <= 0) continue;
            Database::execute(
                "INSERT IGNORE INTO required_document_employees (required_document_id, employee_id, tenant_id) VALUES (?, ?, ?)",
                [$requiredDocumentId, $empId, $tenantId]
            );
        }
    }

    public static function getEmployeeScope(int $requiredDocumentId, int $tenantId): array {
        $rows = Database::fetchAll(
            "SELECT employee_id FROM required_document_employees WHERE required_document_id = ? AND tenant_id = ?",
            [$requiredDocumentId, $tenantId]
        );
        return array_map(fn($r) => (int) $r['employee_id'], $rows);
    }

    public static function setCategoryScope(int $requiredDocumentId, int $tenantId, array $categoryIds): void {
        Database::execute(
            "DELETE FROM required_document_categories WHERE required_document_id = ? AND tenant_id = ?",
            [$requiredDocumentId, $tenantId]
        );
        foreach ($categoryIds as $catId) {
            $catId = (int) $catId;
            if ($catId <= 0) continue;
            Database::execute(
                "INSERT IGNORE INTO required_document_categories (required_document_id, category_id, tenant_id) VALUES (?, ?, ?)",
                [$requiredDocumentId, $catId, $tenantId]
            );
        }
    }

    public static function getCategoryScope(int $requiredDocumentId, int $tenantId): array {
        $rows = Database::fetchAll(
            "SELECT category_id FROM required_document_categories WHERE required_document_id = ? AND tenant_id = ?",
            [$requiredDocumentId, $tenantId]
        );
        return array_map(fn($r) => (int) $r['category_id'], $rows);
    }

    public static function deleteRequired(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM required_documents WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function toggleRequiredActive(int $id, int $tenantId): bool {
        return Database::execute(
            "UPDATE required_documents SET is_active = NOT is_active WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function upload(int $employeeId, int $tenantId, int $documentTypeId, string $filePath, string $originalName, int $uploadedBy, ?int $fileSize = null, ?string $mimeType = null): int {
        Database::execute(
            "INSERT INTO employee_documents (tenant_id, employee_id, required_document_id, file_path, original_name, file_size, mime_type, uploaded_by, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'uploaded')
             ON DUPLICATE KEY UPDATE file_path = VALUES(file_path), original_name = VALUES(original_name), file_size = VALUES(file_size), mime_type = VALUES(mime_type), status = 'uploaded', uploaded_by = VALUES(uploaded_by), rejected_reason = NULL, notes = NULL",
            [$tenantId, $employeeId, $documentTypeId, $filePath, $originalName, $fileSize, $mimeType, $uploadedBy]
        );
        return (int) Database::lastInsertId();
    }

    public static function getByEmployee(int $employeeId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT ed.*, rd.name as document_name, rd.description, rd.category, rd.expiry_days
             FROM employee_documents ed
             LEFT JOIN required_documents rd ON rd.id = ed.required_document_id
             WHERE ed.employee_id = ? AND ed.tenant_id = ?
             ORDER BY rd.name ASC",
            [$employeeId, $tenantId]
        );
    }

    public static function getDocumentById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT ed.*, rd.name as document_name, rd.description
             FROM employee_documents ed
             LEFT JOIN required_documents rd ON rd.id = ed.required_document_id
             WHERE ed.id = ? AND ed.tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function updateDocument(int $id, int $tenantId, array $fields): bool {
        $allowed = ['notes', 'expires_at'];
        $sets = [];
        $vals = [];
        foreach ($allowed as $col) {
            if (array_key_exists($col, $fields)) {
                $sets[] = "{$col} = ?";
                $vals[] = $fields[$col];
            }
        }
        if (empty($sets)) return false;

        $vals[] = $id;
        $vals[] = $tenantId;
        return Database::execute(
            "UPDATE employee_documents SET " . implode(', ', $sets) . " WHERE id = ? AND tenant_id = ?",
            $vals
        ) > 0;
    }

    public static function updateStatus(int $id, int $tenantId, string $status, ?string $reason = null): bool {
        $sql = "UPDATE employee_documents SET status = ?";
        $params = [$status];
        if ($reason !== null) {
            $sql .= ", rejected_reason = ?";
            $params[] = $reason;
        }
        $sql .= " WHERE id = ? AND tenant_id = ?";
        $params[] = $id;
        $params[] = $tenantId;
        return Database::execute($sql, $params) > 0;
    }

    public static function verifyDocument(int $id, int $tenantId, int $verifiedBy): bool {
        return Database::execute(
            "UPDATE employee_documents SET status = 'uploaded', verified_at = NOW(), verified_by = ?, rejected_reason = NULL WHERE id = ? AND tenant_id = ?",
            [$verifiedBy, $id, $tenantId]
        ) > 0;
    }

    public static function rejectDocument(int $id, int $tenantId, string $reason): bool {
        return Database::execute(
            "UPDATE employee_documents SET status = 'rejected', rejected_reason = ?, verified_at = NULL WHERE id = ? AND tenant_id = ?",
            [$reason, $id, $tenantId]
        ) > 0;
    }

    public static function setExpiryDate(int $id, int $tenantId, string $date): bool {
        return Database::execute(
            "UPDATE employee_documents SET expires_at = ? WHERE id = ? AND tenant_id = ?",
            [$date, $id, $tenantId]
        ) > 0;
    }

    public static function delete(int $documentId, int $tenantId): bool {
        $doc = Database::fetchOne(
            "SELECT file_path FROM employee_documents WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$documentId, $tenantId]
        );
        if (!$doc) return false;

        if (file_exists($doc['file_path'])) {
            @unlink($doc['file_path']);
        }

        return Database::execute(
            "DELETE FROM employee_documents WHERE id = ? AND tenant_id = ?",
            [$documentId, $tenantId]
        ) > 0;
    }

    public static function getMissingDocuments(int $tenantId, ?int $employeeId = null): array {
        $sql = "SELECT e.id as employee_id, e.name as employee_name, e.branch_id, b.name as branch_name, rd.id as required_document_id, rd.name as document_name, rd.category
                FROM employees e
                JOIN required_documents rd ON rd.tenant_id = e.tenant_id AND (
                    rd.scope_type = 'all'
                    OR (rd.scope_type = 'branch' AND rd.scope_branch_id = e.branch_id)
                    OR (rd.scope_type = 'employees' AND EXISTS (
                        SELECT 1 FROM required_document_employees rde
                        WHERE rde.required_document_id = rd.id AND rde.employee_id = e.id
                    ))
                    OR (rd.scope_type = 'category' AND EXISTS (
                        SELECT 1 FROM required_document_categories rdc
                        JOIN employee_category_assignments eca ON eca.category_id = rdc.category_id AND eca.tenant_id = rdc.tenant_id
                        WHERE rdc.required_document_id = rd.id AND eca.employee_id = e.id AND rdc.tenant_id = ?
                    ))
                )
                LEFT JOIN employee_documents ed ON ed.employee_id = e.id AND ed.required_document_id = rd.id
                LEFT JOIN branches b ON b.id = e.branch_id
                WHERE e.tenant_id = ? AND e.status = 'active' AND rd.is_active = 1 AND rd.is_required = 1 AND ed.id IS NULL";
        $params = [$tenantId, $tenantId];

        if ($employeeId) {
            $sql .= " AND e.id = ?";
            $params[] = $employeeId;
        }

        return Database::fetchAll($sql, $params);
    }

    public static function getMissingByBranch(int $tenantId, ?int $branchId = null): array {
        $sql = "SELECT e.id as employee_id, e.name as employee_name, e.branch_id, b.name as branch_name, rd.id as required_document_id, rd.name as document_name, rd.category
                FROM employees e
                JOIN required_documents rd ON rd.tenant_id = e.tenant_id AND (
                    rd.scope_type = 'all'
                    OR (rd.scope_type = 'branch' AND rd.scope_branch_id = e.branch_id)
                    OR (rd.scope_type = 'employees' AND EXISTS (
                        SELECT 1 FROM required_document_employees rde
                        WHERE rde.required_document_id = rd.id AND rde.employee_id = e.id
                    ))
                    OR (rd.scope_type = 'category' AND EXISTS (
                        SELECT 1 FROM required_document_categories rdc
                        JOIN employee_category_assignments eca ON eca.category_id = rdc.category_id AND eca.tenant_id = rdc.tenant_id
                        WHERE rdc.required_document_id = rd.id AND eca.employee_id = e.id AND rdc.tenant_id = ?
                    ))
                )
                LEFT JOIN employee_documents ed ON ed.employee_id = e.id AND ed.required_document_id = rd.id
                LEFT JOIN branches b ON b.id = e.branch_id
                WHERE e.tenant_id = ? AND e.status = 'active' AND rd.is_active = 1 AND rd.is_required = 1 AND ed.id IS NULL";
        $params = [$tenantId, $tenantId];

        if ($branchId) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }

        return Database::fetchAll($sql, $params);
    }

    public static function getExpiringSoon(int $tenantId, int $daysAhead = 30, ?int $branchId = null): array {
        $sql = "SELECT ed.*, e.name as employee_name, e.branch_id, b.name as branch_name, rd.name as document_name
                FROM employee_documents ed
                JOIN employees e ON e.id = ed.employee_id
                JOIN required_documents rd ON rd.id = ed.required_document_id
                LEFT JOIN branches b ON b.id = e.branch_id
                WHERE ed.tenant_id = ?
                AND ed.status = 'uploaded'
                AND ed.expires_at IS NOT NULL
                AND ed.expires_at BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL ? DAY)";
        $params = [$tenantId, $daysAhead];

        if ($branchId) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }

        $sql .= " ORDER BY ed.expires_at ASC";
        return Database::fetchAll($sql, $params);
    }

    public static function getExpired(int $tenantId, ?int $branchId = null): array {
        $sql = "SELECT ed.*, e.name as employee_name, e.branch_id, b.name as branch_name, rd.name as document_name
                FROM employee_documents ed
                JOIN employees e ON e.id = ed.employee_id
                JOIN required_documents rd ON rd.id = ed.required_document_id
                LEFT JOIN branches b ON b.id = e.branch_id
                WHERE ed.tenant_id = ?
                AND ed.status IN ('expired', 'uploaded')
                AND ed.expires_at IS NOT NULL
                AND ed.expires_at < CURDATE()";
        $params = [$tenantId];

        if ($branchId) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }

        $sql .= " ORDER BY ed.expires_at ASC";
        return Database::fetchAll($sql, $params);
    }

    public static function markExpiredDocuments(int $tenantId): int {
        return Database::execute(
            "UPDATE employee_documents SET status = 'expired'
             WHERE tenant_id = ? AND status = 'uploaded' AND expires_at IS NOT NULL AND expires_at < CURDATE()",
            [$tenantId]
        );
    }

    public static function getStatsByTenant(int $tenantId): array {
        $scopedPairsSql = "SELECT e.id as employee_id, rd.id as required_document_id
                           FROM employees e
                           JOIN required_documents rd ON rd.tenant_id = e.tenant_id AND (
                               rd.scope_type = 'all'
                               OR (rd.scope_type = 'branch' AND rd.scope_branch_id = e.branch_id)
                               OR (rd.scope_type = 'employees' AND EXISTS (
                                   SELECT 1 FROM required_document_employees rde
                                   WHERE rde.required_document_id = rd.id AND rde.employee_id = e.id
                               ))
                               OR (rd.scope_type = 'category' AND EXISTS (
                                   SELECT 1 FROM required_document_categories rdc
                                   JOIN employee_category_assignments eca ON eca.category_id = rdc.category_id AND eca.tenant_id = rdc.tenant_id
                                   WHERE rdc.required_document_id = rd.id AND eca.employee_id = e.id AND rdc.tenant_id = ?
                               ))
                           )
                           WHERE e.tenant_id = ? AND e.status = 'active' AND rd.is_active = 1 AND rd.is_required = 1";

        $totalRequired = Database::fetchOne(
            "SELECT COUNT(*) as cnt FROM ({$scopedPairsSql}) t",
            [$tenantId, $tenantId]
        )['cnt'] ?? 0;

        $uploaded = Database::fetchOne(
            "SELECT COUNT(*) as cnt FROM employee_documents WHERE tenant_id = ? AND status = 'uploaded'",
            [$tenantId]
        )['cnt'] ?? 0;

        $expired = Database::fetchOne(
            "SELECT COUNT(*) as cnt FROM employee_documents WHERE tenant_id = ? AND status = 'expired'",
            [$tenantId]
        )['cnt'] ?? 0;

        $expiringSoon = Database::fetchOne(
            "SELECT COUNT(*) as cnt FROM employee_documents WHERE tenant_id = ? AND status = 'uploaded' AND expires_at IS NOT NULL AND expires_at BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY)",
            [$tenantId]
        )['cnt'] ?? 0;

        $missing = Database::fetchOne(
            "SELECT COUNT(*) as cnt FROM ({$scopedPairsSql}) t
             LEFT JOIN employee_documents ed ON ed.employee_id = t.employee_id AND ed.required_document_id = t.required_document_id
             WHERE ed.id IS NULL",
            [$tenantId, $tenantId]
        )['cnt'] ?? 0;

        return [
            'total_required' => $totalRequired,
            'total_uploaded' => $uploaded,
            'total_missing' => $missing,
            'total_expired' => $expired,
            'total_expiring_soon' => $expiringSoon,
        ];
    }
}
