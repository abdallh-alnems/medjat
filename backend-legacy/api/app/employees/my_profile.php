<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];

$employee = $auth['employee'];
// Return the full required-document checklist (resolved by scope: all / branch
// / category / explicit employee), including items not yet uploaded, so the
// employee sees what is required of them rather than an empty list.
$documents = DocumentModel::getEmployeeDocumentChecklist($employee['id'], $tenantId);
$leavesBalance = LeaveModel::getBalance($employee['id'], $tenantId, (int) date('Y'));

Response::success([
    'employee' => $employee,
    'documents' => $documents,
    'leave_balance' => $leavesBalance,
]);
