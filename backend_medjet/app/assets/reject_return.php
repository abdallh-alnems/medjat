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

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'general', 'Custody Return Rejected', 'تم رفض إرجاع العهدة', 'Your custody return request was rejected.', 'تم رفض طلب إرجاع العهدة الخاص بك.', ?, 'in_app', NOW())",
        [$tenantId, (int) $asset['employee_id'], json_encode(['asset_id' => $id, 'action' => 'return_reject'])]
    );
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Return request rejected']);
