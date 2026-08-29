<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$documents = DocumentModel::getByEmployee($employeeId, $tenantId);
$required = DocumentModel::getRequiredForEmployee($employeeId, $tenantId);

Response::success([
    'documents' => $documents,
    'required_documents' => $required,
]);
