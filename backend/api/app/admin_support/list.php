<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$admin = AdminAuth::require('admin');

$page = max(1, (int) ($_GET['page'] ?? 1));
$limit = min(50, max(1, (int) ($_GET['limit'] ?? 30)));
$status = $_GET['status'] ?? null;
$tenantId = isset($_GET['tenant_id']) ? (int) $_GET['tenant_id'] : null;

$result = SupportModel::listAll($status, $tenantId, $page, $limit);

Response::success($result);
