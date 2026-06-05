<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_leaves');

$in   = $auth['input'];
$id   = (int) ($in['break_id'] ?? 0);
$note = $in['note'] ?? null;
$sDate  = $in['suggested_date'] ?? null;
$sStart = $in['suggested_start_time'] ?? null;
$sEnd   = $in['suggested_end_time'] ?? null;
Validator::required($id, 'break_id');
if ($sDate  !== null) Validator::date($sDate, 'suggested_date');
if ($sStart !== null) Validator::time($sStart, 'suggested_start_time');
if ($sEnd   !== null) Validator::time($sEnd, 'suggested_end_time');

$row = BreakRequestModel::find($id, $tenantId);
if (!$row) Response::fail('الطلب غير موجود', 404, 'not_found');
if ($row['status'] !== 'pending') Response::fail('الطلب ليس قيد الانتظار', 409, 'not_pending');

BreakRequestModel::postpone($id, $tenantId, $auth['admin_id'], $note, $sDate, $sStart, $sEnd);
AuditLogModel::log($tenantId, $auth['admin_id'], 'break.postpone', 'break', $id);

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'break', 'Break Postponed', 'تم تأجيل الإذن', 'Your break request was postponed.', 'تم تأجيل طلب الإذن الخاص بك.', ?, 'in_app', NOW())",
        [$tenantId, $row['employee_id'], json_encode(['break_id' => $id, 'action' => 'postpone', 'suggested_date' => $sDate, 'suggested_start_time' => $sStart, 'suggested_end_time' => $sEnd])]
    );
} catch (Exception $e) { error_log('Notification insert error: ' . $e->getMessage()); }

Response::success(['message' => 'Break postponed']);
