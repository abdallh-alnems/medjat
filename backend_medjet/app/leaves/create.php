<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$type = $input['type'] ?? null;
$startDate = $input['start_date'] ?? null;
$endDate = $input['end_date'] ?? $startDate;
$reason = $input['reason'] ?? null;
$autoApprove = filter_var($input['auto_approve'] ?? false, FILTER_VALIDATE_BOOLEAN);
$onExceed = $input['on_exceed'] ?? 'split';

Validator::required($employeeId, 'employee_id');
Validator::required($type, 'type');
Validator::required($startDate, 'start_date');
Validator::enum($type, ['annual', 'sick', 'personal', 'unpaid'], 'type');
Validator::enum($onExceed, ['split', 'block'], 'on_exceed');

$endDate = $endDate ?? $startDate;

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

if (LeaveModel::hasOverlap($employeeId, $tenantId, $startDate, $endDate)) {
    Response::fail('يوجد تداخل مع إجازة قائمة في هذه الفترة', 409, 'leave_overlap');
}

if ($type === 'annual') {
    $year = (int) date('Y', strtotime($startDate));
    $balance = LeaveModel::getBalance($employeeId, $tenantId, $year);
    $remaining = $balance['remaining_days'];
    $requestedDays = (int) round((strtotime($endDate) - strtotime($startDate)) / 86400) + 1;

    if ($requestedDays > $remaining) {
        if ($onExceed === 'block') {
            Response::fail('رصيد الإجازات السنوية غير كافٍ', 422, 'balance_exceeded');
        }

        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            $paidDays = $remaining;
            $unpaidDays = $requestedDays - $remaining;
            $leaveId1 = null;

            if ($paidDays > 0) {
                $paidEndDate = date('Y-m-d', strtotime($startDate . ' + ' . ($paidDays - 1) . ' days'));
                $leaveId1 = LeaveModel::apply($employeeId, $tenantId, $startDate, 'annual', $reason, $startDate, $paidEndDate);
                if ($autoApprove) {
                    LeaveModel::approve($leaveId1, $tenantId, $auth['admin_id']);
                }
            }

            $unpaidStartDate = date('Y-m-d', strtotime($startDate . ' + ' . $paidDays . ' days'));
            $leaveId2 = LeaveModel::apply($employeeId, $tenantId, $unpaidStartDate, 'unpaid', $reason, $unpaidStartDate, $endDate);
            if ($autoApprove) {
                LeaveModel::approve($leaveId2, $tenantId, $auth['admin_id']);
            }

            $con->commit();

            AuditLogModel::log($tenantId, $auth['admin_id'], 'leave.create', 'leave', $leaveId1 ?? $leaveId2);

try {
    $recipients = SmartAlertService::recipientsForBranch($tenantId, $employee['branch_id'], 'manage_leaves');
    foreach ($recipients as $rid) {
        SmartAlertService::dispatch(
            $rid, 'leave_events', 'leave',
            'طلب إجازة جديد', "طلب إجازة جديد من {$employee['name']}",
            'New Leave Request', "New leave request from {$employee['name']}",
            ['leave_id' => $leaveId1 ?? $leaveId2, 'employee_id' => $employeeId, 'type' => $type],
            "leave:" . ($leaveId1 ?? $leaveId2)
        );
    }
} catch (Throwable $e) {
    error_log('SmartAlert leave create split: ' . $e->getMessage());
}

            Response::success([
                'warning' => 'balance_exceeded',
                'paid_days' => $paidDays,
                'unpaid_days' => $unpaidDays,
                'leaves' => [
                    ['id' => $leaveId1, 'type' => 'annual', 'status' => $autoApprove ? 'approved' : 'pending'],
                    ['id' => $leaveId2, 'type' => 'unpaid', 'status' => $autoApprove ? 'approved' : 'pending'],
                ],
            ]);
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }
    }
}

$leaveId = LeaveModel::apply($employeeId, $tenantId, $startDate, $type, $reason, $startDate, $endDate);

if ($autoApprove) {
    LeaveModel::approve($leaveId, $tenantId, $auth['admin_id']);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'leave.create', 'leave', $leaveId);

try {
    $recipients = SmartAlertService::recipientsForBranch($tenantId, $employee['branch_id'], 'manage_leaves');
    foreach ($recipients as $rid) {
        SmartAlertService::dispatch(
            $rid, 'leave_events', 'leave',
            'طلب إجازة جديد', "طلب إجازة جديد من {$employee['name']} ({$type})",
            'New Leave Request', "New leave request from {$employee['name']} ({$type})",
            ['leave_id' => $leaveId, 'employee_id' => $employeeId, 'type' => $type],
            "leave:{$leaveId}"
        );
    }
} catch (Throwable $e) {
    error_log('SmartAlert leave create: ' . $e->getMessage());
}

Response::success([
    'leave_id' => $leaveId,
    'status' => $autoApprove ? 'approved' : 'pending',
]);
