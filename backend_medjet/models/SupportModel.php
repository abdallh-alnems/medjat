<?php

final class SupportModel {
    public const CATEGORIES = ['technical', 'billing', 'feature_request', 'account', 'other'];
    public const PRIORITIES = ['low', 'normal', 'high', 'urgent'];
    public const STATUSES = ['open', 'pending_support', 'pending_user', 'resolved', 'closed'];

    public static function createTicket(
        int $tenantId,
        int $adminId,
        string $subject,
        string $category,
        string $priority,
        string $body
    ): int {
        $db = Database::getInstance();
        $db->beginTransaction();
        try {
            Database::execute(
                "INSERT INTO support_tickets
                    (tenant_id, opened_by_admin_id, subject, category, priority, status, unread_for_support, last_message_at, last_message_preview)
                 VALUES (?, ?, ?, ?, ?, 'open', 1, NOW(), ?)",
                [$tenantId, $adminId, $subject, $category, $priority, mb_substr($body, 0, 255)]
            );
            $ticketId = (int) Database::lastInsertId();

            Database::execute(
                "INSERT INTO support_messages (ticket_id, sender_type, sender_admin_id, body)
                 VALUES (?, 'user', ?, ?)",
                [$ticketId, $adminId, $body]
            );

            $db->commit();
            return $ticketId;
        } catch (Throwable $e) {
            $db->rollBack();
            throw $e;
        }
    }

    public static function listByTenant(int $tenantId, ?string $status = null, int $page = 1, int $limit = 20): array {
        $offset = ($page - 1) * $limit;
        $sql = "SELECT * FROM support_tickets WHERE tenant_id = ?";
        $params = [$tenantId];

        if ($status !== null && $status !== '' && in_array($status, self::STATUSES, true)) {
            $sql .= " AND status = ?";
            $params[] = $status;
        }

        $countSql = str_replace("SELECT *", "SELECT COUNT(*) AS c", $sql);
        $total = (int) (Database::fetchOne($countSql, $params)['c'] ?? 0);

        $sql .= " ORDER BY last_message_at DESC, created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;

        $tickets = Database::fetchAll($sql, $params);

        $unreadTotal = (int) (Database::fetchOne(
            "SELECT COUNT(*) AS c FROM support_tickets WHERE tenant_id = ? AND unread_for_user = 1 AND status NOT IN ('closed','resolved')",
            [$tenantId]
        )['c'] ?? 0);

        return [
            'tickets' => $tickets,
            'total' => $total,
            'page' => $page,
            'unread_total' => $unreadTotal,
        ];
    }

    public static function findTicketById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM support_tickets WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function findTicketByIdGlobal(int $id): ?array {
        return Database::fetchOne(
            "SELECT st.*, t.name AS tenant_name FROM support_tickets st JOIN tenants t ON t.id = st.tenant_id WHERE st.id = ?",
            [$id]
        );
    }

    public static function getMessages(int $ticketId, ?int $afterId = null, bool $markRead = false): array {
        if ($markRead) {
            Database::execute(
                "UPDATE support_tickets SET unread_for_user = 0 WHERE id = ?",
                [$ticketId]
            );
        }

        $sql = "SELECT * FROM support_messages WHERE ticket_id = ?";
        $params = [$ticketId];

        if ($afterId !== null) {
            $sql .= " AND id > ?";
            $params[] = $afterId;
        }

        $sql .= " ORDER BY id ASC";
        $messages = Database::fetchAll($sql, $params);

        $lastId = 0;
        if (!empty($messages)) {
            $lastId = (int) end($messages)['id'];
        }

        return [
            'messages' => $messages,
            'last_id' => $lastId,
        ];
    }

    public static function addMessage(
        int $ticketId,
        string $senderType,
        ?int $senderAdminId,
        ?int $senderSuperAdminId,
        string $body
    ): int {
        $db = Database::getInstance();
        $db->beginTransaction();
        try {
            Database::execute(
                "INSERT INTO support_messages (ticket_id, sender_type, sender_admin_id, sender_super_admin_id, body)
                 VALUES (?, ?, ?, ?, ?)",
                [$ticketId, $senderType, $senderAdminId, $senderSuperAdminId, $body]
            );
            $messageId = (int) Database::lastInsertId();

            $preview = mb_substr($body, 0, 255);

            if ($senderType === 'user') {
                Database::execute(
                    "UPDATE support_tickets
                     SET status = 'pending_support', unread_for_support = 1, unread_for_user = 0,
                         last_message_at = NOW(), last_message_preview = ?
                     WHERE id = ?",
                    [$preview, $ticketId]
                );
            } elseif ($senderType === 'support') {
                Database::execute(
                    "UPDATE support_tickets
                     SET status = 'pending_user', unread_for_user = 1, unread_for_support = 0,
                         last_message_at = NOW(), last_message_preview = ?
                     WHERE id = ?",
                    [$preview, $ticketId]
                );
            }

            $db->commit();
            return $messageId;
        } catch (Throwable $e) {
            $db->rollBack();
            throw $e;
        }
    }

    public static function closeTicket(int $ticketId, int $tenantId): void {
        Database::execute(
            "UPDATE support_tickets SET status = 'closed' WHERE id = ? AND tenant_id = ?",
            [$ticketId, $tenantId]
        );
    }

    public static function reopenTicket(int $ticketId, int $tenantId): void {
        Database::execute(
            "UPDATE support_tickets SET status = 'pending_support', unread_for_support = 1, unread_for_user = 0 WHERE id = ? AND tenant_id = ?",
            [$ticketId, $tenantId]
        );
    }

    public static function markReadBySupport(int $ticketId): void {
        Database::execute(
            "UPDATE support_tickets SET unread_for_support = 0 WHERE id = ?",
            [$ticketId]
        );
    }

    public static function getTicketStatus(int $ticketId): ?string {
        $row = Database::fetchOne(
            "SELECT status FROM support_tickets WHERE id = ?",
            [$ticketId]
        );
        return $row ? $row['status'] : null;
    }

    public static function listAll(?string $status = null, ?int $tenantId = null, int $page = 1, int $limit = 30): array {
        $offset = ($page - 1) * $limit;
        $sql = "SELECT st.*, t.name AS tenant_name FROM support_tickets st JOIN tenants t ON t.id = st.tenant_id WHERE 1=1";
        $params = [];

        if ($status !== null && $status !== '' && in_array($status, self::STATUSES, true)) {
            $sql .= " AND st.status = ?";
            $params[] = $status;
        }
        if ($tenantId !== null) {
            $sql .= " AND st.tenant_id = ?";
            $params[] = $tenantId;
        }

        $countSql = str_replace("SELECT st.*, t.name AS tenant_name", "SELECT COUNT(*) AS c", $sql);
        $total = (int) (Database::fetchOne($countSql, $params)['c'] ?? 0);

        $sql .= " ORDER BY st.last_message_at DESC, st.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;

        return [
            'tickets' => Database::fetchAll($sql, $params),
            'total' => $total,
            'page' => $page,
        ];
    }

    public static function setTicketStatus(int $ticketId, string $status): void {
        Database::execute(
            "UPDATE support_tickets SET status = ? WHERE id = ?",
            [$status, $ticketId]
        );
    }

    public static function assignTicket(int $ticketId, int $superAdminId): void {
        Database::execute(
            "UPDATE support_tickets SET assigned_super_admin_id = ? WHERE id = ?",
            [$superAdminId, $ticketId]
        );
    }
}
