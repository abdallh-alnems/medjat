<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$status = $_GET['status'] ?? null;

// Expire the employee's own pending requests whose window already passed.
BreakRequestModel::expirePastPending($tenantId, $auth['employee']['id']);

$rows = BreakRequestModel::listForEmployee($auth['employee']['id'], $tenantId, $status);
Response::success(['breaks' => $rows]);
