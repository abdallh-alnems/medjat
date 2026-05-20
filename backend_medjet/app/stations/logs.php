<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'station_view_logs');

$filters = [
    'branch_id' => $_GET['branch_id'] ?? null,
    'station_id' => $_GET['station_id'] ?? null,
    'employee_id' => $_GET['employee_id'] ?? null,
    'result' => $_GET['result'] ?? null,
    'from' => $_GET['from'] ?? null,
    'to' => $_GET['to'] ?? null,
];
$page = (int) ($_GET['page'] ?? 1);

$logs = StationRecognitionLogModel::getLogs($tenantId, $filters, $page);

Response::success($logs);
