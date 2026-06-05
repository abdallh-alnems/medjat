<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$input = $auth['input'];
$leaveId = (int) ($input['leave_id'] ?? 0);
Validator::required($leaveId, 'leave_id');

if (ApprovalEngine::isPending($tenantId, 'leave', $leaveId)) {
    Response::fail('This leave is managed by a multi-level approval chain. Use approvals/decide.', 409);
}

LeaveModel::approve($leaveId, $tenantId, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'leave.approve', 'leave', $leaveId);

try {
    $leave = Database::fetchOne(
        "SELECT employee_id FROM leaves WHERE id = ? AND tenant_id = ?",
        [$leaveId, $tenantId]
    );
    if ($leave) {
        Database::execute(
            "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
             VALUES (?, ?, 'leave', 'Leave Approved', 'تم قبول الإجازة', 'Your leave request has been approved.', 'تم قبول طلب الإجازة الخاص بك.', ?, 'in_app', NOW())",
            [$tenantId, $leave['employee_id'], json_encode(['leave_id' => $leaveId, 'action' => 'approve'])]
        );
    }
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Leave approved']);
