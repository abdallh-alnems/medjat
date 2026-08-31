<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];

$id = (int) ($auth['input']['break_id'] ?? 0);
Validator::required($id, 'break_id');

$row = BreakRequestModel::find($id, $tenantId);
if (!$row || (int) $row['employee_id'] !== (int) $auth['employee']['id']) {
    Response::fail('الطلب غير موجود', 404, 'not_found');
}
if ($row['status'] !== 'pending') {
    Response::fail('لا يمكن إلغاء طلب تمّت معالجته', 409, 'not_pending');
}

BreakRequestModel::cancel($id, $auth['employee']['id'], $tenantId);
Response::success(['message' => 'Break request cancelled']);
