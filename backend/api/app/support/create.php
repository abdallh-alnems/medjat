<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_support');

$input = $auth['input'];
$subject = trim($input['subject'] ?? '');
$category = $input['category'] ?? 'other';
$priority = $input['priority'] ?? 'normal';
$body = trim($input['body'] ?? '');

Validator::required($subject, 'subject');
Validator::maxLength($subject, 255, 'subject');
Validator::required($body, 'body');
Validator::maxLength($body, 5000, 'body');
$category = Validator::enum($category, SupportModel::CATEGORIES, 'category');
$priority = Validator::enum($priority, SupportModel::PRIORITIES, 'priority');

$ticketId = SupportModel::createTicket(
    $tenantId,
    $auth['admin_id'],
    $subject,
    $category,
    $priority,
    $body
);

AuditLogModel::log($tenantId, $auth['admin_id'], 'support.ticket.create', 'support_ticket', $ticketId, [
    'subject' => $subject,
    'category' => $category,
]);

try {
    EmailService::send(
        getenv('SUPPORT_EMAIL') ?: 'support@medjatapp.com',
        'New Support Ticket #' . $ticketId,
        "New ticket from tenant #{$tenantId}: {$subject}\n\n{$body}"
    );
} catch (Throwable $e) {
    error_log('Support email error: ' . $e->getMessage());
}

try {
    NotificationService::sendToSupportTeam(
        'New Support Ticket',
        $subject,
        ['type' => 'support', 'ticket_id' => $ticketId]
    );
} catch (Throwable $e) {
    error_log('Support push error: ' . $e->getMessage());
}

Response::success(['ticket_id' => $ticketId]);
