<?php

final class DocumentRequestModel {
    public static function create(
        int $tenantId,
        int $employeeId,
        ?int $templateId,
        ?string $docType,
        array $extraFields,
        string $status = 'pending',
        bool $requestedByEmployee = false,
        ?int $issuedBy = null
    ): int {
        $processedAt = $status === 'pending' ? null : date('Y-m-d H:i:s');
        Database::execute(
            "INSERT INTO document_requests
                (tenant_id, employee_id, template_id, doc_type, status, extra_fields,
                 requested_by_employee, issued_by, processed_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $employeeId,
                $templateId,
                $docType,
                $status,
                empty($extraFields) ? null : json_encode($extraFields, JSON_UNESCAPED_UNICODE),
                $requestedByEmployee ? 1 : 0,
                $issuedBy,
                $processedAt,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function find(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT r.*, e.name AS employee_name
             FROM document_requests r
             JOIN employees e ON e.id = r.employee_id
             WHERE r.id = ? AND r.tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function getByTenant(int $tenantId, ?string $status = null, int $page = 1, int $limit = 30): array {
        $sql = "SELECT r.*, e.name AS employee_name, t.name_ar AS template_name_ar, t.name_en AS template_name_en
                FROM document_requests r
                JOIN employees e ON e.id = r.employee_id
                LEFT JOIN document_templates t ON t.id = r.template_id
                WHERE r.tenant_id = ?";
        $params = [$tenantId];
        if ($status !== null && $status !== '') {
            $sql .= " AND r.status = ?";
            $params[] = $status;
        }
        $offset = ($page - 1) * $limit;
        $sql .= " ORDER BY r.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        return ['items' => Database::fetchAll($sql, $params), 'page' => $page];
    }

    public static function markApproved(int $id, int $tenantId, int $issuedBy, string $pdfPath): void {
        Database::execute(
            "UPDATE document_requests
             SET status = 'approved', issued_by = ?, pdf_path = ?, processed_at = NOW()
             WHERE id = ? AND tenant_id = ?",
            [$issuedBy, $pdfPath, $id, $tenantId]
        );
    }

    public static function markRejected(int $id, int $tenantId, int $issuedBy, ?string $reason): void {
        Database::execute(
            "UPDATE document_requests
             SET status = 'rejected', issued_by = ?, rejection_reason = ?, processed_at = NOW()
             WHERE id = ? AND tenant_id = ?",
            [$issuedBy, $reason, $id, $tenantId]
        );
    }

    public static function setPdfPath(int $id, int $tenantId, string $pdfPath): void {
        Database::execute(
            "UPDATE document_requests SET pdf_path = ? WHERE id = ? AND tenant_id = ?",
            [$pdfPath, $id, $tenantId]
        );
    }

    public static function decodeExtra(?string $raw): array {
        if (empty($raw)) {
            return [];
        }
        $decoded = json_decode($raw, true);
        return is_array($decoded) ? $decoded : [];
    }
}
