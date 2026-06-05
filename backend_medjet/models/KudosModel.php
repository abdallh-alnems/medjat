<?php

final class KudosModel {
    public const BADGES = ['teamwork', 'innovation', 'leadership', 'customer_service', 'above_beyond', 'reliability', 'thank_you'];
    public const VISIBILITY = ['public', 'private'];

    public static function create(int $tenantId, array $data, ?int $senderAdminId, ?int $senderEmployeeId): int {
        Database::execute(
            "INSERT INTO kudos (tenant_id, recipient_employee_id, sender_employee_id, sender_admin_id, badge, message, visibility)
             VALUES (?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['recipient_employee_id'],
                $senderEmployeeId,
                $senderAdminId,
                $data['badge'] ?? 'thank_you',
                $data['message'],
                $data['visibility'] ?? 'public',
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM kudos WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function wall(int $tenantId, int $limit = 50, ?int $beforeId = null): array {
        $sql = "SELECT k.*,
                       re.name AS recipient_name,
                       se.name AS sender_employee_name,
                       sa.name AS sender_admin_name
                FROM kudos k
                JOIN employees re ON re.id = k.recipient_employee_id
                LEFT JOIN employees se ON se.id = k.sender_employee_id
                LEFT JOIN admins sa ON sa.id = k.sender_admin_id
                WHERE k.tenant_id = ? AND k.visibility = 'public'";
        $params = [$tenantId];
        if ($beforeId !== null) {
            $sql .= " AND k.id < ?";
            $params[] = $beforeId;
        }
        $sql .= " ORDER BY k.created_at DESC LIMIT ?";
        $params[] = $limit;
        return Database::fetchAll($sql, $params);
    }

    public static function receivedBy(int $tenantId, int $employeeId): array {
        return Database::fetchAll(
            "SELECT k.*,
                    se.name AS sender_employee_name,
                    sa.name AS sender_admin_name
             FROM kudos k
             LEFT JOIN employees se ON se.id = k.sender_employee_id
             LEFT JOIN admins sa ON sa.id = k.sender_admin_id
             WHERE k.tenant_id = ? AND k.recipient_employee_id = ?
             ORDER BY k.created_at DESC",
            [$tenantId, $employeeId]
        );
    }

    public static function leaderboard(int $tenantId, int $days = 90, int $limit = 10): array {
        return Database::fetchAll(
            "SELECT k.recipient_employee_id, e.name AS employee_name, COUNT(*) AS kudos_count
             FROM kudos k
             JOIN employees e ON e.id = k.recipient_employee_id
             WHERE k.tenant_id = ? AND k.created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
             GROUP BY k.recipient_employee_id, e.name
             ORDER BY kudos_count DESC
             LIMIT ?",
            [$tenantId, $days, $limit]
        );
    }

    public static function delete(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM kudos WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function notifyRecipient(int $tenantId, int $kudosId, int $recipientEmployeeId, string $badge): void {
        $dataJson = json_encode(['kind' => 'kudos', 'kudos_id' => $kudosId], JSON_UNESCAPED_UNICODE);
        $title = 'New Kudos';
        $body = "You received a {$badge} kudos!";

        Database::execute(
            "INSERT INTO notifications (tenant_id, admin_id, employee_id, type, title, body, data, sent_via)
             VALUES (?, ?, ?, 'general', ?, ?, ?, 'in_app')",
            [$tenantId, null, $recipientEmployeeId, $title, $body, $dataJson]
        );

        $employee = Database::fetchOne(
            "SELECT admin_id FROM employees WHERE id = ? AND tenant_id = ?",
            [$recipientEmployeeId, $tenantId]
        );
        if ($employee && $employee['admin_id']) {
            try {
                NotificationService::sendToUser((int) $employee['admin_id'], $title, $body, ['kind' => 'kudos', 'kudos_id' => $kudosId]);
            } catch (Throwable $e) {
                error_log('Kudos push error: ' . $e->getMessage());
            }
        }
    }
}
