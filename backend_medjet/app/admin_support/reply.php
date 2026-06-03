<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$admin = AdminAuth::require('admin');

$input = json_decode(file_get_contents('php://input'), true) ?? [];
$ticketId = (int) ($input['ticket_id'] ?? 0);
$body = trim($input['body'] ?? '');

Validator::required($ticketId, 'ticket_id');
Validator::required($body, 'body');
Validator::maxLength($body, 5000, 'body');

$ticket = SupportModel::findTicketByIdGlobal($ticketId);
if (!$ticket) {
    Response::notFound('Ticket');
}

$messageId = SupportModel::addMessage(
    $ticketId,
    'support',
    null,
    (int) $admin['admin_id'],
    $body
);

NotificationService::sendToUser(
    (int) $ticket['opened_by_admin_id'],
    'Support Reply',
    mb_substr($body, 0, 100),
    ['type' => 'support', 'ticket_id' => $ticketId]
);

Database::execute(
    "INSERT INTO notifications (admin_id, tenant_id, type, title, title_ar, body, body_ar)
     VALUES (?, NULL, 'support', 'Support Reply', 'رد الدعم', ?, ?)",
    [$ticket['opened_by_admin_id'], mb_substr($body, 0, 200), mb_substr($body, 0, 200)]
);

AdminAuth::logAction('support.reply', 'support_ticket', $ticketId, ['message_id' => $messageId]);

Response::success([
    'message_id' => $messageId,
    'status' => SupportModel::getTicketStatus($ticketId),
]);
