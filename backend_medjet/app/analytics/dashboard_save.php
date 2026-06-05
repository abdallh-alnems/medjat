<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'view_analytics');

$body = Validator::getJsonBody();

$name = $body['name'] ?? 'Default';
if (!is_string($name) || $name === '') {
    Response::fail('name must be a non-empty string', 400);
}

$layout = $body['layout'] ?? null;
if (!is_array($layout)) {
    Response::fail('layout must be an array', 400);
}

$validKeys = ['turnover', 'absence', 'labor_cost', 'headcount', 'overview'];
$validTypes = ['line', 'bar', 'pie', 'kpi'];

foreach ($layout as $i => $widget) {
    if (!is_array($widget)) {
        Response::fail("layout[{$i}] must be an object", 400);
    }
    if (!isset($widget['key']) || !in_array($widget['key'], $validKeys, true)) {
        Response::fail("layout[{$i}].key must be one of: " . implode(', ', $validKeys), 400);
    }
    if (!isset($widget['type']) || !in_array($widget['type'], $validTypes, true)) {
        Response::fail("layout[{$i}].type must be one of: " . implode(', ', $validTypes), 400);
    }
}

$adminId = (int) $auth['admin_id'];
$id = AnalyticsDashboardModel::save($tenantId, $adminId, $name, $layout);

AuditLogModel::log($tenantId, $adminId, 'analytics.dashboard_save', 'analytics_dashboard', $id, [
    'name' => $name,
    'widget_count' => count($layout),
]);

Response::success(['id' => $id, 'name' => $name, 'widget_count' => count($layout)]);
