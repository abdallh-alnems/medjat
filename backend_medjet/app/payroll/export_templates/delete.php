<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];

$id = (int)($input['id'] ?? 0);
Validator::required($id, 'id');

$existing = PayrollExportTemplateModel::findById($id, $tenantId);
if ($existing === null) {
    Response::fail('Template not found', 422);
}

PayrollExportTemplateModel::delete($id, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'export_template.delete', 'payroll_export_template', $id, [
    'name' => $existing['name'],
]);

Response::success([
    'message' => 'Template deleted',
]);
