<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$requestId = (int) ($_GET['request_id'] ?? 0);
Validator::required($requestId, 'request_id');

$req = ApprovalRequestModel::findById($requestId, $tenantId);
if (!$req) {
    Response::notFound('Approval request');
}

$isGm = $auth['role'] === 'general_manager';
$hasManageApprovals = PermissionMiddleware::effectivePermissions($auth['admin_id'], $tenantId, $auth['role']);
$hasPerm = $hasManageApprovals === '*'
    || (is_array($hasManageApprovals) && in_array('manage_approvals', $hasManageApprovals, true));

if (!$isGm && !$hasPerm) {
    $step = ApprovalRequestModel::currentStep($requestId, $tenantId);
    $canView = false;
    if ($step) {
        $canView = ($step['approver_type'] === 'admin' && (int) $step['approver_admin_id'] === (int) $auth['admin_id'])
            || ($step['approver_type'] === 'role' && $step['approver_role'] === $auth['role']);
    }
    if (!$canView) {
        Response::forbidden('Access denied');
    }
}

Response::success(['request' => $req]);
