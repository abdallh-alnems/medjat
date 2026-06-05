<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];

$name = trim((string)($input['name'] ?? ''));
Validator::required($name, 'name');
if ($name === '' || mb_strlen($name) > 100) {
    Response::fail('name must be 1-100 characters', 422);
}

$allowedDelimiters = [',', ';', '|', "\t"];
$delimiter = (string)($input['delimiter'] ?? ',');
if (!in_array($delimiter, $allowedDelimiters, true)) {
    Response::fail('delimiter must be one of: , ; | TAB', 422);
}

$columns = $input['columns'] ?? [];
if (!is_array($columns) || count($columns) === 0) {
    Response::fail('columns must be a non-empty array', 422);
}
foreach ($columns as $i => $col) {
    if (!is_array($col) || !isset($col['label']) || !isset($col['field'])) {
        Response::fail("columns[$i] must have label and field", 422);
    }
    if (!PayrollFieldCatalog::has($col['field'])) {
        Response::fail("unknown field: {$col['field']}", 422);
    }
}

$decimalPlaces = (int)($input['decimal_places'] ?? 2);
if ($decimalPlaces < 0 || $decimalPlaces > 4) {
    Response::fail('decimal_places must be 0-4', 422);
}

$id = PayrollExportTemplateModel::create($tenantId, [
    'name'              => $name,
    'delimiter'         => $delimiter,
    'include_bom'       => (int)($input['include_bom'] ?? 1),
    'include_header_row' => (int)($input['include_header_row'] ?? 1),
    'decimal_places'    => $decimalPlaces,
    'columns'           => $columns,
], (int)$auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'export_template.create', 'payroll_export_template', $id, [
    'name' => $name,
]);

Response::success([
    'id' => $id,
    'message' => 'Template created',
]);
