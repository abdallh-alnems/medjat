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
            'cycle_start_day' => $b['cycle_start_day'] !== null
                ? (int) $b['cycle_start_day']
                : null,
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
        'email' => '',
        'attendance_methods' => $tenantMethods,
        'manual_attendance_admin_ids' => $manualAdminIds,
        'allow_offline_attendance' => (bool) ($tenant['allow_offline_attendance'] ?? true),
        'cycle_start_day' => (int) ($tenant['cycle_start_day'] ?? 1),
        'currency' => $tenant['currency'] ?? 'EGP',
        'timezone' => $tenant['timezone'] ?? 'Africa/Cairo',
        'branches' => $branchList,
        // Letter/certificate branding & company text data
        'commercial_register' => $tenant['commercial_register'] ?? '',
        'company_address' => $tenant['company_address'] ?? '',
        'company_phone' => $tenant['company_phone'] ?? '',
        'has_logo' => !empty($tenant['logo_url']),
        'has_stamp' => !empty($tenant['stamp_url']),
        'has_signature' => !empty($tenant['signature_url']),
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
    // Only real `tenants` columns may go here.
    if (isset($input['name'])) {
        $updateData['name'] = trim((string) $input['name']);
    }
    if (isset($input['currency'])) {
        $currency = strtoupper(trim((string) $input['currency']));
        if (!preg_match('/^[A-Z]{3}$/', $currency)) {
            Response::fail('currency must be a 3-letter ISO code (e.g. EGP)', 422);
        }
        $updateData['currency'] = $currency;
    }
    if (isset($input['timezone'])) {
        $timezone = trim((string) $input['timezone']);
        if (!in_array($timezone, timezone_identifiers_list(), true)) {
            Response::fail('Invalid timezone identifier', 422);
        }
        $updateData['timezone'] = $timezone;
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

    if (isset($input['cycle_start_day'])) {
        $day = (int) $input['cycle_start_day'];
        if ($day < 1 || $day > 28) {
            Response::fail('cycle_start_day must be between 1 and 28', 422);
        }
        $updateData['cycle_start_day'] = $day;
    }

    if (isset($input['allow_offline_attendance'])) {
        $allowOffline = filter_var($input['allow_offline_attendance'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($allowOffline === null) {
            Response::fail('allow_offline_attendance must be true or false', 422);
        }
        TenantModel::updateAllowOffline($tenantId, $allowOffline);
    }

    if (!empty($updateData)) {
        TenantModel::update($tenantId, $updateData);
    }

    // Letter/certificate company text data (columns guaranteed to exist).
    $brandingData = [];
    foreach (['commercial_register', 'company_address', 'company_phone'] as $field) {
        if (isset($input[$field])) {
            $brandingData[$field] = trim((string) $input[$field]);
        }
    }
    if (!empty($brandingData)) {
        TenantModel::update($tenantId, $brandingData);
    }

    AuditLogModel::log($tenantId, $auth['admin_id'], 'tenant.update_settings', 'tenant', $tenantId);

    Response::success(['message' => 'Settings updated']);
}

Response::fail('Method not allowed', 405);
