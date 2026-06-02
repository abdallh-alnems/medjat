<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateEmployee(db());

$limit = min((int) ($_GET['limit'] ?? 50), 100);
$offset = (int) ($_GET['offset'] ?? 0);
$unreadOnly = isset($_GET['unread_only']) && filter_var($_GET['unread_only'], FILTER_VALIDATE_BOOLEAN);

$sql = "SELECT id, type, title, title_ar, body, body_ar, data, read_at, created_at
        FROM notifications
        WHERE admin_id = ?";
$params = [$auth['admin_id']];

if ($unreadOnly) {
    $sql .= " AND read_at IS NULL";
}

$sql .= " ORDER BY created_at DESC LIMIT ? OFFSET ?";
$params[] = $limit;
$params[] = $offset;

$notifications = Database::fetchAll($sql, $params);

$unreadCount = Database::fetchOne(
    "SELECT COUNT(*) as cnt FROM notifications WHERE admin_id = ? AND read_at IS NULL",
    [$auth['admin_id']]
);

Response::success([
    'notifications' => $notifications,
    'unread_count' => (int) $unreadCount['cnt'],
]);
