<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$rules = DeductionRuleModel::getActiveByTenant($tenantId);

Response::success(['rules' => $rules]);
