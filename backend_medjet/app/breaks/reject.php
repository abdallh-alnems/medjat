<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_leaves');

$id   = (int) ($auth['input']['break_id'] ?? 0);
$note = $auth['input']['rejection_reason'] ?? $auth['input']['note'] ?? null;
Validator::required($id, 'break_id');

$row = BreakRequestModel::find($id, $tenantId);
if (!$row) Response::fail('الطلب غير موجود', 404, 'not_found');
if ($row['status'] !== 'pending') Response::fail('الطلب ليس قيد الانتظار', 409, 'not_pending');

BreakRequestModel::reject($id, $tenantId, $auth['admin_id'], $note);
AuditLogModel::log($tenantId, $auth['admin_id'], 'break.reject', 'break', $id);

try {
    $bodyAr = ($note !== null && trim((string) $note) !== '')
        ? 'تم رفض طلب الإذن الخاص بك: ' . trim((string) $note)
        : 'تم رفض طلب الإذن الخاص بك.';
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'break', 'Break Rejected', 'تم رفض الإذن', 'Your break request has been rejected.', ?, ?, 'push,in_app', NOW())",
        [$tenantId, $row['employee_id'], $bodyAr, json_encode(['break_id' => $id, 'action' => 'reject'])]
    );

    NotificationService::sendToEmployee(
        (int) $row['employee_id'],
        'تم رفض الإذن',
        $bodyAr,
        ['break_id' => (string) $id, 'action' => 'reject', 'type' => 'break_rejected']
    );
} catch (Exception $e) { error_log('Notification insert error: ' . $e->getMessage()); }

Response::success(['message' => 'Break rejected']);
