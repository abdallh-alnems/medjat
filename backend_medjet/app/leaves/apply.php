<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];

$input = $auth['input'];
$date = $input['date'] ?? null;
$type = $input['type'] ?? null;
$reason = $input['reason'] ?? null;

Validator::required($date, 'date');
Validator::required($type, 'type');
Validator::enum($type, ['annual', 'sick', 'personal', 'unpaid'], 'type');

$employee = $auth['employee'];

$startDateInput = $input['start_date'] ?? $date;
$endDateInput = $input['end_date'] ?? $startDateInput;

if (LeaveModel::hasOverlap($employee['id'], $tenantId, $startDateInput, $endDateInput)) {
    Response::fail('يوجد تداخل مع إجازة قائمة في هذه الفترة', 409, 'leave_overlap');
}

$leaveId = LeaveModel::apply($employee['id'], $tenantId, $date, $type, $reason, $startDateInput, $endDateInput);

try {
    $recipients = SmartAlertService::recipientsForBranch($tenantId, $employee['branch_id'], 'manage_leaves');
    foreach ($recipients as $rid) {
        SmartAlertService::dispatch(
            $rid, 'leave_events', 'leave',
            'طلب إجازة جديد', "طلب إجازة جديد من {$employee['name']} ({$type})",
            'New Leave Request', "New leave request from {$employee['name']} ({$type})",
            ['leave_id' => $leaveId, 'employee_id' => $employee['id'], 'type' => $type],
            "leave:{$leaveId}"
        );
    }
} catch (Throwable $e) {
    error_log('SmartAlert leave apply: ' . $e->getMessage());
}

Response::success(['leave_id' => $leaveId, 'message' => 'Leave request submitted']);
