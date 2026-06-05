<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_recruitment');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
$status = $input['status'] ?? '';
Validator::required($id, 'id');
Validator::required($status, 'status');

$status = Validator::enum($status, JobOpeningModel::STATUSES, 'status');

$job = JobOpeningModel::findById($id, $tenantId);
if (!$job) {
    Response::notFound('Job opening');
}

JobOpeningModel::setStatus($id, $tenantId, $status);

AuditLogModel::log($tenantId, $auth['admin_id'], 'job_opening.set_status', 'job_opening', $id, ['status' => $status]);

Response::success(['message' => 'Job opening status updated']);
