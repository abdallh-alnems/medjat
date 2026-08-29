<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

LeaveCarryoverPolicyModel::delete($tenantId, $id);

AuditLogModel::log($tenantId, $auth['admin_id'], 'leave.carryover_policy.delete', 'leave_carryover_policy', $id, null);

Response::success(['message' => 'Carryover policy removed']);
