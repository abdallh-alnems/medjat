<?php

final class DocumentModel {
    public static function getRequiredByTenant(int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM required_documents WHERE tenant_id = ? AND is_active = 1 ORDER BY name ASC",
            [$tenantId]
        );
    }

    public static function addRequired(int $tenantId, string $name, ?string $description = null): int {
        Database::execute(
            "INSERT INTO required_documents (tenant_id, name, description) VALUES (?, ?, ?)",
            [$tenantId, $name, $description]
        );
        return (int) Database::lastInsertId();
    }

    public static function upload(int $employeeId, int $tenantId, int $documentTypeId, string $filePath, string $originalName, int $uploadedBy): int {
        Database::execute(
            "INSERT INTO employee_documents (tenant_id, employee_id, required_document_id, file_path, original_name, uploaded_by, status)
             VALUES (?, ?, ?, ?, ?, ?, 'uploaded')
             ON DUPLICATE KEY UPDATE file_path = VALUES(file_path), original_name = VALUES(original_name), status = 'uploaded', uploaded_by = VALUES(uploaded_by)",
            [$tenantId, $employeeId, $documentTypeId, $filePath, $originalName, $uploadedBy]
        );
        return (int) Database::lastInsertId();
    }

    public static function getByEmployee(int $employeeId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT ed.*, rd.name as document_name, rd.description
             FROM employee_documents ed
             LEFT JOIN required_documents rd ON rd.id = ed.required_document_id
             WHERE ed.employee_id = ? AND ed.tenant_id = ?
             ORDER BY rd.name ASC",
            [$employeeId, $tenantId]
        );
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
        $sql = "SELECT e.id as employee_id, e.name as employee_name, rd.name as document_name
                FROM employees e
                CROSS JOIN required_documents rd
                LEFT JOIN employee_documents ed ON ed.employee_id = e.id AND ed.required_document_id = rd.id
                WHERE e.tenant_id = ? AND e.status = 'active' AND rd.is_active = 1 AND ed.id IS NULL";
        $params = [$tenantId];

        if ($employeeId) {
            $sql .= " AND e.id = ?";
            $params[] = $employeeId;
        }

        return Database::fetchAll($sql, $params);
    }
}
