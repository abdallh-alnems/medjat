<?php

/**
 * Audit trail for every face-verification attempt, accepted or not.
 *
 * This is what makes threshold tuning possible: run the company in `log_only`
 * mode for a couple of weeks, look at the score distribution for `matched` vs
 * `below_threshold`, then raise or lower the threshold on real data instead of
 * guessing. It is also the evidence when an employee disputes a rejection.
 */
final class FaceVerificationLogModel {
    /**
     * Has this employee already sent these exact numbers?
     *
     * A genuine capture never repeats: lighting, head angle and distance all
     * move between attempts, so two identical embeddings did not both come from
     * a camera. One of them was replayed from storage.
     *
     * Not time-windowed on purpose. An embedding identical to one from six
     * months ago is no less impossible than one from this morning, and the index
     * on (tenant_id, employee_id, embedding_hash) makes the age irrelevant to
     * the cost.
     *
     * Returns the id of the earlier attempt, so the security log can point at
     * it, or null when this capture is new.
     */
    public static function findReplay(int $tenantId, int $employeeId, string $embeddingHash): ?int {
        if ($embeddingHash === '') {
            return null;
        }

        try {
            $row = Database::fetchOne(
                "SELECT id FROM face_verification_logs
                 WHERE tenant_id = ? AND employee_id = ? AND embedding_hash = ?
                 ORDER BY id LIMIT 1",
                [$tenantId, $employeeId, $embeddingHash]
            );
            return $row !== null ? (int) $row['id'] : null;
        } catch (Exception $e) {
            // Never let this check break a check-in. A failure here means the
            // detection is unavailable, not that the attempt is a replay —
            // failing closed would lock out a whole company over a bad index.
            error_log('Face replay lookup failed: ' . $e->getMessage());
            return null;
        }
    }

    /** Logging must never break a check-in, so failures are swallowed. */
    public static function log(array $row): void {
        try {
            Database::execute(
                "INSERT INTO face_verification_logs
                    (tenant_id, employee_id, branch_id, purpose, result, accepted,
                     match_score, threshold, liveness_passed, challenge,
                     latitude, longitude, selfie_path, is_mock_location, is_rooted_device,
                     embedding_hash)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    $row['tenant_id'],
                    $row['employee_id'],
                    $row['branch_id'] ?? null,
                    $row['purpose'] ?? 'check_in',
                    $row['result'],
                    !empty($row['accepted']) ? 1 : 0,
                    $row['match_score'] ?? null,
                    $row['threshold'] ?? null,
                    !empty($row['liveness_passed']) ? 1 : 0,
                    $row['challenge'] ?? null,
                    $row['latitude'] ?? null,
                    $row['longitude'] ?? null,
                    $row['selfie_path'] ?? null,
                    !empty($row['is_mock_location']) ? 1 : 0,
                    !empty($row['is_rooted_device']) ? 1 : 0,
                    $row['embedding_hash'] ?? null,
                ]
            );
        } catch (Exception $e) {
            error_log('Face verification log failed: ' . $e->getMessage());
        }
    }

    /** Recent attempts for one employee (HR review on the employee profile). */
    public static function recentForEmployee(int $employeeId, int $tenantId, int $limit = 20): array {
        $limit = max(1, min(100, $limit));

        return Database::fetchAll(
            "SELECT id, branch_id, purpose, result, accepted, match_score, threshold,
                    liveness_passed, challenge, selfie_path, created_at
             FROM face_verification_logs
             WHERE employee_id = ? AND tenant_id = ?
             ORDER BY id DESC
             LIMIT {$limit}",
            [$employeeId, $tenantId]
        );
    }

    /**
     * Score distribution for the tuning phase: how many attempts landed in each
     * 0.05-wide score bucket, split by whether they cleared the threshold.
     */
    public static function scoreDistribution(int $tenantId, int $days = 30): array {
        $days = max(1, min(365, $days));

        return Database::fetchAll(
            "SELECT ROUND(FLOOR(match_score * 20) / 20, 2) AS bucket,
                    result,
                    COUNT(*) AS attempts
             FROM face_verification_logs
             WHERE tenant_id = ?
               AND match_score IS NOT NULL
               AND created_at >= DATE_SUB(NOW(), INTERVAL {$days} DAY)
             GROUP BY bucket, result
             ORDER BY bucket",
            [$tenantId]
        );
    }
}
