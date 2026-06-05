<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_performance');
$input = $auth['input'];

$name = trim((string) ($input['name'] ?? ''));
Validator::required($name, 'name');
$startDate = $input['start_date'] ?? '';
$endDate = $input['end_date'] ?? '';
Validator::required($startDate, 'start_date');
Validator::required($endDate, 'end_date');
Validator::date($startDate, 'start_date');
Validator::date($endDate, 'end_date');

if ($endDate < $startDate) {
    Response::fail('end_date must be >= start_date', 422);
}

$periodType = Validator::enum($input['period_type'] ?? 'quarterly', PerformanceCycleModel::PERIOD_TYPES, 'period_type');

$data = [
    'name' => $name,
    'name_ar' => $input['name_ar'] ?? null,
    'period_type' => $periodType,
    'start_date' => $startDate,
    'end_date' => $endDate,
    'status' => $input['status'] ?? 'draft',
];

if (isset($data['status'])) {
    $data['status'] = Validator::enum($data['status'], PerformanceCycleModel::STATUSES, 'status');
}

$id = PerformanceCycleModel::create($tenantId, $data, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'performance_cycle.create', 'performance_cycle', $id, ['name' => $name]);

Response::success(['id' => $id, 'message' => 'Cycle created'], 201);
