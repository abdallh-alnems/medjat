<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$input = $auth['input'];
$date = $input['date'] ?? null;
$type = $input['type'] ?? null;
$reason = $input['reason'] ?? null;

Validator::required($date, 'date');
Validator::required($type, 'type');
Validator::enum($type, ['annual', 'sick', 'personal', 'unpaid'], 'type');

$employee = EmployeeModel::findByUserId($auth['user_id'], $tenantId);
if (!$employee) {
    Response::fail('Employee profile not found', 404);
}

$leaveId = LeaveModel::apply($employee['id'], $tenantId, $date, $type, $reason);

Response::success(['leave_id' => $leaveId, 'message' => 'Leave request submitted']);
