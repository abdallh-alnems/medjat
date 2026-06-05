<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];

$input     = $auth['input'];
$date      = $input['date'] ?? null;
$startTime = $input['start_time'] ?? null;
$endTime   = $input['end_time'] ?? null;
$type      = $input['type'] ?? 'break';
$reason    = $input['reason'] ?? null;

Validator::required($date, 'date');
Validator::date($date, 'date');
Validator::required($startTime, 'start_time');
Validator::time($startTime, 'start_time');
Validator::required($endTime, 'end_time');
Validator::time($endTime, 'end_time');
Validator::enum($type, ['break','permission','prayer','errand','medical','early_leave','other'], 'type');

$startTs = strtotime($date . ' ' . $startTime);
$endTs   = strtotime($date . ' ' . $endTime);
if ($endTs <= $startTs) {
    Response::fail('وقت النهاية يجب أن يكون بعد وقت البداية', 422, 'invalid_time_range');
}
$durationMinutes = (int) round(($endTs - $startTs) / 60);

if ($durationMinutes > 480) {
    Response::fail('مدة الإذن كبيرة جدًا', 422, 'duration_too_long');
}

if (BreakRequestModel::hasOverlap($employee['id'], $tenantId, $date, $startTime, $endTime)) {
    Response::fail('يوجد تداخل مع طلب إذن قائم في نفس الوقت', 409, 'break_overlap');
}

$id = BreakRequestModel::create(
    $tenantId, $employee['id'], $date, $startTime, $endTime, $durationMinutes, $type, $reason
);

try {
    $recipients = SmartAlertService::recipientsForBranch($tenantId, $employee['branch_id'] ?? null, 'manage_leaves');
    foreach ($recipients as $rid) {
        SmartAlertService::dispatch(
            $rid, 'break_events', 'break',
            'طلب إذن/استراحة جديد', "طلب إذن جديد من {$employee['name']} بتاريخ {$date} ({$startTime}–{$endTime})",
            'New break request', "New break request from {$employee['name']} on {$date} ({$startTime}–{$endTime})",
            ['break_id' => $id, 'employee_id' => $employee['id'], 'type' => $type],
            "break:{$id}"
        );
    }
} catch (Throwable $e) {
    error_log('SmartAlert break request: ' . $e->getMessage());
}

Response::success(['break_id' => $id, 'message' => 'Break request submitted']);
