<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_support');

$ticketId = (int) ($_GET['ticket_id'] ?? 0);
Validator::required($ticketId, 'ticket_id');

$ticket = SupportModel::findTicketById($ticketId, $tenantId);
if (!$ticket) {
    Response::notFound('Ticket');
}

$afterId = isset($_GET['after_id']) ? (int) $_GET['after_id'] : null;
$markRead = ($afterId === null);

$messagesResult = SupportModel::getMessages($ticketId, $afterId, $markRead);

if ($markRead) {
    $ticket = SupportModel::findTicketById($ticketId, $tenantId);
}

Response::success([
    'ticket' => $ticket,
    'messages' => $messagesResult['messages'],
    'last_id' => $messagesResult['last_id'],
]);
