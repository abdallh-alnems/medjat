<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$admin = AdminAuth::require('admin');

$input = json_decode(file_get_contents('php://input'), true) ?? [];
$ticketId = (int) ($input['ticket_id'] ?? 0);
$status = trim($input['status'] ?? '');

Validator::required($ticketId, 'ticket_id');
Validator::required($status, 'status');

$allowedStatuses = ['resolved', 'closed', 'reopen'];
Validator::enum($status, $allowedStatuses, 'status');

$ticket = SupportModel::findTicketByIdGlobal($ticketId);
if (!$ticket) {
    Response::notFound('Ticket');
}

$previousStatus = SupportModel::getTicketStatus($ticketId);

$mappedStatus = $status === 'reopen' ? 'pending_support' : $status;
SupportModel::setTicketStatus($ticketId, $mappedStatus);

AdminAuth::logAction('support.status', 'support_ticket', $ticketId, [
    'from' => $previousStatus,
    'to' => $mappedStatus,
]);

Response::success([
    'ticket_id' => $ticketId,
    'status' => $mappedStatus,
]);
