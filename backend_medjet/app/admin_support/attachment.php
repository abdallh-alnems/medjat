<?php
// Serve one support attachment to the support desk.
//
// Attachments are stored outside any publicly-served directory and reached only
// through here, so a leaked URL is worthless without a live admin token — a
// client's screenshot can contain payroll figures or staff faces.
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
AdminAuth::require('admin');

$messageId = (int) ($_GET['message_id'] ?? 0);
Validator::required($messageId, 'message_id');

$message = Database::fetchOne(
    "SELECT id, ticket_id, attachment_url, attachment_name FROM support_messages WHERE id = ? LIMIT 1",
    [$messageId]
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
