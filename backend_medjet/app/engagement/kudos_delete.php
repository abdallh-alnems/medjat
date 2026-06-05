<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_engagement');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

$kudos = KudosModel::findById($id, $tenantId);
if (!$kudos) {
    Response::notFound('Kudos');
}

$deleted = KudosModel::delete($id, $tenantId);
if (!$deleted) {
    Response::fail('Failed to delete kudos', 500);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'kudos.delete', 'kudos', $id, ['recipient' => $kudos['recipient_employee_id']]);

Response::success(['message' => 'Kudos deleted']);
