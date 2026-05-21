<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_assets');

$status = $_GET['status'] ?? null;
$employeeId = isset($_GET['employee_id']) ? (int) $_GET['employee_id'] : null;

$items = AssetModel::listByTenant($tenantId, $status, $employeeId);

Response::success(['items' => $items]);
