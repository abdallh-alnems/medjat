<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];
$input = $auth['input'];

$reasonRaw = $input['reason'] ?? '';
$reasonMap = [
    'mock_location'      => 'mock_location',
    'rooted'             => 'rooted',
    'jailbroken'         => 'jailbroken',
    'vpn'                => 'vpn',
    'no_local_biometric' => 'no_local_biometric',
];
$reason = $reasonMap[$reasonRaw] ?? null;
if ($reason === null) {
    Response::fail('Invalid reason', 400, 'invalid_reason');
}

$branchId = (int) ($input['branch_id'] ?? 0) ?: null;
$lat = isset($input['latitude']) ? (float) $input['latitude'] : null;
$lng = isset($input['longitude']) ? (float) $input['longitude'] : null;

AttendanceSecurityModel::log(
    $tenantId,
    (int) $employee['id'],
    $branchId,
    $reason,
    'blocked',
    $lat,
    $lng
);

Response::success(['logged' => true]);
