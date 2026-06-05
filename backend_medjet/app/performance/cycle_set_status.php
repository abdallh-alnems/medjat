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
$status = $input['status'] ?? '';
Validator::required($status, 'status');
$status = Validator::enum($status, PerformanceCycleModel::STATUSES, 'status');

$cycle = PerformanceCycleModel::findById($id, $tenantId);
if (!$cycle) {
    Response::notFound('Cycle');
}

PerformanceCycleModel::setStatus($id, $tenantId, $status);

AuditLogModel::log($tenantId, $auth['admin_id'], 'performance_cycle.set_status', 'performance_cycle', $id, ['status' => $status]);

Response::success(['message' => 'Cycle status updated']);
