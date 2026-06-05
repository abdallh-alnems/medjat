<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'view_analytics');

$dashboard = AnalyticsDashboardModel::getForAdmin($tenantId, (int) $auth['admin_id']);

if ($dashboard) {
    $layout = json_decode($dashboard['layout'], true) ?: [];
    Response::success([
        'id' => (int) $dashboard['id'],
        'name' => $dashboard['name'],
        'layout' => $layout,
        'updated_at' => $dashboard['updated_at'],
    ]);
}

Response::success([
    'id' => null,
    'name' => 'Default',
    'layout' => [
        ['key' => 'overview', 'type' => 'kpi', 'position' => 0, 'size' => 12],
        ['key' => 'turnover', 'type' => 'line', 'position' => 1, 'size' => 6],
        ['key' => 'absence', 'type' => 'bar', 'position' => 2, 'size' => 6],
        ['key' => 'labor_cost', 'type' => 'line', 'position' => 3, 'size' => 6],
        ['key' => 'headcount', 'type' => 'line', 'position' => 4, 'size' => 6],
    ],
    'updated_at' => null,
]);
