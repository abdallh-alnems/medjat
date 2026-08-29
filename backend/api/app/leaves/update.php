<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];

$input = $auth['input'];
$leaveId = (int) ($input['leave_id'] ?? $_GET['id'] ?? 0);
$type = $input['type'] ?? null;
$reason = $input['reason'] ?? null;
$startDate = $input['start_date'] ?? $input['date'] ?? null;
$endDate = $input['end_date'] ?? $startDate;

Validator::required($leaveId, 'leave_id');
Validator::required($type, 'type');
Validator::enum($type, ['annual', 'sick', 'personal', 'unpaid'], 'type');
Validator::required($startDate, 'start_date');
Validator::date($startDate, 'start_date');
Validator::date($endDate, 'end_date');

if (strtotime($endDate) < strtotime($startDate)) {
    Response::fail('تاريخ النهاية قبل تاريخ البداية', 422, 'invalid_date_range');
}

if ($startDate < date('Y-m-d')) {
    Response::fail('لا يمكن طلب إجازة بتاريخ ماضٍ', 422, 'leave_past_date');
}

$employee = $auth['employee'];

$leave = LeaveModel::findOwnedPending($leaveId, (int) $employee['id'], $tenantId);
if (!$leave) {
    Response::fail('لا يمكن تعديل هذا الطلب', 409, 'leave_not_editable');
}

if (LeaveModel::hasOverlap((int) $employee['id'], $tenantId, $startDate, $endDate, $leaveId)) {
    Response::fail('يوجد تداخل مع إجازة قائمة في هذه الفترة', 409, 'leave_overlap');
}

if ($type === 'annual') {
    $year = (int) date('Y', strtotime($startDate));
    $balance = LeaveModel::getBalance((int) $employee['id'], $tenantId, $year);
    $requestedDays = (int) round(
        (strtotime($endDate) - strtotime($startDate)) / 86400
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

LeaveModel::updateOwn($leaveId, (int) $employee['id'], $tenantId, $type, $startDate, $endDate, $reason);

Response::success(['message' => 'Leave request updated']);
