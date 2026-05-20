<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'documents_view_reports');

$branchId = isset($_GET['branch_id']) ? (int) $_GET['branch_id'] : null;
$employeeId = isset($_GET['employee_id']) ? (int) $_GET['employee_id'] : null;

if ($employeeId) {
    $missing = DocumentModel::getMissingDocuments($tenantId, $employeeId);
} else {
    $missing = DocumentModel::getMissingByBranch($tenantId, $branchId);
}

Response::success(['missing_documents' => $missing]);
