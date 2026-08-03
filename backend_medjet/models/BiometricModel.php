<?php

final class BiometricModel {
    public static function enrollFace(
        int $employeeId,
        int $tenantId,
        string $embeddingJson,
        ?string $photoUrl,
        float $qualityScore,
        ?string $modelVersion = null,
        ?int $embeddingDim = null
    ): void {
        // COALESCE on the photo keeps an existing reference image when a
        // re-enrollment arrives without one.
        Database::execute(
            "UPDATE employees SET
                face_embedding = ?,
                face_photo_url = COALESCE(?, face_photo_url),
                face_model_version = ?,
                face_embedding_dim = ?,
                face_enrolled_at = NOW(),
                face_quality_score = ?,
                biometric_enrollment_status = CASE
                    WHEN fingerprint_enrolled_at IS NOT NULL THEN 'both'
                    ELSE 'face_only'
                END
             WHERE id = ? AND tenant_id = ?",
            [$embeddingJson, $photoUrl, $modelVersion, $embeddingDim, $qualityScore, $employeeId, $tenantId]
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
                face_photo_url = NULL,
                face_model_version = NULL,
                face_embedding_dim = NULL,
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
                    face_quality_score, face_photo_url, face_model_version, has_linked_account
             FROM employees WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $tenantId]
        );

        if ($emp !== null) {
            // An embedding from a retired model can't be compared against the
            // current one, so surface it as needing re-enrollment rather than
            // letting every check-in fail with a confusing mismatch error.
            $emp['needs_reenrollment'] = $emp['face_enrolled_at'] !== null
                && $emp['face_model_version'] !== FaceMatchService::MODEL_VERSION;
        }

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
