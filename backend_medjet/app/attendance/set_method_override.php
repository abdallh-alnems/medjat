<?php
/**
 * Set or clear an attendance-method override for a category or a single
 * employee. (Branch overrides keep their own endpoint because they also carry
 * gps_radius / allow_offline.)
 *
 * Input: scope_type (category|employee), scope_id,
 *        attendance_methods (array of methods, or null to inherit).
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$scopeType = $input['scope_type'] ?? '';
$scopeId = (int) ($input['scope_id'] ?? 0);

if (!in_array($scopeType, ['category', 'employee'], true)) {
    Response::fail('scope_type must be category or employee', 422);
}
Validator::required($scopeId, 'scope_id');

$allowedMethods = ['qr_gps', 'gps_only', 'manual'];
$methods = $input['attendance_methods'] ?? null;

if ($methods !== null) {
    if (!is_array($methods) || empty($methods)) {
        Response::fail('attendance_methods must be a non-empty array, or null to inherit', 422);
    }
    foreach ($methods as $m) {
        if (!in_array($m, $allowedMethods, true)) {
            Response::fail('Invalid attendance method: ' . $m, 422);
        }
    }
    $methods = array_values(array_unique($methods));
}

if ($scopeType === 'category') {
    $category = EmployeeCategoryModel::findById($scopeId, $tenantId);
    if (!$category) {
        Response::notFound('Category');
    }
    EmployeeCategoryModel::setAttendanceMethods($scopeId, $tenantId, $methods);
} else {
    $employee = EmployeeModel::findById($scopeId, $tenantId);
    if (!$employee) {
        Response::notFound('Employee');
    }
    EmployeeModel::setAttendanceMethods($scopeId, $tenantId, $methods);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'attendance.set_method_override', $scopeType, $scopeId, ['attendance_methods' => $methods]);

Response::success(['message' => 'Attendance method override updated']);
