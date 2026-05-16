<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
Validator::required($branchId, 'branch_id');

$employeeCount = BranchModel::getEmployeeCount($branchId, $tenantId);
if ($employeeCount > 0) {
    Response::fail('Cannot delete branch with active employees', 400);
}

BranchModel::delete($branchId, $tenantId);

AuditLogModel::log($tenantId, $auth['user_id'], 'branch.delete', 'branch', $branchId);

Response::success(['message' => 'Branch deleted']);
