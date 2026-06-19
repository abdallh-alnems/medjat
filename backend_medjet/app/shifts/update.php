<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$id = (int) ($input['id'] ?? $_GET['id'] ?? 0);
if (!$id) Response::fail('Shift ID required', 422, 'shift_id_required');

$shift = ShiftModel::findById($id, $tenantId);
if (!$shift) Response::notFound('Shift');

ShiftModel::update($id, $tenantId, $input);

AuditLogModel::log($tenantId, $auth['admin_id'], 'shift.update', 'shift', $id);

Response::success(['message' => 'Updated']);
