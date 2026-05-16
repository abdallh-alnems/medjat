<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();

$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    $input = [];
}

$token = $input['token'] ?? null;
if (!$token) {
    Response::fail('Token is required', 400);
}

$auth = Auth::authenticateUser(db());

$tenantId = TenantMiddleware::requireTenant();

$user = UserModel::findById($auth['user_id'], $tenantId);
if (!$user) {
    Response::fail('User not found in this company', 404);
}

$employee = EmployeeModel::findByUserId($auth['user_id'], $tenantId);

Response::success([
    'user' => [
        'id' => (int) $user['id'],
        'name' => $user['name'],
        'phone' => $user['phone'],
        'email' => $user['email'],
        'role' => $user['role'],
        'branch_id' => $user['branch_id'] ? (int) $user['branch_id'] : null,
        'tenant_id' => (int) $user['tenant_id'],
    ],
    'employee' => $employee ? [
        'id' => (int) $employee['id'],
        'job_title' => $employee['job_title'],
        'base_salary' => (float) $employee['base_salary'],
        'hire_date' => $employee['hire_date'],
        'status' => $employee['status'],
    ] : null,
]);
