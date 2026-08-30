<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$input = $auth['input'];
$leaveId = (int) ($input['leave_id'] ?? $_GET['id'] ?? 0);
$rejectionReason = $input['rejection_reason'] ?? $input['reason'] ?? null;
Validator::required($leaveId, 'leave_id');

// A manager rejecting directly from the leave screen overrides any pending
// multi-level approval chain: cancel the open request, then reject.
if (ApprovalEngine::isPending($tenantId, 'leave', $leaveId)) {
    ApprovalEngine::cancelFor($tenantId, 'leave', $leaveId);
}

LeaveModel::reject($leaveId, $tenantId, $auth['admin_id'], $rejectionReason);

AuditLogModel::log($tenantId, $auth['admin_id'], 'leave.reject', 'leave', $leaveId);

try {
    $leave = Database::fetchOne(
        "SELECT employee_id FROM leaves WHERE id = ? AND tenant_id = ?",
        [$leaveId, $tenantId]
    );
    if ($leave) {
        $bodyAr = $rejectionReason !== null && trim((string) $rejectionReason) !== ''
            ? 'تم رفض طلب الإجازة الخاص بك. السبب: ' . trim((string) $rejectionReason)
            : 'تم رفض طلب الإجازة الخاص بك.';

        Database::execute(
            "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
             VALUES (?, ?, 'leave', 'Leave Rejected', 'تم رفض الإجازة', 'Your leave request has been rejected.', ?, ?, 'push,in_app', NOW())",
            [$tenantId, $leave['employee_id'], $bodyAr, json_encode(['leave_id' => $leaveId, 'action' => 'reject'])]
        );

        NotificationService::sendToEmployee(
            (int) $leave['employee_id'],
            'تم رفض الإجازة',
            $bodyAr,
            ['leave_id' => (string) $leaveId, 'action' => 'reject', 'type' => 'leave']
        );
    }
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Leave rejected']);
