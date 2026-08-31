<?php
// Serve one support attachment to the company that owns the ticket.
//
// The tenant-side twin of app/admin_support/attachment.php. The ownership check
// is the point: a message id is a small integer, so without it any company
// could walk another company's attachments.
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$messageId = (int) ($_GET['message_id'] ?? 0);
Validator::required($messageId, 'message_id');

$message = Database::fetchOne(
    "SELECT m.id, m.attachment_url, m.attachment_name
     FROM support_messages m
     JOIN support_tickets t ON t.id = m.ticket_id
     WHERE m.id = ? AND t.tenant_id = ?
     LIMIT 1",
    [$messageId, $tenantId]
);
if (!$message || empty($message['attachment_url'])) {
    Response::notFound('Attachment');
}

$path = SupportAttachment::resolve($message['attachment_url']);
if ($path === null) {
    Response::notFound('File');
}

$mime = SupportAttachment::mimeFor($path);
$name = $message['attachment_name'] ?: basename($path);

header('Content-Type: ' . $mime);
header('Content-Length: ' . filesize($path));
header('Content-Disposition: inline; filename="' . rawurlencode($name) . '"');
header('Cache-Control: private, max-age=300');
readfile($path);
