<?php

final class PerformanceModel {
    public const REVIEWER_TYPES = ['manager','self','peer','subordinate'];
    public const STATUSES = ['draft','submitted'];

    public static function create(int $tenantId, array $data, int $reviewerId): int {
        Database::execute(
            "INSERT INTO performance_reviews (tenant_id, employee_id, cycle_id, reviewer_id, reviewer_type, rating, strengths, areas_for_improvement, review, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['employee_id'],
                $data['cycle_id'] ?? null,
                $reviewerId,
                $data['reviewer_type'] ?? 'manager',
                $data['rating'] ?? null,
                $data['strengths'] ?? null,
                $data['areas_for_improvement'] ?? null,
                $data['review'] ?? null,
                $data['status'] ?? 'submitted',
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function addReview(int $employeeId, int $tenantId, float $rating, string $review, int $reviewerId): int {
        return self::create($tenantId, [
            'employee_id' => $employeeId,
            'rating' => $rating,
            'review' => $review,
            'reviewer_type' => 'manager',
            'status' => 'submitted',
        ], $reviewerId);
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT pr.*, a.name AS reviewer_name
             FROM performance_reviews pr
             LEFT JOIN admins a ON a.id = pr.reviewer_id
             WHERE pr.id = ? AND pr.tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        ) ?: null;
    }

    public static function getByEmployee(int $employeeId, int $tenantId, ?int $cycleId = null): array {
        $sql = "SELECT pr.*, a.name AS reviewer_name
                FROM performance_reviews pr
                LEFT JOIN admins a ON a.id = pr.reviewer_id
                WHERE pr.employee_id = ? AND pr.tenant_id = ?";
        $params = [$employeeId, $tenantId];
        if ($cycleId !== null) {
            $sql .= " AND pr.cycle_id = ?";
            $params[] = $cycleId;
        }
        $sql .= " ORDER BY pr.created_at DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $allowed = ['rating', 'strengths', 'areas_for_improvement', 'review', 'status', 'reviewer_type'];
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
            "UPDATE performance_reviews SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function delete(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM performance_reviews WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function summary(int $tenantId, int $employeeId, ?int $cycleId = null): array {
        $sql = "SELECT
                    COUNT(*) AS reviews_count,
                    AVG(rating) AS avg_rating,
                    (SELECT rating FROM performance_reviews
                     WHERE tenant_id = ? AND employee_id = ?";
        $params = [$tenantId, $employeeId];
        if ($cycleId !== null) {
            $sql .= " AND cycle_id = ?";
            $params[] = $cycleId;
        }
        $sql .= " AND rating IS NOT NULL ORDER BY created_at DESC LIMIT 1) AS latest_rating
                FROM performance_reviews
                WHERE tenant_id = ? AND employee_id = ?";
        $params[] = $tenantId;
        $params[] = $employeeId;
        if ($cycleId !== null) {
            $sql .= " AND cycle_id = ?";
            $params[] = $cycleId;
        }

        $row = Database::fetchOne($sql, $params);
        return [
            'reviews_count' => (int) ($row['reviews_count'] ?? 0),
            'avg_rating' => $row['avg_rating'] !== null ? round((float) $row['avg_rating'], 2) : null,
            'latest_rating' => $row['latest_rating'] !== null ? round((float) $row['latest_rating'], 2) : null,
        ];
    }
}
