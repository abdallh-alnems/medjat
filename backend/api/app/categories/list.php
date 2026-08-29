<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

// Category names are a dashboard filter dimension, so allow any staff member
// who can see the dashboard to read the list (not just employee managers).
PermissionMiddleware::checkAny($auth, [
    'manage_employees',
    'view_reports',
    'manage_company_settings',
]);

$categories = EmployeeCategoryModel::listByTenant($tenantId);

Response::success(['categories' => $categories]);
