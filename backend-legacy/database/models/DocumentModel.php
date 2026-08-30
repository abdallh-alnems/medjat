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

    /**
     * Adds a single employee to a required document's employee-scope without
     * disturbing the rest of the list. Used when an admin requests an existing
     * document type from one specific employee from their profile.
     */
    public static function addEmployeeToScope(int $requiredDocumentId, int $tenantId, int $employeeId): void {
        Database::execute(
            "INSERT IGNORE INTO required_document_employees (required_document_id, employee_id, tenant_id) VALUES (?, ?, ?)",
            [$requiredDocumentId, $employeeId, $tenantId]
        );
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

    /**
     * Scoped employees with their names (joined to employees so only ones that
     * still exist are returned). Lets clients show names without depending on a
     * paginated employee list.
     */
    public static function getEmployeeScopeDetailed(int $requiredDocumentId, int $tenantId): array {
        $rows = Database::fetchAll(
            "SELECT e.id, e.name
             FROM required_document_employees rde
             JOIN employees e ON e.id = rde.employee_id AND e.tenant_id = rde.tenant_id
             WHERE rde.required_document_id = ? AND rde.tenant_id = ?
             ORDER BY e.name ASC",
            [$requiredDocumentId, $tenantId]
        );
        return array_map(fn($r) => ['id' => (int) $r['id'], 'name' => $r['name']], $rows);
    }

    /** Scoped categories with their names (joined to employee_categories). */
    public static function getCategoryScopeDetailed(int $requiredDocumentId, int $tenantId): array {
        $rows = Database::fetchAll(
            "SELECT c.id, c.name
             FROM required_document_categories rdc
             JOIN employee_categories c ON c.id = rdc.category_id AND c.tenant_id = rdc.tenant_id
             WHERE rdc.required_document_id = ? AND rdc.tenant_id = ?
             ORDER BY c.name ASC",
            [$requiredDocumentId, $tenantId]
        );
        return array_map(fn($r) => ['id' => (int) $r['id'], 'name' => $r['name']], $rows);
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

    public static function upload(int $employeeId, int $tenantId, int $documentTypeId, string $filePath, string $originalName, ?int $uploadedBy = null, ?int $fileSize = null, ?string $mimeType = null, string $status = 'uploaded'): int {
        // $status lets the caller distinguish an admin upload (verified
        // immediately => 'uploaded') from an employee self-submission awaiting
        // review (=> 'pending'). Re-uploading over a rejected document resets
        // the status via VALUES(status) and clears the rejection reason.
        Database::execute(
            "INSERT INTO employee_documents (tenant_id, employee_id, required_document_id, file_path, original_name, file_size, mime_type, uploaded_by, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE file_path = VALUES(file_path), original_name = VALUES(original_name), file_size = VALUES(file_size), mime_type = VALUES(mime_type), status = VALUES(status), uploaded_by = VALUES(uploaded_by), verified_at = NULL, verified_by = NULL, rejected_reason = NULL, notes = NULL",
            [$tenantId, $employeeId, $documentTypeId, $filePath, $originalName, $fileSize, $mimeType, $uploadedBy, $status]
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

    /**
     * Full required-document checklist for an employee: every required document
     * that applies to them by scope (all / their branch / explicit employee /
     * their category), merged with any document they have already uploaded.
     * Not-yet-uploaded items come back with status 'required' so the employee
     * app can prompt for them instead of showing an empty list.
     */
    public static function getEmployeeDocumentChecklist(int $employeeId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT rd.id as required_document_id,
                    rd.name as document_type_name,
                    rd.description,
                    rd.category,
                    rd.is_required,
                    ed.id as employee_document_id,
                    ed.file_path,
                    ed.original_name,
                    ed.rejected_reason,
                    ed.verified_at,
                    ed.expires_at as expiry_date,
                    COALESCE(ed.status, 'required') as status
             FROM required_documents rd
             JOIN employees e ON e.id = ? AND e.tenant_id = ?
             LEFT JOIN employee_documents ed
                    ON ed.required_document_id = rd.id
                   AND ed.employee_id = e.id
                   AND ed.tenant_id = rd.tenant_id
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

    /**
     * Every in-scope active employee for one required-document type, merged with
     * the document they have (if any) for that type. Lets an admin open a single
     * document type and see who submitted it — and who hasn't — in one list,
     * then review / approve / reject from there. Employees with no row come back
     * with document_id = NULL (not yet submitted).
     */
    public static function getSubmissionsForRequired(int $requiredDocumentId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT e.id as employee_id, e.name as employee_name, b.name as branch_name,
                    ed.id as document_id, ed.status, ed.original_name, ed.file_path,
                    ed.mime_type, ed.verified_at, ed.rejected_reason, ed.expires_at,
                    ed.created_at as uploaded_at, rd.name as document_name
             FROM employees e
             JOIN required_documents rd ON rd.id = ? AND rd.tenant_id = e.tenant_id AND (
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
             LEFT JOIN employee_documents ed
                    ON ed.employee_id = e.id
                   AND ed.required_document_id = rd.id
                   AND ed.tenant_id = e.tenant_id
             LEFT JOIN branches b ON b.id = e.branch_id
             WHERE e.tenant_id = ? AND e.status = 'active'
             ORDER BY e.name ASC",
            [$requiredDocumentId, $tenantId, $tenantId]
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

    /**
     * Documents whose expiry date falls within each document type's own
     * configured notification window (notification_days_before), rather than a
     * fixed window. Used by the alert cron so every document type can control
     * how early its expiry reminder fires. Falls back to 30 days when unset.
     */
    public static function getDueForNotification(int $tenantId, ?int $branchId = null): array {
        $sql = "SELECT ed.*, e.name as employee_name, e.branch_id, b.name as branch_name,
                       rd.name as document_name, rd.notification_days_before
                FROM employee_documents ed
                JOIN employees e ON e.id = ed.employee_id
                JOIN required_documents rd ON rd.id = ed.required_document_id
                LEFT JOIN branches b ON b.id = e.branch_id
                WHERE ed.tenant_id = ?
                AND ed.status = 'uploaded'
                AND ed.expires_at IS NOT NULL
                AND ed.expires_at BETWEEN CURDATE()
                    AND DATE_ADD(CURDATE(), INTERVAL COALESCE(rd.notification_days_before, 30) DAY)";
        $params = [$tenantId];

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
