<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$input = $auth['input'];
$name = $input['name'] ?? null;
$phone = $input['phone'] ?? null;

if ($name) {
    AdminModel::update($auth['admin_id'], $tenantId, ['name' => $name]);
}

Response::success(['message' => 'Profile updated']);
