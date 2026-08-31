<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$method = $_SERVER['REQUEST_METHOD'];

$allowedMethods = AttendanceMethodResolver::ALLOWED;

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
            'qr_code' => $b['qr_code'] ?? null,
            'attendance_methods' => $methods,
            // NULL = inherit the company face settings.
            'face_match_threshold' => $b['face_match_threshold'] !== null
                ? (float) $b['face_match_threshold']
                : null,
            'face_liveness_required' => $b['face_liveness_required'] !== null
                ? (bool) $b['face_liveness_required']
                : null,
            // NULL wifi_mode = the branch has never enabled the WiFi method.
            'wifi_mode' => $b['wifi_mode'] ?? null,
            'wifi_match' => $b['wifi_match'] ?? 'bssid',
            'gps_radius_meters' => (int) ($b['gps_radius_meters'] ?? 100),
            // latitude/longitude are NOT NULL; 0,0 means "unset".
            'lat' => ((float) ($b['latitude'] ?? 0)) != 0.0 ? (float) $b['latitude'] : null,
            'lng' => ((float) ($b['longitude'] ?? 0)) != 0.0 ? (float) $b['longitude'] : null,
            'cycle_start_day' => $b['cycle_start_day'] !== null
                ? (int) $b['cycle_start_day']
                : null,
        ];
    }, $branches);

    $tenantMethods = json_decode($tenant['attendance_methods'] ?? '["qr_gps"]', true) ?: ['qr_gps'];
    $manualAdminIds = $tenant['manual_attendance_admin_ids'] !== null
        ? json_decode($tenant['manual_attendance_admin_ids'], true)
        : null;

    // Category overrides (attendance_methods != null = custom, else inherit).
    $categoryList = array_map(function ($c) {
        $methods = null;
        if (isset($c['attendance_methods']) && $c['attendance_methods'] !== null) {
            $methods = json_decode($c['attendance_methods'], true);
        }
        return [
            'id' => (int) $c['id'],
            'name' => $c['name'],
            'color' => $c['color'] ?? null,
            'employee_count' => (int) ($c['employee_count'] ?? 0),
            'attendance_methods' => $methods,
            // NULL = inherit the company switch. Sent as null, not false, so the
            // screen can show three states instead of guessing at two.
            'web_attendance_allowed' => $c['web_attendance_allowed'] !== null
                ? (bool) $c['web_attendance_allowed']
                : null,
        ];
    }, EmployeeCategoryModel::listByTenant($tenantId, true));

    // Employees with an explicit override.
    $employeeOverrides = array_map(function ($e) {
        return [
            'id' => (int) $e['id'],
            'name' => $e['name'],
            'branch_name' => $e['branch_name'] ?? null,
            'attendance_methods' => $e['attendance_methods'] !== null
                ? json_decode($e['attendance_methods'], true)
                : null,
        ];
    }, EmployeeModel::listAttendanceOverrides($tenantId));

    Response::success([
        'name' => $tenant['name'] ?? '',
        'address' => $tenant['company_address'] ?? '',
        'phone' => '',
        'email' => '',
        'attendance_methods' => $tenantMethods,
        'manual_attendance_admin_ids' => $manualAdminIds,
        'allow_offline_attendance' => (bool) ($tenant['allow_offline_attendance'] ?? true),
        'reject_mock_location' => (bool) ($tenant['reject_mock_location'] ?? false),
        'require_local_biometric' => (bool) ($tenant['require_local_biometric'] ?? false),
        'face_match_threshold' => (float) ($tenant['face_match_threshold'] ?? FaceMatchService::DEFAULT_THRESHOLD),
        'face_liveness_required' => (bool) ($tenant['face_liveness_required'] ?? true),
        'face_enforce_mode' => $tenant['face_enforce_mode'] ?? 'log_only',
        'gps_latitude' => $tenant['gps_latitude'] !== null ? (float) $tenant['gps_latitude'] : null,
        'gps_longitude' => $tenant['gps_longitude'] !== null ? (float) $tenant['gps_longitude'] : null,
        'gps_radius_meters' => $tenant['gps_radius_meters'] !== null ? (int) $tenant['gps_radius_meters'] : null,
        'cycle_start_day' => (int) ($tenant['cycle_start_day'] ?? 1),
        'week_start_day' => (int) ($tenant['week_start_day'] ?? 6),
        'currency' => $tenant['currency'] ?? 'EGP',
        'timezone' => $tenant['timezone'] ?? 'Africa/Cairo',
        // False means nobody ever picked one, so the client may suggest the
        // device's zone. True means hands off.
        'timezone_is_explicit' => (bool) ($tenant['timezone_is_explicit'] ?? false),
        // Browser attendance channel. Off for every company that has not opted
        // in; the photo default is on so enabling the weakest channel keeps the
        // one control that says anything about who pressed the button.
        'web_attendance_enabled' => (bool) ($tenant['web_attendance_enabled'] ?? false),
        'web_attendance_photo_required' => (bool) ($tenant['web_attendance_photo_required'] ?? true),
        // What the browser cannot check, whatever the company has configured
        // elsewhere. Codes rather than sentences so each client localizes them,
        // and served from here so the disclosure cannot drift per client.
        'web_channel_limitations' => [
            'wifi_bssid',     // no access-point identity is available to a page
            'mock_location',  // no spoofing signal is reported to a page
            'face_match',     // the on-device face model does not run in a browser
        ],
        // Branches whose only network control is BSSID-based, i.e. no control at
        // all on this channel — named so the warning is specific.
        'branches_without_ip_networks' => BranchNetworkModel::branchesWithoutIpControl($tenantId),
        // True when the company default would make the browser channel useless.
        // The page sends no `method`, so a browser punch always resolves as
        // 'gps_only'; without it every employee on the company default is
        // refused the instant they press the button. Reported next to the switch
        // because "I turned it on and nothing works" is otherwise a support
        // ticket, and the cause is two screens away.
        'web_requires_gps_only' => !in_array('gps_only', $tenantMethods, true),
        'branches' => $branchList,
        'categories' => $categoryList,
        'employee_overrides' => $employeeOverrides,
        // Letter/certificate branding & company text data
        'commercial_register' => $tenant['commercial_register'] ?? '',
        'company_address' => $tenant['company_address'] ?? '',
        'company_phone' => $tenant['company_phone'] ?? '',
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
            Response::fail('currency must be a 3-letter ISO code (e.g. EGP)', 422, 'currency_3_letter_iso_code');
        }
        $updateData['currency'] = $currency;
    }
    if (isset($input['timezone'])) {
        $timezone = trim((string) $input['timezone']);
        if (!in_array($timezone, timezone_identifiers_list(), true)) {
            Response::fail('Invalid timezone identifier', 422, 'invalid_timezone_identifier');
        }
        $updateData['timezone'] = $timezone;
        // Saving from this screen is a deliberate choice, so stop the client
        // from ever auto-suggesting a device timezone over it again.
        $updateData['timezone_is_explicit'] = 1;
    }

    if (isset($input['attendance_methods'])) {
        $methodsVal = $input['attendance_methods'];
        if (!is_array($methodsVal) || empty($methodsVal)) {
            Response::fail('attendance_methods must be a non-empty array', 422, 'attendance_methods_non_empty_array');
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
                Response::fail('manual_attendance_admin_ids must be an array or null', 422, 'manual_attendance_admin_ids_array');
            }
            foreach ($manualAdminIdsVal as $aid) {
                $admin = AdminModel::findById((int) $aid, $tenantId);
                if (!$admin) {
                    Response::fail('Admin ID ' . $aid . ' not found in this tenant', 422, 'admin_not_found');
                }
            }
        }

        TenantModel::updateAttendanceMethods($tenantId, $methodsVal, $manualAdminIdsVal);
    // array_key_exists, not isset: null is a real value here — it means "no
    // restriction, any admin may record manual attendance" — and isset() cannot
    // see it, so clearing the list was only ever possible by also sending the
    // whole method list along to carry it. That coupling is what let an
    // unrelated save rewrite a company's methods.
    } elseif (array_key_exists('manual_attendance_admin_ids', $input)) {
        // Read through, never rewritten. This branch has no opinion about the
        // methods and must not become a way to change them by omission.
        $currentMethods = json_decode($tenant['attendance_methods'] ?? '[]', true) ?: [];
        $manualAdminIdsVal = $input['manual_attendance_admin_ids'];

        // Only guard when a list is actually being set. Refusing to CLEAR a
        // restriction because the method is off would leave a company unable to
        // tidy up after disabling manual attendance.
        if ($manualAdminIdsVal !== null && !in_array('manual', $currentMethods, true)) {
            Response::fail('Cannot set manual_attendance_admin_ids when manual method is not enabled', 422, 'cannot_set_manual_attendance_admin');
        }
        if ($manualAdminIdsVal !== null) {
            if (!is_array($manualAdminIdsVal)) {
                Response::fail('manual_attendance_admin_ids must be an array or null', 422, 'manual_attendance_admin_ids_array');
            }
            foreach ($manualAdminIdsVal as $aid) {
                $admin = AdminModel::findById((int) $aid, $tenantId);
                if (!$admin) {
                    Response::fail('Admin ID ' . $aid . ' not found in this tenant', 422, 'admin_not_found');
                }
            }
        }
        TenantModel::updateAttendanceMethods($tenantId, $currentMethods, $manualAdminIdsVal);
    }

    if (isset($input['cycle_start_day'])) {
        $day = (int) $input['cycle_start_day'];
        if ($day < 1 || $day > 28) {
            Response::fail('cycle_start_day must be between 1 and 28', 422, 'cycle_start_day_between_1');
        }
        $updateData['cycle_start_day'] = $day;
    }

    if (isset($input['week_start_day'])) {
        $wday = (int) $input['week_start_day'];
        if ($wday < 1 || $wday > 7) {
            Response::fail('week_start_day must be between 1 (Mon) and 7 (Sun)', 422, 'week_start_day_between_1');
        }
        $updateData['week_start_day'] = $wday;
    }

    if (isset($input['allow_offline_attendance'])) {
        $allowOffline = filter_var($input['allow_offline_attendance'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($allowOffline === null) {
            Response::fail('allow_offline_attendance must be true or false', 422, 'allow_offline_attendance_true_false');
        }
        TenantModel::updateAllowOffline($tenantId, $allowOffline);
    }

    if (isset($input['reject_mock_location'])) {
        $rejectMock = filter_var($input['reject_mock_location'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($rejectMock === null) {
            Response::fail('reject_mock_location must be true or false', 422, 'reject_mock_location_true_false');
        }
        TenantModel::updateRejectMockLocation($tenantId, $rejectMock);
    }

    if (isset($input['require_local_biometric'])) {
        $requireBio = filter_var($input['require_local_biometric'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($requireBio === null) {
            Response::fail('require_local_biometric must be true or false', 422, 'require_local_biometric_true_false');
        }
        TenantModel::updateRequireLocalBiometric($tenantId, $requireBio);
    }

    // Browser attendance channel. Kept out of $updateData and audited on its own
    // line: this is the switch that decides whether the weakest verification
    // surface in the product is open, and "who turned it on, and when" is the
    // first question anyone will ask about a disputed browser punch.
    if (array_key_exists('web_attendance_enabled', $input)
        || array_key_exists('web_attendance_photo_required', $input)) {
        $webEnabled = array_key_exists('web_attendance_enabled', $input)
            ? filter_var($input['web_attendance_enabled'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE)
            : (bool) ($tenant['web_attendance_enabled'] ?? false);
        if ($webEnabled === null) {
            Response::fail('web_attendance_enabled must be true or false', 422, 'web_attendance_enabled_bool');
        }

        $webPhoto = array_key_exists('web_attendance_photo_required', $input)
            ? filter_var($input['web_attendance_photo_required'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE)
            : (bool) ($tenant['web_attendance_photo_required'] ?? true);
        if ($webPhoto === null) {
            Response::fail('web_attendance_photo_required must be true or false', 422, 'web_attendance_photo_required_bool');
        }

        $wasEnabled = (bool) ($tenant['web_attendance_enabled'] ?? false);
        $wasPhoto = (bool) ($tenant['web_attendance_photo_required'] ?? true);

        if ($webEnabled !== $wasEnabled || $webPhoto !== $wasPhoto) {
            TenantModel::update($tenantId, [
                'web_attendance_enabled' => $webEnabled ? 1 : 0,
                'web_attendance_photo_required' => $webPhoto ? 1 : 0,
            ]);

            AuditLogModel::log(
                $tenantId,
                $auth['admin_id'],
                'tenant.web_attendance_settings',
                'tenant',
                $tenantId,
                [
                    'enabled' => ['from' => $wasEnabled, 'to' => $webEnabled],
                    'photo_required' => ['from' => $wasPhoto, 'to' => $webPhoto],
                ]
            );
        }
    }

    // Company-wide face-recognition settings for the face_selfie method.
    if (array_key_exists('face_match_threshold', $input)
        || array_key_exists('face_liveness_required', $input)
        || array_key_exists('face_enforce_mode', $input)) {
        $threshold = array_key_exists('face_match_threshold', $input)
            ? (float) $input['face_match_threshold']
            : (float) ($tenant['face_match_threshold'] ?? FaceMatchService::DEFAULT_THRESHOLD);
        // Below 0.3 the match is meaningless; above 0.95 nobody ever passes.
        if ($threshold < 0.3 || $threshold > 0.95) {
            Response::fail('face_match_threshold must be between 0.3 and 0.95', 422, 'face_match_threshold_range');
        }

        $liveness = array_key_exists('face_liveness_required', $input)
            ? filter_var($input['face_liveness_required'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE)
            : (bool) ($tenant['face_liveness_required'] ?? true);
        if ($liveness === null) {
            Response::fail('face_liveness_required must be true or false', 422, 'face_liveness_required_bool');
        }

        $enforceMode = array_key_exists('face_enforce_mode', $input)
            ? (string) $input['face_enforce_mode']
            : ($tenant['face_enforce_mode'] ?? 'log_only');
        if (!in_array($enforceMode, ['log_only', 'enforce'], true)) {
            Response::fail('face_enforce_mode must be log_only or enforce', 422, 'face_enforce_mode_invalid');
        }

        TenantModel::updateFaceSettings($tenantId, $threshold, $liveness, $enforceMode);
    }

    // Company-wide GPS geofence (default for branches without their own center).
    // Send all three together; null clears the company location.
    if (array_key_exists('gps_latitude', $input)
        || array_key_exists('gps_longitude', $input)
        || array_key_exists('gps_radius_meters', $input)) {
        $gLat = $input['gps_latitude'] ?? null;
        $gLng = $input['gps_longitude'] ?? null;
        $gRadius = $input['gps_radius_meters'] ?? null;
        if ($gLat === null || $gLng === null) {
            TenantModel::updateGeofence($tenantId, null, null, null);
        } else {
            $radius = (int) $gRadius;
            if ($radius < 5 || $radius > 5000) {
                Response::fail('gps_radius_meters must be between 5 and 5000', 422, 'gps_radius_meters_between_5');
            }
            TenantModel::updateGeofence($tenantId, (float) $gLat, (float) $gLng, $radius);
        }
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

Response::fail('Method not allowed', 405, 'method_not_allowed');
