<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$input = $auth['input'];
$leaveId = (int) ($input['leave_id'] ?? 0);
$reason = $input['reason'] ?? null;
Validator::required($leaveId, 'leave_id');

LeaveModel::reject($leaveId, $tenantId, $auth['user_id'], $reason);

AuditLogModel::log($tenantId, $auth['user_id'], 'leave.reject', 'leave', $leaveId);

Response::success(['message' => 'Leave rejected']);
