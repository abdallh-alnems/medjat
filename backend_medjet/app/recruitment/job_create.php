<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_recruitment');

$input = $auth['input'];
$title = trim((string) ($input['title'] ?? ''));
Validator::required($title, 'title');

$employmentType = Validator::enum($input['employment_type'] ?? 'full_time', JobOpeningModel::EMPLOYMENT_TYPES, 'employment_type');

$data = [
    'title' => $title,
    'branch_id' => isset($input['branch_id']) && $input['branch_id'] !== '' ? (int) $input['branch_id'] : null,
    'department' => $input['department'] ?? null,
    'description' => $input['description'] ?? null,
    'employment_type' => $employmentType,
    'openings_count' => max(1, (int) ($input['openings_count'] ?? 1)),
    'status' => $input['status'] ?? 'open',
];

$id = JobOpeningModel::create($tenantId, $data, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'job_opening.create', 'job_opening', $id, ['title' => $title]);

Response::success(['id' => $id, 'message' => 'Job opening created'], 201);
