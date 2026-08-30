<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];

$input = $auth['input'];
$leaveId = (int) ($input['leave_id'] ?? $_GET['id'] ?? 0);
Validator::required($leaveId, 'leave_id');

$employee = $auth['employee'];

$leave = LeaveModel::findOwnedPending($leaveId, (int) $employee['id'], $tenantId);
if (!$leave) {
    Response::fail('لا يمكن إلغاء هذا الطلب', 409, 'leave_not_cancellable');
}

// Drop any open multi-level approval request, then remove the leave.
ApprovalEngine::cancelFor($tenantId, 'leave', $leaveId);
LeaveModel::cancelOwn($leaveId, (int) $employee['id'], $tenantId);

Response::success(['message' => 'Leave request cancelled']);
