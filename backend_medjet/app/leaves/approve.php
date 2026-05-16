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

LeaveModel::approve($leaveId, $tenantId, $auth['user_id']);

AuditLogModel::log($tenantId, $auth['user_id'], 'leave.approve', 'leave', $leaveId);

Response::success(['message' => 'Leave approved']);
