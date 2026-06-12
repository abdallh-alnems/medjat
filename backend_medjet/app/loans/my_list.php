<?php
// Employee-facing: list the signed-in employee's own advance requests.
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$status = $_GET['status'] ?? null;

$rows = LoanModel::listByTenant($tenantId, $status, (int) $auth['employee']['id']);
Response::success(['loans' => $rows]);
