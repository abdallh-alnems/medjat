<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$id = (int) ($_GET['id'] ?? 0);
if ($id <= 0) {
    Response::fail('Employee ID is required', 422, 'employee_id_required');
}

$employee = EmployeeModel::findById($id, $tenantId);
if (!$employee) {
    Response::fail('Employee profile not found', 404, 'employee_profile_not_found');
}

// Lazily auto-reactivate if a definite suspension elapsed, then re-read so the
// returned status reflects the reactivation.
EmployeeSuspensionModel::reconcileExpired($tenantId, date('Y-m-d'));
$employee = EmployeeModel::findById($id, $tenantId) ?? $employee;

// ---- Strip credentials and biometric material -------------------------------
// EmployeeModel::findById selects `e.*`, so every column on the employees table
// reaches the client unless it is removed here.
//
//   face_embedding  is the raw biometric template the server matches against.
//                   A client never needs it — the phone extracts its own — and
//                   shipping it hands out the very thing an impersonation
//                   attack would otherwise have to produce.
//   kiosk_pin_hash  is the hash of a six-digit fallback code. Six digits is a
//                   one-million space; a hash in the wrong hands is a short
//                   offline search away from the code itself.
//
// Both are replaced by the booleans the UI actually wants, so no screen has a
// reason to ask for the originals.
if (!empty($employee['face_enrolled_by_station_id'])) {
    $station = Database::fetchOne(
        "SELECT name FROM attendance_stations WHERE id = ? AND tenant_id = ? LIMIT 1",
        [(int) $employee['face_enrolled_by_station_id'], $tenantId]
    );
    $employee['face_enrolled_station_name'] = $station['name'] ?? null;
}

$employee = EmployeeModel::scrubForClient($employee);

$documents = DocumentModel::getByEmployee($employee['id'], $tenantId);
$warnings = WarningModel::getByEmployee($employee['id'], $tenantId);
$activeSuspension = EmployeeSuspensionModel::getActiveForEmployee((int) $employee['id'], $tenantId);
$leavesBalance = LeaveModel::getBalance($employee['id'], $tenantId, (int) date('Y'));

$activationCode = null;
$activationExpiresAt = null;
if ($employee['status'] === 'pending_activation') {
    $codeRow = ActivationCodeModel::findActive((int) $employee['id']);
    $activationCode = $codeRow['code'] ?? null;
    $activationExpiresAt = isset($codeRow['expires_at'])
        ? gmdate('Y-m-d\TH:i:s\Z', strtotime($codeRow['expires_at']))
        : null;
}

$categories = EmployeeCategoryModel::getEmployeeCategories((int) $employee['id'], $tenantId);

// Effective attendance cycle start day: branch override, else company default.
$cycleRow = Database::fetchOne(
    "SELECT COALESCE(b.cycle_start_day, t.cycle_start_day, 1) AS cycle_start_day
     FROM tenants t
     LEFT JOIN branches b ON b.id = ? AND b.tenant_id = t.id
     WHERE t.id = ? LIMIT 1",
    [$employee['branch_id'] ?? 0, $tenantId]
);
$cycleStartDay = (int) ($cycleRow['cycle_start_day'] ?? 1);

Response::success([
    'employee' => $employee,
    'documents' => $documents,
    'warnings' => $warnings,
    'leave_balance' => $leavesBalance,
    'activation_code' => $activationCode,
    'expires_at' => $activationExpiresAt,
    'categories' => $categories,
    'cycle_start_day' => $cycleStartDay,
    'active_suspension' => $activeSuspension,
]);
