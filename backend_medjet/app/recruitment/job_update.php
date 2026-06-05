<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_recruitment');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

$job = JobOpeningModel::findById($id, $tenantId);
if (!$job) {
    Response::notFound('Job opening');
}

$data = [];
foreach (['branch_id', 'title', 'department', 'description', 'employment_type', 'openings_count'] as $key) {
    if (array_key_exists($key, $input)) {
        $data[$key] = $input[$key];
    }
}

if (isset($data['employment_type'])) {
    $data['employment_type'] = Validator::enum($data['employment_type'], JobOpeningModel::EMPLOYMENT_TYPES, 'employment_type');
}
if (isset($data['branch_id']) && $data['branch_id'] === '') {
    $data['branch_id'] = null;
}

JobOpeningModel::update($id, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'job_opening.update', 'job_opening', $id);

Response::success(['message' => 'Job opening updated']);
