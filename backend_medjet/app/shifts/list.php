<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

// Reading the shift list is a shared lookup: it's a dashboard filter dimension,
// the shift dropdown when adding/editing an employee, and the weekly schedule's
// source. Gating it on manage_company_settings alone left HR, branch managers
// and viewers with an empty (silently 403'd) list. Managing shifts
// (create/update/delete) stays restricted in those endpoints.
PermissionMiddleware::checkAny($auth, [
    'manage_company_settings',
    'manage_employees',
    'manage_attendance',
    'manage_schedule',
    'view_reports',
]);

$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$shifts = ShiftModel::getByTenant($tenantId, $branchId);
Response::success(['items' => $shifts]);
