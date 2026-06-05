<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_performance');
$input = $auth['input'];

$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

$cycle = PerformanceCycleModel::findById($id, $tenantId);
if (!$cycle) {
    Response::notFound('Cycle');
}

$data = [];
$allowed = ['name', 'name_ar', 'period_type', 'start_date', 'end_date'];
foreach ($allowed as $key) {
    if (array_key_exists($key, $input)) {
        $data[$key] = $input[$key];
    }
}

if (isset($data['period_type'])) {
    $data['period_type'] = Validator::enum($data['period_type'], PerformanceCycleModel::PERIOD_TYPES, 'period_type');
}
if (isset($data['start_date'])) {
    Validator::date($data['start_date'], 'start_date');
}
if (isset($data['end_date'])) {
    Validator::date($data['end_date'], 'end_date');
}

if (isset($data['start_date']) && isset($data['end_date']) && $data['end_date'] < $data['start_date']) {
    Response::fail('end_date must be >= start_date', 422);
}

PerformanceCycleModel::update($id, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'performance_cycle.update', 'performance_cycle', $id);

Response::success(['message' => 'Cycle updated']);
