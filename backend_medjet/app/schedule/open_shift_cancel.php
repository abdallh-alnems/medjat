<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_schedule');
$input = $auth['input'];

Validator::required($input['id'] ?? null, 'id');
$id = (int) $input['id'];

$shift = OpenShiftModel::findById($id, $tenantId);
if (!$shift) Response::notFound('Open shift');

if ($shift['branch_id'] !== null) {
    PermissionMiddleware::checkBranchAccess($auth, (int) $shift['branch_id']);
}

OpenShiftModel::cancel($id, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'schedule.open_shift_cancel', 'open_shift', $id);

Response::success(['cancelled' => true]);
