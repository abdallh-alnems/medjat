<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$admin = AdminAuth::require('admin');

$input = json_decode(file_get_contents('php://input'), true) ?? [];
$ticketId = (int) ($input['ticket_id'] ?? 0);
$body = trim($input['body'] ?? '');

Validator::required($ticketId, 'ticket_id');
// A screenshot on its own is a complete answer, so the body may be empty when
// something is attached — but a message with neither is not a message.
$hasAttachment = !empty($input['attachment']);
if ($body === '' && !$hasAttachment) {
    Response::fail('اكتب رسالة أو أرفق ملفًا', 422, 'body_required');
}
Validator::maxLength($body, 5000, 'body');

$ticket = SupportModel::findTicketByIdGlobal($ticketId);
if (!$ticket) {
    Response::notFound('Ticket');
}

$attachment = $hasAttachment
    ? SupportAttachment::store($input['attachment'], $ticketId, $input['attachment_name'] ?? null)
    : null;
if ($hasAttachment && $attachment === null) {
    Response::fail('تعذّر حفظ المرفق — يُقبل صورة أو PDF حتى 5 ميجابايت', 422, 'attachment_rejected');
}

$messageId = SupportModel::addMessage(
    $ticketId,
    'support',
    null,
    (int) $admin['admin_id'],
    $body,
    $attachment['path'] ?? null,
    $attachment['name'] ?? null
);

$preview = $body !== '' ? $body : ('📎 ' . ($attachment['name'] ?? 'مرفق'));

NotificationService::sendToUser(
    (int) $ticket['opened_by_admin_id'],
    'Support Reply',
    mb_substr($preview, 0, 100),
    ['type' => 'support', 'ticket_id' => $ticketId]
);

Database::execute(
    "INSERT INTO notifications (admin_id, tenant_id, type, title, title_ar, body, body_ar)
     VALUES (?, NULL, 'support', 'Support Reply', 'رد الدعم', ?, ?)",
    [$ticket['opened_by_admin_id'], mb_substr($preview, 0, 200), mb_substr($preview, 0, 200)]
);

AdminAuth::logAction('support.reply', 'support_ticket', $ticketId, ['message_id' => $messageId]);

Response::success([
    'message_id' => $messageId,
    'status' => SupportModel::getTicketStatus($ticketId),
]);
