<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_assets');

$input = $auth['input'];
$id = (int) ($input['id'] ?? $_GET['id'] ?? 0);
Validator::required($id, 'id');

$asset = AssetModel::findById($id, $tenantId);
if (!$asset) {
    Response::notFound('Custody');
}
if (!in_array($asset['status'], ['assigned', 'return_requested'], true)) {
    Response::fail('This custody item is already returned', 409);
}

AssetModel::approveReturn($id, $tenantId, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'asset.return_approve', 'asset', $id);

$assetName = (string) ($asset['name'] ?? '');
NotificationService::notifyEmployee(
    $tenantId,
    (int) $asset['employee_id'],
    'approval',
    'Custody Return Confirmed',
    'تم تأكيد إرجاع العهدة',
    "Your return of \"{$assetName}\" has been confirmed.",
    "تم تأكيد إرجاع العهدة: {$assetName}.",
    ['type' => 'asset', 'asset_id' => $id, 'action' => 'return_approve']
);

Response::success(['message' => 'Custody return confirmed']);
