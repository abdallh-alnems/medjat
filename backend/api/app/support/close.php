<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_support');

$input = $auth['input'];
$ticketId = (int) ($input['ticket_id'] ?? 0);
$action = $input['action'] ?? '';

Validator::required($ticketId, 'ticket_id');

$ticket = SupportModel::findTicketById($ticketId, $tenantId);
if (!$ticket) {
    Response::notFound('Ticket');
}

if ($action === 'close') {
    SupportModel::closeTicket($ticketId, $tenantId);
    $newStatus = 'closed';
} elseif ($action === 'reopen') {
    SupportModel::reopenTicket($ticketId, $tenantId);
    $newStatus = 'pending_support';
} else {
    Response::fail('Invalid action. Use "close" or "reopen".', 400, 'invalid_action_close_reopen');
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'support.ticket.' . $action, 'support_ticket', $ticketId, [
    'new_status' => $newStatus,
]);

Response::success(['status' => $newStatus]);
