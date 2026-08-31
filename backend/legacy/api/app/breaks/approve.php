<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

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

// A permission whose window already passed can't be approved after the fact.
if (strtotime($row['date'] . ' ' . $row['end_time']) < time()) {
    BreakRequestModel::expirePastPending($tenantId, (int) $row['employee_id']);
    Response::fail('انتهى وقت الإذن، لا يمكن الموافقة عليه', 409, 'break_window_passed');
}

// Hourly salary deduction can apply to any request. If the manager passes the
// flag at approval it wins; otherwise the value chosen at creation is kept.
$deductFromSalary = array_key_exists('deduct_from_salary', $auth['input'])
    ? filter_var($auth['input']['deduct_from_salary'], FILTER_VALIDATE_BOOLEAN)
    : (bool) $row['deduct_from_salary'];

BreakRequestModel::approve($id, $tenantId, $auth['admin_id'], $note, $deductFromSalary);
AuditLogModel::log($tenantId, $auth['admin_id'], 'break.approve', 'break', $id);

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'break', 'Break Approved', 'تم قبول الإذن', 'Your break request has been approved.', 'تمت الموافقة على طلب الإذن الخاص بك.', ?, 'push,in_app', NOW())",
        [$tenantId, $row['employee_id'], json_encode(['break_id' => $id, 'action' => 'approve'])]
    );

    NotificationService::sendToEmployee(
        (int) $row['employee_id'],
        'تم قبول الإذن',
        'تمت الموافقة على طلب الإذن الخاص بك.',
        ['break_id' => (string) $id, 'action' => 'approve', 'type' => 'break_approved']
    );
} catch (Exception $e) { error_log('Notification insert error: ' . $e->getMessage()); }

Response::success(['message' => 'Break approved']);
