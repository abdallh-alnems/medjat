<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'add_managers');

$input = $auth['input'];
$userId = (int) ($input['user_id'] ?? 0);
$name = $input['name'] ?? '';
$permissions = $input['permissions'] ?? [];
$branchId = ($input['branch_id'] ?? null) ? (int) $input['branch_id'] : null;

Validator::required($userId, 'user_id');

$id = RoleModel::create($tenantId, $userId, $name, $permissions, $branchId);

AuditLogModel::log($tenantId, $auth['user_id'], 'role.create', 'user', $userId, ['permissions' => $permissions]);

Response::success(['id' => $id, 'message' => 'Role created']);
