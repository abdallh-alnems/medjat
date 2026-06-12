<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_assets');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

$asset = AssetModel::findById($id, $tenantId);
if (!$asset) {
    Response::notFound('Custody');
}
// Returned items are historical records and must not be edited.
if ($asset['status'] === 'returned') {
    Response::fail('A returned custody item cannot be edited', 409, 'asset_returned_locked');
}

$type = $input['type'] ?? $asset['type'];
$name = trim((string) ($input['name'] ?? $asset['name']));
$description = $input['description'] ?? $asset['description'];
$value = array_key_exists('value', $input)
    ? ($input['value'] !== '' && $input['value'] !== null ? (float) $input['value'] : null)
    : ($asset['value'] !== null ? (float) $asset['value'] : null);
$currency = $input['currency'] ?? $asset['currency'];
$serialNo = $input['serial_no'] ?? $asset['serial_no'];
$quantity = (int) ($input['quantity'] ?? $asset['quantity']);
$assignedAt = $input['assigned_at'] ?? $asset['assigned_at'];
$notes = $input['notes'] ?? $asset['notes'];

Validator::required($name, 'name');
$type = Validator::enum($type, AssetModel::TYPES, 'type');
Validator::date($assignedAt, 'assigned_at');
if ($value !== null) {
    Validator::numeric($value, 'value', 0);
}
if ($quantity < 1) {
    $quantity = 1;
}

AssetModel::update(
    $id, $tenantId, $type, $name, $description, $value, $currency,
    $serialNo, $quantity, $assignedAt, $notes
);

AuditLogModel::log($tenantId, $auth['admin_id'], 'asset.update', 'asset', $id, ['name' => $name]);

Response::success(['message' => 'Custody updated']);
