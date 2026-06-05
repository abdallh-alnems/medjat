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

$candidate = CandidateModel::findById($id, $tenantId);
if (!$candidate) {
    Response::notFound('Candidate');
}

$data = [];
foreach (['job_opening_id', 'email', 'phone', 'cv_url', 'source', 'expected_salary', 'notes', 'name'] as $key) {
    if (array_key_exists($key, $input)) {
        $data[$key] = $input[$key];
    }
}

CandidateModel::update($id, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'candidate.update', 'candidate', $id);

Response::success(['message' => 'Candidate updated']);
