<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$token = $input['token'] ?? null;
$code = trim((string) ($input['activation_code'] ?? ''));

if (!$token) Response::fail('Token is required', 400);
if ($code === '') Response::fail('Activation code is required', 422);

$verified = Auth::verifyFirebaseToken($token);
$firebaseUid = $verified->claims()->get('sub');
$email = $verified->claims()->get('email');

$codeRow = ActivationCodeModel::findByCode($code);
if (!$codeRow) {
    Response::fail('Invalid or expired code', 404);
}

$pdo = db();
try {
    $pdo->beginTransaction();

    Database::execute(
        "UPDATE employees SET status = 'active', updated_at = NOW() WHERE id = ?",
        [$codeRow['employee_id']]
    );

    ActivationCodeModel::markUsed((int) $codeRow['id'], $firebaseUid);

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log('Activation failed: ' . $e->getMessage());
    Response::fail('Activation failed', 500);
}

$employee = Database::fetchOne(
    "SELECT e.*, b.name as branch_name, t.name as tenant_name
     FROM employees e
     LEFT JOIN branches b ON b.id = e.branch_id
     LEFT JOIN tenants t ON t.id = e.tenant_id
     WHERE e.id = ? LIMIT 1",
    [$codeRow['employee_id']]
);

try {
    $empTenantId = (int) $employee['tenant_id'];
    $empBranchId = $employee['branch_id'] ? (int) $employee['branch_id'] : null;
    $recipients = SmartAlertService::recipientsForBranch($empTenantId, $empBranchId, 'manage_employees');
    foreach ($recipients as $rid) {
        SmartAlertService::dispatch(
            $rid, 'payroll_events', 'general',
            'موظف جديد مفعّل', "تم تفعيل حساب {$employee['name']}",
            'Employee Activated', "{$employee['name']} has been activated",
            ['employee_id' => (int) $employee['id'], 'employee_name' => $employee['name']],
            "emp_activate:{$codeRow['employee_id']}"
        );
    }
} catch (Throwable $e) {
    error_log('SmartAlert activate employee: ' . $e->getMessage());
}

Response::success([
    'success' => true,
    'employee' => [
        'id' => (int) $employee['id'],
        'name' => $employee['name'],
        'tenant_id' => (int) $employee['tenant_id'],
        'tenant_name' => $employee['tenant_name'],
        'branch_id' => $employee['branch_id'] ? (int) $employee['branch_id'] : null,
        'branch_name' => $employee['branch_name'],
        'job_title' => $employee['job_title'],
    ],
]);
