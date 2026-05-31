<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$warningId = (int) ($input['id'] ?? 0);

Validator::required($warningId, 'id');

$warning = WarningModel::findById($warningId, $tenantId);
if (!$warning) {
    Response::notFound('Warning');
}

// System-generated alerts (device changes, automated flags) are part of the
// security/audit trail and must not be removed manually.
if (in_array($warning['type'], ['device_change', 'system'], true)) {
    Response::forbidden('System-generated warnings cannot be deleted');
}

WarningModel::delete($warningId, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'warning.delete', 'employee', (int) $warning['employee_id'], ['warning_id' => $warningId, 'type' => $warning['type']]);

Response::success(['message' => 'Warning deleted']);
