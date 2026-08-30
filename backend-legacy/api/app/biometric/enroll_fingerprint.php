<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'biometric_enroll');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$emp = EmployeeModel::findById($employeeId, $tenantId);
if (!$emp) Response::fail('Employee not found', 404, 'employee_not_found');
PermissionMiddleware::checkBranchAccess($auth, (int) $emp['branch_id']);

$templateBase64 = $input['template_base64'] ?? null;
Validator::required($templateBase64, 'template_base64');

BiometricModel::enrollFingerprint($employeeId, $tenantId, base64_decode($templateBase64));

AuditLogModel::log($tenantId, $auth['admin_id'], 'biometric.enroll_fingerprint', 'employee', $employeeId);

Response::success([
    'employee_id' => $employeeId,
    'status' => 'fingerprint_enrolled',
], 201);
