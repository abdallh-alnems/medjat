<?php

/**
 * Every identification attempt at a kiosk — including the ones that identify
 * nobody, which is the whole reason this table exists separately from
 * `face_verification_logs` (whose `employee_id` is NOT NULL).
 *
 * Two columns here carry the weight of the one-to-many design:
 * `runner_up_score` and `candidates_searched`. The employee app verifies one
 * known person against one threshold; a kiosk resolves an unknown face against
 * a whole roster, and false-accept risk compounds with roster size. Storing the
 * runner-up on every attempt is what lets the margin rule be audited after the
 * fact and the operating point tuned on real data instead of on LFW figures.
 */
final class StationRecognitionLogModel {
    /**
     * Records one attempt.
     *
     * `capture_expires_at` is computed **in SQL** from a seconds interval. PHP
     * runs UTC on this server while MySQL runs the tenant zone, so a
     * PHP-computed expiry is born hours wrong — the face-challenge table
     * learned this the hard way.
     */
    public static function record(array $row, ?int $captureTtlSeconds = null): int {
        $sql = "INSERT INTO station_recognition_logs
                    (tenant_id, station_id, branch_id, employee_id, purpose, method,
                     result, accepted, match_score, runner_up_score, threshold, margin,
                     candidates_searched, liveness_passed, challenge, capture_path,
                     latitude, longitude, attendance_id, capture_expires_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, "
              . ($captureTtlSeconds !== null
                    ? "DATE_ADD(NOW(), INTERVAL ? SECOND))"
                    : "NULL)");

        $params = [
            $row['tenant_id'],
            $row['station_id'],
            $row['branch_id'],
            $row['employee_id']         ?? null,
            $row['purpose']             ?? 'check_in',
            $row['method']              ?? 'face',
            $row['result'],
            !empty($row['accepted']) ? 1 : 0,
            $row['match_score']         ?? null,
            $row['runner_up_score']     ?? null,
            $row['threshold']           ?? null,
            $row['margin']              ?? null,
            $row['candidates_searched'] ?? null,
            !empty($row['liveness_passed']) ? 1 : 0,
            $row['challenge']           ?? null,
            $row['capture_path']        ?? null,
            $row['latitude']            ?? null,
            $row['longitude']           ?? null,
            $row['attendance_id']       ?? null,
        ];

        if ($captureTtlSeconds !== null) {
            $params[] = $captureTtlSeconds;
        }

        Database::execute($sql, $params);
        return (int) Database::lastInsertId();
    }

    public static function linkAttendance(int $logId, int $attendanceId): void {
        Database::execute(
            "UPDATE station_recognition_logs SET attendance_id = ? WHERE id = ?",
            [$attendanceId, $logId]
        );
    }

    /**
     * Attempts for the management app.
     *
     * `capture_path` is deliberately NOT selected. Scores and outcomes are
     * attendance data; the image behind them is biometric evidence and costs a
     * different permission to reach.
     */
    public static function search(int $tenantId, array $filters, int $limit = 100): array {
        $sql = "SELECT l.id, l.station_id, l.branch_id, l.employee_id, l.purpose, l.method,
                       l.result, l.accepted, l.match_score, l.runner_up_score,
                       l.threshold, l.margin, l.candidates_searched,
                       l.liveness_passed, l.attendance_id, l.created_at,
                       (l.capture_path IS NOT NULL) AS has_capture,
                       e.name AS employee_name, s.name AS station_name, b.name AS branch_name
                  FROM station_recognition_logs l
             LEFT JOIN employees e ON e.id = l.employee_id
                  JOIN attendance_stations s ON s.id = l.station_id
                  JOIN branches b ON b.id = l.branch_id
                 WHERE l.tenant_id = ?";
        $params = [$tenantId];

        foreach (['branch_id' => 'l.branch_id', 'station_id' => 'l.station_id', 'result' => 'l.result'] as $key => $column) {
            if (!empty($filters[$key])) {
                $sql .= " AND {$column} = ?";
                $params[] = $filters[$key];
            }
        }
        if (!empty($filters['date_from'])) {
            $sql .= " AND l.created_at >= ?";
            $params[] = $filters['date_from'];
        }
        if (!empty($filters['date_to'])) {
            $sql .= " AND l.created_at <= ?";
            $params[] = $filters['date_to'];
        }

        $sql .= " ORDER BY l.created_at DESC LIMIT " . (int) $limit;
        return Database::fetchAll($sql, $params);
    }

    /**
     * Score histogram, in 0.05 buckets, split by outcome.
     *
     * This is how a company sets `station_match_threshold` and
     * `station_match_margin` on its own data — the same tuning ramp
     * `face_selfie` uses through `app/attendance/face_logs.php`. Shipping with
     * the defaults and never reading this is how a company ends up with a
     * threshold that rejects half its staff.
     */
    public static function distribution(int $tenantId, ?int $branchId = null): array {
        $sql = "SELECT ROUND(FLOOR(match_score * 20) / 20, 2) AS bucket,
                       result,
                       COUNT(*) AS attempts,
                       AVG(runner_up_score) AS avg_runner_up,
                       AVG(candidates_searched) AS avg_candidates
                  FROM station_recognition_logs
                 WHERE tenant_id = ? AND match_score IS NOT NULL";
        $params = [$tenantId];

        if ($branchId !== null) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }

        return Database::fetchAll($sql . " GROUP BY bucket, result ORDER BY bucket", $params);
    }

    /** Rows whose capture has outlived its retention window. */
    public static function expiredCaptures(int $limit = 500): array {
        return Database::fetchAll(
            "SELECT id, capture_path
               FROM station_recognition_logs
              WHERE capture_path IS NOT NULL
                AND capture_expires_at IS NOT NULL
                AND capture_expires_at <= NOW()
              LIMIT " . (int) $limit
        );
    }

    /** Called only after the file itself has been unlinked. */
    public static function clearCapture(int $logId): void {
        Database::execute(
            "UPDATE station_recognition_logs SET capture_path = NULL WHERE id = ?",
            [$logId]
        );
    }
}
