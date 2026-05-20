<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$method = $_SERVER['REQUEST_METHOD'];

$allowedMethods = ['qr_gps', 'gps_only', 'manual', 'station'];

if ($method === 'GET') {
    $tenant = TenantModel::findById($tenantId);
    if (!$tenant) {
        Response::notFound('Tenant');
    }

    $branches = BranchModel::getAll($tenantId);

    $branchList = array_map(function ($b) {
        $methods = null;
        if (isset($b['attendance_methods']) && $b['attendance_methods'] !== null) {
            $methods = json_decode($b['attendance_methods'], true);
        }
        return [
            'id' => (int) $b['id'],
            'name' => $b['name'],
            'attendance_methods' => $methods,
            'gps_radius_meters' => (int) ($b['gps_radius_meters'] ?? 100),
        ];
    }, $branches);

    $tenantMethods = json_decode($tenant['attendance_methods'] ?? '["qr_gps"]', true) ?: ['qr_gps'];
    $manualAdminIds = $tenant['manual_attendance_admin_ids'] !== null
        ? json_decode($tenant['manual_attendance_admin_ids'], true)
        : null;

    Response::success([
        'name' => $tenant['name'] ?? '',
        'address' => $tenant['domain'] ?? '',
        'phone' => '',
        'email' => $tenant['owner_email'] ?? '',
        'attendance_methods' => $tenantMethods,
        'manual_attendance_admin_ids' => $manualAdminIds,
        'branches' => $branchList,
    ]);
}

if ($method === 'PUT' || $method === 'POST') {
    PermissionMiddleware::check($auth, 'manage_company_settings');

    $input = $auth['input'];

    $tenant = TenantModel::findById($tenantId);
    if (!$tenant) {
        Response::notFound('Tenant');
    }

    $updateData = [];
    foreach (['name', 'address', 'phone', 'email', 'timezone', 'currency'] as $field) {
        if (isset($input[$field])) {
            $updateData[$field] = $input[$field];
        }
    }

    if (isset($input['attendance_methods'])) {
        $methodsVal = $input['attendance_methods'];
        if (!is_array($methodsVal) || empty($methodsVal)) {
            Response::fail('attendance_methods must be a non-empty array', 422);
        }
        foreach ($methodsVal as $m) {
            if (!in_array($m, $allowedMethods, true)) {
                Response::fail('Invalid attendance method: ' . $m . '. Allowed: ' . implode(', ', $allowedMethods), 422);
            }
        }
        $methodsVal = array_values(array_unique($methodsVal));

        $manualAdminIdsVal = $input['manual_attendance_admin_ids'] ?? null;

        if (!in_array('manual', $methodsVal, true)) {
            $manualAdminIdsVal = null;
        }

        if ($manualAdminIdsVal !== null) {
            if (!is_array($manualAdminIdsVal)) {
                Response::fail('manual_attendance_admin_ids must be an array or null', 422);
            }
            foreach ($manualAdminIdsVal as $aid) {
                $admin = AdminModel::findById((int) $aid, $tenantId);
                if (!$admin) {
                    Response::fail('Admin ID ' . $aid . ' not found in this tenant', 422);
                }
            }
        }

        TenantModel::updateAttendanceMethods($tenantId, $methodsVal, $manualAdminIdsVal);
    } elseif (isset($input['manual_attendance_admin_ids'])) {
        $currentMethods = json_decode($tenant['attendance_methods'] ?? '[]', true) ?: [];
        if (!in_array('manual', $currentMethods, true)) {
            Response::fail('Cannot set manual_attendance_admin_ids when manual method is not enabled', 422);
        }
        $manualAdminIdsVal = $input['manual_attendance_admin_ids'];
        if ($manualAdminIdsVal !== null) {
            if (!is_array($manualAdminIdsVal)) {
                Response::fail('manual_attendance_admin_ids must be an array or null', 422);
            }
            foreach ($manualAdminIdsVal as $aid) {
                $admin = AdminModel::findById((int) $aid, $tenantId);
                if (!$admin) {
                    Response::fail('Admin ID ' . $aid . ' not found in this tenant', 422);
                }
            }
        }
        TenantModel::updateAttendanceMethods($tenantId, $currentMethods, $manualAdminIdsVal);
    }

    if (!empty($updateData)) {
        TenantModel::update($tenantId, $updateData);
    }

    AuditLogModel::log($tenantId, $auth['admin_id'], 'tenant.update_settings', 'tenant', $tenantId);

    Response::success(['message' => 'Settings updated']);
}

Response::fail('Method not allowed', 405);
