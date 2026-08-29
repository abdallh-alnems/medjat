<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];

$employee = $auth['employee'];
$year = (int) ($_GET['year'] ?? date('Y'));
$balance = LeaveModel::getBalance($employee['id'], $tenantId, $year);

Response::success($balance);
