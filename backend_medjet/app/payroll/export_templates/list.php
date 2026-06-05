<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$rows = PayrollExportTemplateModel::listAll($tenantId);

foreach ($rows as &$row) {
    $row['columns'] = json_decode($row['columns'], true) ?: [];
}
unset($row);

Response::success([
    'templates' => $rows,
]);
