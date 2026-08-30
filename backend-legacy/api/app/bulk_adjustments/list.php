<?php
/**
 * List the tenant's bulk bonus/deduction batches, newest first, each with its
 * member count and total figure.
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$batches = BulkAdjustmentModel::listByTenant($tenantId);

Response::success(['items' => $batches]);
