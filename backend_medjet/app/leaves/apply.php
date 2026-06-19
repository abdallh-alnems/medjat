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

// An employee may keep at most two requests awaiting a manager's decision.
if (LeaveModel::countPendingForEmployee($employee['id'], $tenantId) >= 2) {
    Response::fail('لا يمكنك تقديم أكثر من طلبين قيد المراجعة', 422, 'leave_pending_limit');
}

$startDateInput = $input['start_date'] ?? $date;
$endDateInput = $input['end_date'] ?? $startDateInput;

// A leave cannot start in the past.
if ($startDateInput < date('Y-m-d')) {
    Response::fail('لا يمكن طلب إجازة بتاريخ ماضٍ', 422, 'leave_past_date');
}

if (LeaveModel::hasOverlap($employee['id'], $tenantId, $startDateInput, $endDateInput)) {
    Response::fail('يوجد تداخل مع إجازة قائمة في هذه الفترة', 409, 'leave_overlap');
}

// Annual leave cannot exceed the remaining yearly balance.
if ($type === 'annual') {
    $year = (int) date('Y', strtotime($startDateInput));
    $balance = LeaveModel::getBalance((int) $employee['id'], $tenantId, $year);
    $requestedDays = (int) round(
        (strtotime($endDateInput) - strtotime($startDateInput)) / 86400
    ) + 1;
    $remaining = (int) $balance['remaining_days'];
    if ($requestedDays > $remaining) {
        Response::fail(
            "رصيد إجازتك السنوية لا يكفي (المتبقي {$remaining} يوم، والطلب {$requestedDays} يوم)",
            422,
            'leave_balance_insufficient',
            ['remaining' => $remaining, 'days' => $requestedDays]
        );
    }
}

$leaveId = LeaveModel::apply($employee['id'], $tenantId, $date, $type, $reason, $startDateInput, $endDateInput);

ApprovalEngine::route($tenantId, 'leave', $leaveId, [
    'amount'         => null,
    'branch_id'      => $employee['branch_id'] ?? null,
    'by_employee_id' => $auth['employee_id'],
    'by_admin_id'    => null,
]);

$typeLabelsAr = [
    'annual'   => 'سنوية',
    'sick'     => 'مرضية',
    'personal' => 'شخصية',
    'unpaid'   => 'بدون راتب',
];
$typeAr = $typeLabelsAr[$type] ?? $type;

try {
    $recipients = SmartAlertService::recipientsForBranch($tenantId, $employee['branch_id'], 'manage_leaves');
    foreach ($recipients as $rid) {
        SmartAlertService::dispatch(
            $rid, 'leave_events', 'leave',
            'طلب إجازة جديد', "طلب إجازة جديدة من {$employee['name']} (إجازة {$typeAr})",
            'New Leave Request', "New leave request from {$employee['name']} ({$type})",
            ['leave_id' => $leaveId, 'employee_id' => $employee['id'], 'type' => $type],
            "leave:{$leaveId}"
        );
    }
} catch (Throwable $e) {
    error_log('SmartAlert leave apply: ' . $e->getMessage());
}

Response::success(['leave_id' => $leaveId, 'message' => 'Leave request submitted']);
