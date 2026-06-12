<?php
/**
 * Generate (or regenerate with force=1) the QR payload for a branch that
 * doesn't have one yet, so a QR+GPS poster can be shown for it.
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
Validator::required($branchId, 'branch_id');

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) {
    Response::notFound('Branch');
}

$force = isset($input['force']) && (int) $input['force'] === 1;
$code = BranchModel::ensureQrCode($branchId, $tenantId, $force);

AuditLogModel::log($tenantId, $auth['admin_id'], 'branch.generate_qr', 'branch', $branchId);

Response::success(['qr_code' => $code]);
