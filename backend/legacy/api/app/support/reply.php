<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_support');

$input = $auth['input'];
$ticketId = (int) ($input['ticket_id'] ?? 0);
$body = trim($input['body'] ?? '');

Validator::required($ticketId, 'ticket_id');
// A screenshot on its own is a complete report, so the body may be empty when
// something is attached — but a message with neither is not a message.
$hasAttachment = !empty($input['attachment']);
if ($body === '' && !$hasAttachment) {
    Response::fail('اكتب رسالة أو أرفق ملفًا', 422, 'body_required');
}
Validator::maxLength($body, 5000, 'body');

$ticket = SupportModel::findTicketById($ticketId, $tenantId);
if (!$ticket) {
    Response::notFound('Ticket');
}

$currentStatus = $ticket['status'];
if ($currentStatus === 'closed') {
    SupportModel::reopenTicket($ticketId, $tenantId);
    $currentStatus = 'pending_support';
}

$attachment = $hasAttachment
    ? SupportAttachment::store($input['attachment'], $ticketId, $input['attachment_name'] ?? null)
    : null;
if ($hasAttachment && $attachment === null) {
    Response::fail('تعذّر حفظ المرفق — يُقبل صورة أو PDF حتى 5 ميجابايت', 422, 'attachment_rejected');
}

$messageId = SupportModel::addMessage(
    $ticketId,
    'user',
    $auth['admin_id'],
    null,
    $body,
    $attachment['path'] ?? null,
    $attachment['name'] ?? null
);

$newStatus = SupportModel::getTicketStatus($ticketId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'support.ticket.reply', 'support_ticket', $ticketId, [
    'message_id' => $messageId,
]);

try {
    EmailService::send(
        getenv('SUPPORT_EMAIL') ?: 'support@permedjat.com',
        'Reply on Ticket #' . $ticketId,
        "Admin #{$auth['admin_id']} replied to ticket #{$ticketId}:\n\n{$body}"
    );
} catch (Throwable $e) {
    error_log('Support email error: ' . $e->getMessage());
}

try {
    NotificationService::sendToSupportTeam(
        'New Support Message',
        mb_substr($body, 0, 100),
        ['type' => 'support', 'ticket_id' => $ticketId]
    );
} catch (Throwable $e) {
    error_log('Support push error: ' . $e->getMessage());
}

Response::success([
    'message_id' => $messageId,
    'status' => $newStatus,
]);
