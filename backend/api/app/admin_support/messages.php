<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$admin = AdminAuth::require('admin');

$ticketId = (int) ($_GET['ticket_id'] ?? 0);
Validator::required($ticketId, 'ticket_id');

$ticket = SupportModel::findTicketByIdGlobal($ticketId);
if (!$ticket) {
    Response::notFound('Ticket');
}

$afterId = isset($_GET['after_id']) ? (int) $_GET['after_id'] : null;
$markRead = ($afterId === null);

if ($markRead) {
    SupportModel::markReadBySupport($ticketId);
}

$messagesResult = SupportModel::getMessages($ticketId, $afterId, false);

if ($markRead) {
    $ticket = SupportModel::findTicketByIdGlobal($ticketId);
}

Response::success([
    'ticket' => $ticket,
    'messages' => $messagesResult['messages'],
    'last_id' => $messagesResult['last_id'],
]);
