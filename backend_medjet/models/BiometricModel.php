<?php

final class BiometricModel {
    public static function enrollFace(int $employeeId, int $tenantId, string $embeddingJson, ?string $photoUrl, float $qualityScore): void {
        Database::execute(
            "UPDATE employees SET
                face_embedding = ?,
                face_enrolled_at = NOW(),
                face_quality_score = ?,
                biometric_enrollment_status = CASE
                    WHEN fingerprint_enrolled_at IS NOT NULL THEN 'both'
                    ELSE 'face_only'
                END
             WHERE id = ? AND tenant_id = ?",
            [$embeddingJson, $qualityScore, $employeeId, $tenantId]
        );
    }

    public static function enrollFingerprint(int $employeeId, int $tenantId, string $encryptedTemplate): void {
        Database::execute(
            "UPDATE employees SET
                fingerprint_enrolled_at = NOW(),
                biometric_enrollment_status = CASE
                    WHEN face_embedding IS NOT NULL THEN 'both'
                    ELSE 'fingerprint_only'
                END
             WHERE id = ? AND tenant_id = ?",
            [$employeeId, $tenantId]
        );
    }

    public static function deleteFace(int $employeeId, int $tenantId): void {
        $emp = EmployeeModel::findById($employeeId, $tenantId);
        $newStatus = ($emp && $emp['fingerprint_enrolled_at']) ? 'fingerprint_only' : 'not_enrolled';
        Database::execute(
            "UPDATE employees SET
                face_embedding = NULL,
                face_enrolled_at = NULL,
                face_quality_score = NULL,
                biometric_enrollment_status = ?
             WHERE id = ? AND tenant_id = ?",
            [$newStatus, $employeeId, $tenantId]
        );
    }

    public static function deleteFingerprint(int $employeeId, int $tenantId): void {
        $emp = EmployeeModel::findById($employeeId, $tenantId);
        $newStatus = ($emp && $emp['face_embedding']) ? 'face_only' : 'not_enrolled';
        Database::execute(
            "UPDATE employees SET
                fingerprint_enrolled_at = NULL,
                biometric_enrollment_status = ?
             WHERE id = ? AND tenant_id = ?",
            [$newStatus, $employeeId, $tenantId]
        );
    }

    public static function getStatus(int $employeeId, int $tenantId): ?array {
        $emp = Database::fetchOne(
            "SELECT biometric_enrollment_status, face_enrolled_at, fingerprint_enrolled_at,
                    face_quality_score, has_linked_account
             FROM employees WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $tenantId]
        );
        return $emp;
    }

    public static function findEmployeesForBranch(int $branchId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT id, name, biometric_enrollment_status, face_embedding
             FROM employees
             WHERE branch_id = ? AND tenant_id = ? AND status = 'active'
               AND biometric_enrollment_status != 'not_enrolled'",
            [$branchId, $tenantId]
        );
    }
}
