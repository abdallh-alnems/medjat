<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

OnboardingModel::ensureDefaults($tenantId);

$templates = OnboardingModel::listTemplates($tenantId);

Response::success(['items' => $templates]);
