<?php

final class CandidateModel {
    public const STAGES = ['applied', 'screening', 'interview', 'offer', 'hired', 'rejected'];

    public static function create(int $tenantId, array $data, int $adminId): int {
        Database::execute(
            "INSERT INTO candidates
                (tenant_id, job_opening_id, name, email, phone, cv_url, source, stage, expected_salary, notes, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['job_opening_id'] ?? null,
                $data['name'],
                $data['email'] ?? null,
                $data['phone'] ?? null,
                $data['cv_url'] ?? null,
                $data['source'] ?? null,
                $data['stage'] ?? 'applied',
                $data['expected_salary'] ?? null,
                $data['notes'] ?? null,
                $adminId,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM candidates WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function listByTenant(int $tenantId, ?int $jobId = null, ?string $stage = null): array {
        $sql = "SELECT c.*, jo.title AS job_title
                FROM candidates c
                LEFT JOIN job_openings jo ON jo.id = c.job_opening_id
                WHERE c.tenant_id = ?";
        $params = [$tenantId];
        if ($jobId !== null) {
            $sql .= " AND c.job_opening_id = ?";
            $params[] = $jobId;
        }
        if ($stage !== null && $stage !== '') {
            $sql .= " AND c.stage = ?";
            $params[] = $stage;
        }
        $sql .= " ORDER BY c.created_at DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function updateStage(int $id, int $tenantId, string $stage, ?string $rejectionReason = null): void {
        if ($stage === 'rejected' && $rejectionReason !== null) {
            Database::execute(
                "UPDATE candidates SET stage = ?, rejection_reason = ? WHERE id = ? AND tenant_id = ?",
                [$stage, $rejectionReason, $id, $tenantId]
            );
        } else {
            Database::execute(
                "UPDATE candidates SET stage = ? WHERE id = ? AND tenant_id = ?",
                [$stage, $id, $tenantId]
            );
        }
    }

    public static function attachEmployee(int $id, int $tenantId, int $employeeId): void {
        Database::execute(
            "UPDATE candidates SET stage = 'hired', converted_employee_id = ? WHERE id = ? AND tenant_id = ?",
            [$employeeId, $id, $tenantId]
        );
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $allowed = ['job_opening_id', 'email', 'phone', 'cv_url', 'source', 'expected_salary', 'notes', 'name'];
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
            "UPDATE candidates SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }
}
