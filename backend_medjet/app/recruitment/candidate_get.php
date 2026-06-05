<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_recruitment');

$id = (int) ($_GET['id'] ?? 0);
Validator::required($id, 'id');

$candidate = CandidateModel::findById($id, $tenantId);
if (!$candidate) {
    Response::notFound('Candidate');
}

Response::success($candidate);
