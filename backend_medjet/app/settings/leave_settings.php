<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $tenant = TenantModel::findById($tenantId);
    if (!$tenant) {
        Response::notFound('Tenant');
    }

    Response::success([
        'default_annual_leave_days' => (int) ($tenant['default_annual_leave_days'] ?? 21),
        'leave_carryover_max_days' => $tenant['leave_carryover_max_days'] !== null
            ? (int) $tenant['leave_carryover_max_days']
            : null,
    ]);
}

if ($method === 'POST' || $method === 'PUT') {
    PermissionMiddleware::check($auth, 'manage_company_settings');

    $input = $auth['input'];
    $updateData = [];

    if (isset($input['default_annual_leave_days'])) {
        $days = (int) $input['default_annual_leave_days'];
        if ($days < 0 || $days > 366) {
            Response::fail('default_annual_leave_days must be between 0 and 366', 422);
        }
        $updateData['default_annual_leave_days'] = $days;
    }

    if (array_key_exists('leave_carryover_max_days', $input)) {
        $val = $input['leave_carryover_max_days'];
        if ($val === null || $val === '') {
            $updateData['leave_carryover_max_days'] = null;
        } else {
            $max = (int) $val;
            if ($max < 0 || $max > 366) {
                Response::fail('leave_carryover_max_days must be between 0 and 366, or null', 422);
            }
            $updateData['leave_carryover_max_days'] = $max;
        }
    }

    if (empty($updateData) && !array_key_exists('leave_carryover_max_days', $input)) {
        Response::fail('No leave settings provided', 422);
    }

    TenantModel::update($tenantId, $updateData);

    AuditLogModel::log($tenantId, $auth['admin_id'], 'tenant.update_leave_settings', 'tenant', $tenantId, $updateData);

    Response::success(['message' => 'Leave settings updated']);
}

Response::fail('Method not allowed', 405);
