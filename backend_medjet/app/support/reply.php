<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_support');

$input = $auth['input'];
$ticketId = (int) ($input['ticket_id'] ?? 0);
$body = trim($input['body'] ?? '');

Validator::required($ticketId, 'ticket_id');
Validator::required($body, 'body');
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

$messageId = SupportModel::addMessage(
    $ticketId,
    'user',
    $auth['admin_id'],
    null,
    $body
);

$newStatus = SupportModel::getTicketStatus($ticketId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'support.ticket.reply', 'support_ticket', $ticketId, [
    'message_id' => $messageId,
]);

try {
    EmailService::send(
        getenv('SUPPORT_EMAIL') ?: 'support@medjatapp.com',
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
