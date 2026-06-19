<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$name = trim($input['name'] ?? '');
$startTime = $input['start_time'] ?? '';
$endTime = $input['end_time'] ?? '';
$branchId = $input['branch_id'] ?? null;

if ($name === '' || $startTime === '' || $endTime === '') {
    Response::fail('Name, start time, and end time are required', 422, 'name_start_time_end_time');
}

$id = ShiftModel::create([
    'tenant_id' => $tenantId,
    'branch_id' => $branchId ? (int) $branchId : null,
    'name' => $name,
    'start_time' => $startTime,
    'end_time' => $endTime,
]);

AuditLogModel::log($tenantId, $auth['admin_id'], 'shift.create', 'shift', $id);

Response::success(['id' => $id, 'message' => 'Shift created'], 201);
