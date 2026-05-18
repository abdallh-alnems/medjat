<?php

final class PerformanceModel {
    public static function addReview(int $employeeId, int $tenantId, float $rating, string $review, int $reviewerId): int {
        Database::execute(
            "INSERT INTO performance_reviews (tenant_id, employee_id, rating, review, reviewer_id) VALUES (?, ?, ?, ?, ?)",
            [$tenantId, $employeeId, $rating, $review, $reviewerId]
        );
        return (int) Database::lastInsertId();
    }

    public static function getByEmployee(int $employeeId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT pr.*, a.name as reviewer_name FROM performance_reviews pr
             LEFT JOIN admins a ON a.id = pr.reviewer_id
             WHERE pr.employee_id = ? AND pr.tenant_id = ?
             ORDER BY pr.created_at DESC",
            [$employeeId, $tenantId]
        );
    }

    public static function update(int $id, int $tenantId, float $rating, string $review): void {
        Database::execute(
            "UPDATE performance_reviews SET rating = ?, review = ? WHERE id = ? AND tenant_id = ?",
            [$rating, $review, $id, $tenantId]
        );
    }
}
