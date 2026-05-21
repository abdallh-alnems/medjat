<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_assets');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$type = $input['type'] ?? 'equipment';
$name = trim((string) ($input['name'] ?? ''));
$description = $input['description'] ?? null;
$value = isset($input['value']) && $input['value'] !== '' ? (float) $input['value'] : null;
$currency = $input['currency'] ?? 'SAR';
$serialNo = $input['serial_no'] ?? null;
$quantity = (int) ($input['quantity'] ?? 1);
$assignedAt = $input['assigned_at'] ?? date('Y-m-d');
$assignPhotoUrl = $input['assign_photo_url'] ?? null;
$notes = $input['notes'] ?? null;

Validator::required($employeeId, 'employee_id');
Validator::required($name, 'name');
$type = Validator::enum($type, AssetModel::TYPES, 'type');
Validator::date($assignedAt, 'assigned_at');
if ($value !== null) {
    Validator::numeric($value, 'value', 0);
}
if ($quantity < 1) {
    $quantity = 1;
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$id = AssetModel::create(
    $tenantId, $employeeId, $type, $name, $description, $value, $currency,
    $serialNo, $quantity, $assignedAt, $assignPhotoUrl, $notes, $auth['admin_id']
);

AuditLogModel::log($tenantId, $auth['admin_id'], 'asset.create', 'asset', $id, ['name' => $name, 'type' => $type]);

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'general', 'Custody Assigned', 'تم تسليمك عهدة', 'A custody item has been assigned to you.', 'تم تسليمك عهدة جديدة.', ?, 'in_app', NOW())",
        [$tenantId, $employeeId, json_encode(['asset_id' => $id, 'action' => 'assign'])]
    );
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['id' => $id, 'message' => 'Custody assigned']);
