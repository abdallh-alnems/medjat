<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_leaves');

$input      = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$date       = $input['date'] ?? null;
$startTime  = $input['start_time'] ?? null;
$endTime    = $input['end_time'] ?? null;
$type       = trim((string) ($input['type'] ?? ''));
$reason     = $input['reason'] ?? null;
// Hourly salary deduction can be chosen at creation for any type; the approving
// manager can still change it at approval time.
$deductFromSalary = filter_var($input['deduct_from_salary'] ?? false, FILTER_VALIDATE_BOOLEAN);

Validator::required($employeeId, 'employee_id');
Validator::required($date, 'date');
Validator::date($date, 'date');
Validator::required($startTime, 'start_time');
Validator::time($startTime, 'start_time');
Validator::required($endTime, 'end_time');
Validator::time($endTime, 'end_time');
if (mb_strlen($type) > 100) {
    Response::fail('نوع الطلب طويل جدًا', 422, 'type_too_long');
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::fail('الموظف غير موجود', 404, 'employee_not_found');
}

$startTs = strtotime($date . ' ' . $startTime);
$endTs   = strtotime($date . ' ' . $endTime);
if ($endTs <= $startTs) {
    Response::fail('وقت النهاية يجب أن يكون بعد وقت البداية', 422, 'invalid_time_range');
}
$durationMinutes = (int) round(($endTs - $startTs) / 60);

if ($durationMinutes > 480) {
    Response::fail('مدة الإذن كبيرة جدًا', 422, 'duration_too_long');
}

// Can't create a permission whose window already ended.
if ($endTs < time()) {
    Response::fail('انتهى وقت الإذن، لا يمكن إنشاؤه', 422, 'break_window_passed');
}

if (BreakRequestModel::hasOverlap($employeeId, $tenantId, $date, $startTime, $endTime)) {
    Response::fail('يوجد تداخل مع طلب إذن قائم في نفس الوقت', 409, 'break_overlap');
}

$id = BreakRequestModel::create(
    $tenantId, $employeeId, $date, $startTime, $endTime, $durationMinutes, $type, $reason, $deductFromSalary
);
AuditLogModel::log($tenantId, $auth['admin_id'], 'break.create', 'break', $id);

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'break', 'New Permission', 'إذن جديد', 'A permission request was created for you.', 'تم إنشاء طلب إذن لك.', ?, 'in_app', NOW())",
        [$tenantId, $employeeId, json_encode(['break_id' => $id, 'action' => 'create'])]
    );
} catch (Exception $e) { error_log('Notification insert error: ' . $e->getMessage()); }

Response::success(['break_id' => $id, 'message' => 'Break request created']);
