<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_recruitment');

$input = $auth['input'];
$name = trim((string) ($input['name'] ?? ''));
Validator::required($name, 'name');

$stage = Validator::enum($input['stage'] ?? 'applied', CandidateModel::STAGES, 'stage');

if ($jobOpeningId = ($input['job_opening_id'] ?? null)) {
    $job = JobOpeningModel::findById((int) $jobOpeningId, $tenantId);
    if (!$job) {
        Response::notFound('Job opening');
    }
}

$data = [
    'name' => $name,
    'job_opening_id' => isset($input['job_opening_id']) && $input['job_opening_id'] !== '' ? (int) $input['job_opening_id'] : null,
    'email' => $input['email'] ?? null,
    'phone' => $input['phone'] ?? null,
    'cv_url' => $input['cv_url'] ?? null,
    'source' => $input['source'] ?? null,
    'stage' => $stage,
    'expected_salary' => $input['expected_salary'] ?? null,
    'notes' => $input['notes'] ?? null,
];

$id = CandidateModel::create($tenantId, $data, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'candidate.create', 'candidate', $id, ['name' => $name, 'stage' => $stage]);

Response::success(['id' => $id, 'message' => 'Candidate created'], 201);
