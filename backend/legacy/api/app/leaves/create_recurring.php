<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$input = $auth['input'];
$dayOfWeek = $input['day_of_week'] ?? null;
$type = $input['type'] ?? 'weekly_off';
$branchId = ($input['branch_id'] ?? null) ? (int) $input['branch_id'] : null;
$reason = $input['reason'] ?? null;

Validator::required($dayOfWeek, 'day_of_week');
Validator::enum($dayOfWeek, ['saturday', 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday'], 'day_of_week');

$id = LeaveModel::createRecurring($tenantId, $branchId, $dayOfWeek, $type, $reason);

Response::success(['id' => $id, 'message' => 'Recurring leave created']);
