<?php

final class AnnouncementModel {
    public const CATEGORIES = ['general', 'policy', 'event', 'celebration', 'urgent'];
    public const AUDIENCE_TYPES = ['all', 'branch', 'category', 'employee'];
    public const STATUSES = ['draft', 'published', 'archived'];

    public static function create(int $tenantId, array $data, int $adminId): int {
        Database::execute(
            "INSERT INTO announcements (tenant_id, title, title_ar, body, body_ar, category, audience_type, audience_id, is_pinned, status, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'draft', ?)",
            [
                $tenantId,
                $data['title'],
                $data['title_ar'] ?? null,
                $data['body'],
                $data['body_ar'] ?? null,
                $data['category'] ?? 'general',
                $data['audience_type'] ?? 'all',
                $data['audience_id'] ?? null,
                isset($data['is_pinned']) ? (int) $data['is_pinned'] : 0,
                $adminId,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM announcements WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function listForAdmin(int $tenantId, ?string $status = null): array {
        $sql = "SELECT a.*,
                       COUNT(DISTINCT ar.id) AS read_count
                FROM announcements a
                LEFT JOIN announcement_reads ar ON ar.announcement_id = a.id
                WHERE a.tenant_id = ?";
        $params = [$tenantId];
        if ($status !== null) {
            $sql .= " AND a.status = ?";
            $params[] = $status;
        }
        $sql .= " GROUP BY a.id ORDER BY a.is_pinned DESC, a.created_at DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $allowed = ['title', 'title_ar', 'body', 'body_ar', 'category', 'audience_type', 'audience_id', 'is_pinned'];
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
            "UPDATE announcements SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function setStatus(int $id, int $tenantId, string $status): void {
        $params = [$status];
        $sql = "UPDATE announcements SET status = ?";
        if ($status === 'published') {
            $sql .= ", published_at = COALESCE(published_at, NOW())";
        }
        $sql .= " WHERE id = ? AND tenant_id = ?";
        $params[] = $id;
        $params[] = $tenantId;
        Database::execute($sql, $params);
    }

    public static function resolveAudienceEmployeeIds(int $tenantId, string $audienceType, ?int $audienceId): array {
        switch ($audienceType) {
            case 'all':
                $rows = Database::fetchAll(
                    "SELECT id FROM employees WHERE tenant_id = ? AND status != 'terminated'",
                    [$tenantId]
                );
                return array_column($rows, 'id');

            case 'branch':
                $rows = Database::fetchAll(
                    "SELECT id FROM employees WHERE tenant_id = ? AND branch_id = ? AND status != 'terminated'",
                    [$tenantId, $audienceId]
                );
                return array_column($rows, 'id');

            case 'category':
                $rows = Database::fetchAll(
                    "SELECT e.id FROM employees e
                     JOIN employee_category_assignments eca ON eca.employee_id = e.id AND eca.category_id = ?
                     WHERE e.tenant_id = ? AND e.status != 'terminated'",
                    [$audienceId, $tenantId]
                );
                return array_column($rows, 'id');

            case 'employee':
                $row = Database::fetchOne(
                    "SELECT id FROM employees WHERE id = ? AND tenant_id = ? AND status != 'terminated'",
                    [$audienceId, $tenantId]
                );
                return $row ? [(int) $row['id']] : [];

            default:
                return [];
        }
    }

    public static function feedForEmployee(int $tenantId, int $employeeId, int $branchId, ?int $categoryId): array {
        $sql = "SELECT a.*,
                       CASE WHEN ar.id IS NOT NULL THEN 1 ELSE 0 END AS is_read
                FROM announcements a
                LEFT JOIN announcement_reads ar ON ar.announcement_id = a.id AND ar.employee_id = ?
                WHERE a.tenant_id = ?
                  AND a.status = 'published'
                  AND (
                      a.audience_type = 'all'
                      OR (a.audience_type = 'branch' AND a.audience_id = ?)
                      OR (a.audience_type = 'category' AND a.audience_id = ?)
                      OR (a.audience_type = 'employee' AND a.audience_id = ?)
                  )
                ORDER BY a.is_pinned DESC, a.published_at DESC";

        $rows = Database::fetchAll($sql, [
            $employeeId,
            $tenantId,
            $branchId,
            $categoryId ?? 0,
            $employeeId,
        ]);

        foreach ($rows as &$row) {
            $row['is_read'] = (int) $row['is_read'];
        }
        unset($row);

        return $rows;
    }

    public static function markRead(int $announcementId, int $tenantId, int $employeeId): void {
        Database::execute(
            "INSERT IGNORE INTO announcement_reads (announcement_id, tenant_id, employee_id, read_at)
             VALUES (?, ?, ?, NOW())",
            [$announcementId, $tenantId, $employeeId]
        );
    }

    public static function readStats(int $announcementId, int $tenantId): array {
        $announcement = self::findById($announcementId, $tenantId);
        if (!$announcement) {
            return [];
        }

        $reached = self::resolveAudienceEmployeeIds(
            $tenantId,
            $announcement['audience_type'],
            $announcement['audience_id'] ? (int) $announcement['audience_id'] : null
        );
        $reachedCount = count($reached);

        $readRow = Database::fetchOne(
            "SELECT COUNT(*) AS cnt FROM announcement_reads WHERE announcement_id = ? AND tenant_id = ?",
            [$announcementId, $tenantId]
        );
        $readCount = (int) ($readRow['cnt'] ?? 0);

        $readers = Database::fetchAll(
            "SELECT ar.employee_id, ar.read_at, e.name AS employee_name
             FROM announcement_reads ar
             JOIN employees e ON e.id = ar.employee_id
             WHERE ar.announcement_id = ? AND ar.tenant_id = ?
             ORDER BY ar.read_at ASC",
            [$announcementId, $tenantId]
        );

        return [
            'reached' => $reachedCount,
            'read' => $readCount,
            'readers' => $readers,
        ];
    }

    public static function unreadCount(int $tenantId, int $employeeId, int $branchId, ?int $categoryId): int {
        $sql = "SELECT COUNT(*) AS cnt
                FROM announcements a
                WHERE a.tenant_id = ?
                  AND a.status = 'published'
                  AND (
                      a.audience_type = 'all'
                      OR (a.audience_type = 'branch' AND a.audience_id = ?)
                      OR (a.audience_type = 'category' AND a.audience_id = ?)
                      OR (a.audience_type = 'employee' AND a.audience_id = ?)
                  )
                  AND NOT EXISTS (
                      SELECT 1 FROM announcement_reads ar
                      WHERE ar.announcement_id = a.id AND ar.employee_id = ?
                  )";

        $row = Database::fetchOne($sql, [
            $tenantId,
            $branchId,
            $categoryId ?? 0,
            $employeeId,
            $employeeId,
        ]);

        return (int) ($row['cnt'] ?? 0);
    }

    public static function delete(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM announcements WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function broadcastNotifications(
        int $tenantId,
        int $announcementId,
        string $title,
        ?string $titleAr,
        string $body,
        ?string $bodyAr,
        array $employeeIds
    ): void {
        if (empty($employeeIds)) {
            return;
        }

        $dataJson = json_encode(['kind' => 'announcement', 'announcement_id' => $announcementId], JSON_UNESCAPED_UNICODE);
        $batchSize = 500;
        $chunks = array_chunk($employeeIds, $batchSize);

        foreach ($chunks as $chunk) {
            $placeholders = [];
            $params = [];
            foreach ($chunk as $empId) {
                $placeholders[] = '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
                $params[] = $tenantId;
                $params[] = null;
                $params[] = $empId;
                $params[] = 'general';
                $params[] = $title;
                $params[] = $titleAr;
                $params[] = $body;
                $params[] = $bodyAr;
                $params[] = $dataJson;
                $params[] = 'in_app';
            }
            Database::execute(
                "INSERT INTO notifications (tenant_id, admin_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via) VALUES " . implode(', ', $placeholders),
                $params
            );
        }

        $employeesWithAdmin = Database::fetchAll(
            "SELECT DISTINCT e.admin_id FROM employees e WHERE e.id IN (" . implode(',', array_map('intval', $employeeIds)) . ") AND e.admin_id IS NOT NULL AND e.tenant_id = ?",
            [$tenantId]
        );
        foreach ($employeesWithAdmin as $row) {
            try {
                NotificationService::sendToUser((int) $row['admin_id'], $title, $body, ['kind' => 'announcement', 'announcement_id' => $announcementId]);
            } catch (Throwable $e) {
                error_log('Announcement push error: ' . $e->getMessage());
            }
        }
    }
}
