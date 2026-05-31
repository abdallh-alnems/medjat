<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$input = $auth['input'];
$updateData = [];

if (array_key_exists('name', $input)) {
    $name = trim((string) $input['name']);
    if ($name === '') {
        Response::fail('Name cannot be empty', 422);
    }
    $updateData['name'] = $name;
}

if (array_key_exists('phone', $input)) {
    $phone = trim((string) $input['phone']);
    if ($phone === '') {
        // Empty clears the phone back to NULL.
        $updateData['phone'] = null;
    } else {
        $normalized = Validator::phone($phone);
        if ($normalized === null) {
            Response::fail('Invalid phone number', 422);
        }
        $updateData['phone'] = $normalized;
    }
}

if (empty($updateData)) {
    Response::fail('Nothing to update', 422);
}

AdminModel::update($auth['admin_id'], $tenantId, $updateData);

AuditLogModel::log($tenantId, $auth['admin_id'], 'profile.update', 'admin', $auth['admin_id'], $updateData);

Response::success(['message' => 'Profile updated']);
