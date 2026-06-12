<?php
/**
 * One bulk batch with its per-employee rows (id, employee name, amount, reason).
 * Input: id (GET query or POST body).
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$id = (int) ($auth['input']['id'] ?? $_GET['id'] ?? 0);
if ($id <= 0) {
    Response::error('id is required', 422);
}

$batch = BulkAdjustmentModel::findById($id, $tenantId);
if (!$batch) {
    Response::notFound('Bulk adjustment');
}

$members = BulkAdjustmentModel::getMembers($id, $batch['kind'], $tenantId);

Response::success([
    'batch' => $batch,
    'members' => $members,
]);
