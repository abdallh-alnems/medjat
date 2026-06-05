<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$input = $auth['input'];
$requestId = (int) ($input['request_id'] ?? 0);
$decision = $input['decision'] ?? '';
$note = $input['note'] ?? null;

Validator::required($requestId, 'request_id');
Validator::enum($decision, ['approve', 'reject'], 'decision');

$req = ApprovalRequestModel::findById($requestId, $tenantId);
if (!$req) {
    Response::notFound('Approval request');
}
if ($req['status'] !== 'pending') {
    Response::fail('Request already finalized', 409);
}

$step = ApprovalRequestModel::currentStep($requestId, $tenantId);
if (!$step) {
    Response::fail('Approval request has no active step', 409);
}
$canAct = $auth['role'] === 'general_manager'
    || ($step['approver_type'] === 'admin' && (int) $step['approver_admin_id'] === (int) $auth['admin_id'])
    || ($step['approver_type'] === 'role' && $step['approver_role'] === $auth['role']);
if (!$canAct) {
    Response::forbidden('You are not the approver for the current step');
}

$result = ApprovalRequestModel::decide($tenantId, $requestId, $step, $auth['admin_id'], $decision, $note);

AuditLogModel::log($tenantId, $auth['admin_id'], "approval.step.{$decision}", $req['entity_type'], (int) $req['entity_id'],
    ['request_id' => $requestId, 'step_order' => $step['step_order']]);

if ($result['final'] !== null) {
    ApprovalDispatcher::apply($tenantId, $req['entity_type'], (int) $req['entity_id'], $result['final'], $auth['admin_id'], $note);
}

if ($result['final'] === null && isset($result['next_step'])) {
    try {
        $nextStep = Database::fetchOne(
            "SELECT * FROM approval_request_steps WHERE request_id = ? AND tenant_id = ? AND step_order = ?",
            [$requestId, $tenantId, $result['next_step']]
        );
        if ($nextStep && $nextStep['approver_type'] === 'admin' && $nextStep['approver_admin_id']) {
            Database::execute(
                "INSERT INTO notifications (tenant_id, admin_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
                 VALUES (?, ?, 'approval', 'Pending Approval', 'موافقة معلّقة', 'You have a pending approval request.', 'لديك طلب موافقة معلّق.', ?, 'in_app', NOW())",
                [$tenantId, (int) $nextStep['approver_admin_id'], json_encode(['request_id' => $requestId])]
            );
        }
    } catch (Exception $e) {
        error_log('Approval notification error: ' . $e->getMessage());
    }
}

Response::success(['final' => $result['final'], 'current_step' => $result['next_step'] ?? null]);
