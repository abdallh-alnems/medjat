<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$input = $auth['input'];
$leaveId = (int) ($input['leave_id'] ?? $_GET['id'] ?? 0);
Validator::required($leaveId, 'leave_id');

// A manager approving directly from the leave screen overrides any pending
// multi-level approval chain: cancel the open request, then approve.
if (ApprovalEngine::isPending($tenantId, 'leave', $leaveId)) {
    ApprovalEngine::cancelFor($tenantId, 'leave', $leaveId);
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
             VALUES (?, ?, 'leave', 'Leave Approved', 'تم قبول الإجازة', 'Your leave request has been approved.', 'تم قبول طلب الإجازة الخاص بك.', ?, 'push,in_app', NOW())",
            [$tenantId, $leave['employee_id'], json_encode(['leave_id' => $leaveId, 'action' => 'approve'])]
        );

        NotificationService::sendToEmployee(
            (int) $leave['employee_id'],
            'تم قبول الإجازة',
            'تم قبول طلب الإجازة الخاص بك.',
            ['leave_id' => (string) $leaveId, 'action' => 'approve', 'type' => 'leave']
        );
    }
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Leave approved']);
