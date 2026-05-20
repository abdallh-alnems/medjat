<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$id = (int) ($_GET['id'] ?? $auth['input']['id'] ?? 0);
if (!$id) Response::fail('Shift ID required', 422);

$shift = ShiftModel::findById($id, $tenantId);
if (!$shift) Response::notFound('Shift');

ShiftModel::delete($id, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'shift.delete', 'shift', $id);

Response::success(['message' => 'Deleted']);
