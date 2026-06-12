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

AssetModel::delete($id, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'asset.delete', 'asset', $id, ['name' => $asset['name'] ?? '']);

Response::success(['message' => 'Custody deleted']);
