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

$data = [];

if (array_key_exists('name', $input)) {
    $name = trim((string)$input['name']);
    if ($name === '' || mb_strlen($name) > 100) {
        Response::fail('name must be 1-100 characters', 422);
    }
    $data['name'] = $name;
}

if (array_key_exists('delimiter', $input)) {
    $allowedDelimiters = [',', ';', '|', "\t"];
    $delimiter = (string)$input['delimiter'];
    if (!in_array($delimiter, $allowedDelimiters, true)) {
        Response::fail('delimiter must be one of: , ; | TAB', 422);
    }
    $data['delimiter'] = $delimiter;
}

if (array_key_exists('columns', $input)) {
    $columns = $input['columns'];
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
    $data['columns'] = $columns;
}

if (array_key_exists('decimal_places', $input)) {
    $decimalPlaces = (int)$input['decimal_places'];
    if ($decimalPlaces < 0 || $decimalPlaces > 4) {
        Response::fail('decimal_places must be 0-4', 422);
    }
    $data['decimal_places'] = $decimalPlaces;
}

if (array_key_exists('include_bom', $input)) {
    $data['include_bom'] = (int)$input['include_bom'];
}

if (array_key_exists('include_header_row', $input)) {
    $data['include_header_row'] = (int)$input['include_header_row'];
}

PayrollExportTemplateModel::update($id, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'export_template.update', 'payroll_export_template', $id, $data);

Response::success([
    'message' => 'Template updated',
]);
