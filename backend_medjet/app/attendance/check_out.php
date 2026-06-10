<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];

AttendanceModel::checkOut($employee['id'], $tenantId);

// Once the employee has left, any still-pending permission for today can no
// longer be acted on, so cancel it automatically.
$cancelledBreaks = BreakRequestModel::cancelPendingOnCheckOut($employee['id'], $tenantId);

Response::success([
    'message' => 'Check-out successful',
    'time' => date('H:i:s'),
    'cancelled_breaks' => $cancelledBreaks,
]);
