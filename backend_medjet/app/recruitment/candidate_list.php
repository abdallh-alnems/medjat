<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_recruitment');

$jobId = isset($_GET['job_id']) ? (int) $_GET['job_id'] : null;
$stage = $_GET['stage'] ?? null;

$list = CandidateModel::listByTenant($tenantId, $jobId, $stage);

Response::success(['items' => $list]);
