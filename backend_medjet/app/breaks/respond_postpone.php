<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];

$input  = $auth['input'];
$id     = (int) ($input['break_id'] ?? 0);
$action = $input['action'] ?? '';
Validator::required($id, 'break_id');
Validator::enum($action, ['accept', 'reject'], 'action');

$row = BreakRequestModel::find($id, $tenantId);
if (!$row || (int) $row['employee_id'] !== (int) $employee['id']) {
    Response::fail('الطلب غير موجود', 404, 'not_found');
}
if ($row['status'] !== 'postponed') {
    Response::fail('لا يوجد اقتراح وقت بديل لهذا الطلب', 409, 'not_postponed');
}

if ($action === 'accept') {
    if (empty($row['suggested_date']) || empty($row['suggested_start_time']) || empty($row['suggested_end_time'])) {
        Response::fail('لا يوجد وقت بديل مكتمل للموافقة عليه', 422, 'no_suggestion');
    }
    $startTs = strtotime($row['suggested_date'] . ' ' . $row['suggested_start_time']);
    $endTs   = strtotime($row['suggested_date'] . ' ' . $row['suggested_end_time']);
    if ($endTs < time()) {
        Response::fail('انتهى وقت الإذن البديل', 422, 'break_window_passed');
    }
    $duration = (int) round(($endTs - $startTs) / 60);
    $ok = BreakRequestModel::acceptPostpone($id, (int) $employee['id'], $tenantId, $duration);
    if (!$ok) Response::fail('تعذّر قبول الوقت البديل', 409, 'accept_failed');
    AuditLogModel::log($tenantId, null, 'break.postpone_accept', 'break', $id);
    Response::success(['message' => 'Suggested time accepted', 'status' => 'approved']);
}

$ok = BreakRequestModel::rejectPostpone($id, (int) $employee['id'], $tenantId);
if (!$ok) Response::fail('تعذّر رفض الوقت البديل', 409, 'reject_failed');
AuditLogModel::log($tenantId, null, 'break.postpone_reject', 'break', $id);
Response::success(['message' => 'Suggested time rejected', 'status' => 'cancelled']);
