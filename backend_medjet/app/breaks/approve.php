<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_leaves');

$id   = (int) ($auth['input']['break_id'] ?? 0);
$note = $auth['input']['note'] ?? null;
Validator::required($id, 'break_id');

$row = BreakRequestModel::find($id, $tenantId);
if (!$row) Response::fail('الطلب غير موجود', 404, 'not_found');
if ($row['status'] !== 'pending') Response::fail('الطلب ليس قيد الانتظار', 409, 'not_pending');

// Hourly salary deduction only applies to early-leave permissions; the manager
// decides at approval time whether the early-leave window is deducted.
$deductFromSalary = ($row['type'] === 'early_leave')
    && filter_var($auth['input']['deduct_from_salary'] ?? false, FILTER_VALIDATE_BOOLEAN);

BreakRequestModel::approve($id, $tenantId, $auth['admin_id'], $note, $deductFromSalary);
AuditLogModel::log($tenantId, $auth['admin_id'], 'break.approve', 'break', $id);

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'break', 'Break Approved', 'تم قبول الإذن', 'Your break request has been approved.', 'تمت الموافقة على طلب الإذن الخاص بك.', ?, 'in_app', NOW())",
        [$tenantId, $row['employee_id'], json_encode(['break_id' => $id, 'action' => 'approve'])]
    );
} catch (Exception $e) { error_log('Notification insert error: ' . $e->getMessage()); }

Response::success(['message' => 'Break approved']);
