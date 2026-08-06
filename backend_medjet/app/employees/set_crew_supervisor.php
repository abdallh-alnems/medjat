<?php
/**
 * Assigns (or clears) the supervisor who may record this employee's attendance
 * on site.
 *
 * Administrator-only. This is the control that decides who gets the one
 * employee-credential exception in the codebase — an employee must never be
 * able to add themselves to somebody's crew, or grant themselves one.
 *
 * Input:  employee_id, supervisor_id (null to clear)
 * Output: message
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

// Absent key means "leave it alone"; an explicit null means "clear it". Those
// are different requests and a bare ?? would collapse them into one.
if (!array_key_exists('supervisor_id', $input)) {
    Response::fail('supervisor_id is required (send null to clear)', 422, 'supervisor_id_required');
}

$supervisorId = $input['supervisor_id'] === null ? null : (int) $input['supervisor_id'];

if ($supervisorId !== null) {
    if ($supervisorId <= 0) {
        Response::fail('supervisor_id must be a positive id or null', 422, 'supervisor_id_invalid');
    }

    // Tenant-scoped lookup: without it, an administrator could point their
    // employee at somebody in another company and the crew queries — which
    // filter on tenant — would then silently return nothing, looking like a
    // configuration that saved but does not work.
    $supervisor = EmployeeModel::findById($supervisorId, $tenantId);
    if (!$supervisor) {
        Response::notFound('Supervisor');
    }

    if (($supervisor['status'] ?? '') === 'terminated') {
        Response::fail(I18n::t('crew_supervisor_terminated'), 422, 'supervisor_terminated');
    }

    // The database cannot check this: the self-reference CHECK is refused by
    // MySQL 8 on a column carrying ON DELETE SET NULL, and a ring spans rows a
    // CHECK cannot see. See CrewModel::wouldCycle and the migration note.
    if (CrewModel::wouldCycle($supervisorId, $employeeId, $tenantId)) {
        Response::fail(I18n::t('crew_supervisor_cycle'), 422, 'supervisor_cycle');
    }
}

Database::execute(
    "UPDATE employees SET crew_supervisor_id = ? WHERE id = ? AND tenant_id = ?",
    [$supervisorId, $employeeId, $tenantId]
);

AuditLogModel::log($tenantId, $auth['admin_id'], 'employee.set_crew_supervisor', 'employee', $employeeId, [
    'supervisor_id' => $supervisorId,
]);

Response::success([
    'message' => I18n::t($supervisorId === null ? 'crew_supervisor_cleared' : 'crew_supervisor_set'),
]);
