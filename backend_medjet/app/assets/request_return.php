<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = (int) $auth['tenant_id'];
$employeeId = (int) $auth['employee']['id'];

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

$note = isset($input['return_note']) ? trim((string) $input['return_note']) : null;
if ($note === '') {
    $note = null;
}

$asset = AssetModel::findById($id, $tenantId);
// Must exist, belong to this employee, and currently be assigned.
if (!$asset || (int) $asset['employee_id'] !== $employeeId) {
    Response::notFound('Custody');
}
if ($asset['status'] !== 'assigned') {
    Response::fail('This custody item cannot be returned in its current state', 409, 'asset_not_returnable');
}

AssetModel::requestReturn($id, $tenantId, $note, null);

AuditLogModel::log($tenantId, null, 'asset.return_request', 'asset', $id);

$employeeName = (string) ($auth['employee']['name'] ?? '');
$assetName = (string) ($asset['name'] ?? '');
NotificationService::notifyManagers(
    $tenantId,
    'approval',
    'Custody Return Requested',
    'طلب إرجاع عهدة',
    "{$employeeName} requested to return: {$assetName}.",
    "طلب {$employeeName} إرجاع العهدة: {$assetName}.",
    ['type' => 'asset', 'asset_id' => $id, 'action' => 'return_request', 'employee_id' => $employeeId]
);

Response::success(['message' => 'Return requested']);
