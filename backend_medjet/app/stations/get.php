<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$id = (int) ($_GET['id'] ?? 0);
Validator::required($id, 'id');

$station = AttendanceStationModel::findById($id, $tenantId);
if (!$station) Response::fail('Station not found', 404);

Response::success($station);
