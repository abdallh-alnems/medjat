<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'add_managers');

$input = $auth['input'];
$adminId = (int) ($input['admin_id'] ?? 0);
$name = $input['name'] ?? '';
$permissions = $input['permissions'] ?? [];
$branchId = ($input['branch_id'] ?? null) ? (int) $input['branch_id'] : null;

Validator::required($adminId, 'admin_id');

$id = RoleModel::create($tenantId, $adminId, $name, $permissions, $branchId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'role.create', 'admin', $adminId, ['permissions' => $permissions]);

Response::success(['id' => $id, 'message' => 'Role created']);
