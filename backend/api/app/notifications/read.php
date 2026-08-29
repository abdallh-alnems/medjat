<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());

$input = $auth['input'];
$id = (int) ($input['id'] ?? $_GET['id'] ?? 0);

if ($id <= 0) {
    Response::fail('Notification ID is required', 400, 'notification_id_required');
}

$notification = Database::fetchOne(
    "SELECT id, admin_id FROM notifications WHERE id = ? AND admin_id = ? LIMIT 1",
    [$id, $auth['admin_id']]
);

if (!$notification) {
    Response::notFound('Notification');
}

Database::execute(
    "UPDATE notifications SET read_at = NOW() WHERE id = ? AND admin_id = ? AND read_at IS NULL",
    [$id, $auth['admin_id']]
);

Response::success(['message' => 'Marked as read']);
