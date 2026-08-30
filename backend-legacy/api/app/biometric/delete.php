<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'DELETE') {
    $input = json_decode(file_get_contents('php://input'), true) ?: [];
} elseif ($method === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true) ?: [];
} else {
    Response::fail('Method not allowed', 405, 'method_not_allowed');
}

$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'biometric_delete');

$employeeId = (int) ($input['employee_id'] ?? 0);
$type = $input['type'] ?? 'both';
Validator::required($employeeId, 'employee_id');
Validator::enum($type, ['face', 'fingerprint', 'both'], 'type');

$emp = EmployeeModel::findById($employeeId, $tenantId);
if (!$emp) Response::fail('Employee not found', 404, 'employee_not_found');

if ($type === 'face' || $type === 'both') {
    BiometricModel::deleteFace($employeeId, $tenantId);
}
if ($type === 'fingerprint' || $type === 'both') {
    BiometricModel::deleteFingerprint($employeeId, $tenantId);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'biometric.delete', 'employee', $employeeId);

Response::success(['employee_id' => $employeeId, 'deleted_type' => $type]);
