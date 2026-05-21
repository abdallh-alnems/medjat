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

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'general', 'Custody Return Confirmed', 'تم تأكيد إرجاع العهدة', 'Your custody return has been confirmed.', 'تم تأكيد إرجاع العهدة الخاصة بك.', ?, 'in_app', NOW())",
        [$tenantId, (int) $asset['employee_id'], json_encode(['asset_id' => $id, 'action' => 'return_approve'])]
    );
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Custody return confirmed']);
