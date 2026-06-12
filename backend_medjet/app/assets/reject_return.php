<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_assets');

$input = $auth['input'];
$id = (int) ($input['id'] ?? $_GET['id'] ?? 0);
$reason = $input['rejection_reason'] ?? null;
Validator::required($id, 'id');

$asset = AssetModel::findById($id, $tenantId);
if (!$asset) {
    Response::notFound('Custody');
}
if ($asset['status'] !== 'return_requested') {
    Response::fail('Only a pending return request can be rejected', 409);
}

AssetModel::rejectReturn($id, $tenantId, $auth['admin_id'], $reason);

AuditLogModel::log($tenantId, $auth['admin_id'], 'asset.return_reject', 'asset', $id);

$assetName = (string) ($asset['name'] ?? '');
NotificationService::notifyEmployee(
    $tenantId,
    (int) $asset['employee_id'],
    'approval',
    'Custody Return Rejected',
    'تم رفض إرجاع العهدة',
    "Your request to return \"{$assetName}\" was rejected."
        . ($reason ? " Reason: {$reason}" : ''),
    "تم رفض طلب إرجاع العهدة: {$assetName}."
        . ($reason ? " السبب: {$reason}" : ''),
    ['type' => 'asset', 'asset_id' => $id, 'action' => 'return_reject']
);

Response::success(['message' => 'Return request rejected']);
