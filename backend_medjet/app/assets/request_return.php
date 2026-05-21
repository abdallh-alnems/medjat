<?php
// Employee-facing: the employee who holds a custody item requests its return.
// The admin then confirms or rejects via approve_return.php / reject_return.php.
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$employee = EmployeeModel::findByAdminId($auth['admin_id'], $tenantId);
if (!$employee) {
    Response::fail('Employee profile not found', 404);
}

$input = $auth['input'];
$id = (int) ($input['id'] ?? $_GET['id'] ?? 0);
$returnNote = $input['return_note'] ?? null;
$returnPhotoUrl = $input['return_photo_url'] ?? null;
Validator::required($id, 'id');

$asset = AssetModel::findById($id, $tenantId);
if (!$asset || (int) $asset['employee_id'] !== (int) $employee['id']) {
    Response::notFound('Custody');
}
if ($asset['status'] !== 'assigned') {
    Response::fail('Return can only be requested for an assigned custody item', 409);
}

AssetModel::requestReturn($id, $tenantId, $returnNote, $returnPhotoUrl);

AuditLogModel::log($tenantId, $auth['admin_id'], 'asset.return_request', 'asset', $id);

Response::success(['message' => 'Return requested']);
