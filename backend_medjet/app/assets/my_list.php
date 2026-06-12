<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = (int) $auth['tenant_id'];
$employeeId = (int) $auth['employee']['id'];

// Employees only ever see their own custody, regardless of any query param.
$status = $_GET['status'] ?? null;
$items = AssetModel::listByTenant($tenantId, $status, $employeeId);

Response::success(['items' => $items]);
