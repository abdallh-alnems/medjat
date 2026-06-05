<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_schedule');
$input = $auth['input'];

Validator::required($input['id'] ?? null, 'id');
Validator::required($input['decision'] ?? null, 'decision');
Validator::enum($input['decision'], ['approve', 'reject'], 'decision');

$id = (int) $input['id'];
$decision = $input['decision'];
$note = $input['note'] ?? null;

$swap = ShiftSwapModel::findById($id, $tenantId);
if (!$swap) Response::notFound('Swap request');

// A swap touches both employees' cells — the manager must have access to both branches.
if (isset($swap['requester_branch_id']) && $swap['requester_branch_id'] !== null) {
    PermissionMiddleware::checkBranchAccess($auth, (int) $swap['requester_branch_id']);
}
if (isset($swap['target_branch_id']) && $swap['target_branch_id'] !== null) {
    PermissionMiddleware::checkBranchAccess($auth, (int) $swap['target_branch_id']);
}

if ($decision === 'approve') {
    ShiftSwapModel::approve($tenantId, $id, (int) $auth['admin_id'], $note);
    AuditLogModel::log($tenantId, $auth['admin_id'], 'schedule.swap_approve', 'shift_swap', $id);
    Response::success(['approved' => true]);
} else {
    ShiftSwapModel::reject($tenantId, $id, (int) $auth['admin_id'], $note);
    AuditLogModel::log($tenantId, $auth['admin_id'], 'schedule.swap_reject', 'shift_swap', $id);
    Response::success(['rejected' => true]);
}
