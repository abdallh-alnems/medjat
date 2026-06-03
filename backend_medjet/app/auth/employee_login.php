<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$phone = trim((string) ($input['phone'] ?? ''));
$code = strtoupper(trim((string) ($input['activation_code'] ?? '')));
$deviceId = trim((string) ($input['device_id'] ?? ''));
$deviceModel = $input['device_model'] ?? null;
$platform = $input['platform'] ?? 'android';
$appVersion = $input['app_version'] ?? null;

if ($phone === '' || $code === '' || $deviceId === '') {
    Response::fail('حقل مطلوب', 422);
}

if (!in_array($platform, ['android', 'ios'], true)) {
    $platform = 'android';
}

$codeRow = ActivationCodeModel::findByCode($code);
if (!$codeRow) {
    Response::fail('كود التفعيل غير صالح أو منتهي', 404);
}

$employee = Database::fetchOne(
    "SELECT e.*, b.name as branch_name, t.name as tenant_name
     FROM employees e
     LEFT JOIN branches b ON b.id = e.branch_id
     LEFT JOIN tenants t ON t.id = e.tenant_id
     WHERE e.id = ? AND e.tenant_id = ? LIMIT 1",
    [(int) $codeRow['employee_id'], (int) $codeRow['tenant_id']]
);

if (!$employee) {
    Response::fail('Employee not found', 404);
}

if (($employee['status'] ?? '') === 'terminated') {
    Response::fail('الحساب موقوف', 403);
}

// Phone is stored in E.164 (+201023809407) but a user might type it locally
// (01023809407). Compare on digits only and tolerate the local-zero ↔ country-
// code difference so a correct code is never rejected over formatting. The code
// is already the secret here — this check is just a sanity guard.
$inDigits = preg_replace('/\D/', '', $phone);
$dbDigits = preg_replace('/\D/', '', $employee['phone'] ?? '');
$inCore = ltrim($inDigits, '0');
$dbCore = ltrim($dbDigits, '0');
$phoneMatches = $inDigits === $dbDigits
    || ($inCore !== '' && $dbCore !== ''
        && (str_ends_with($dbCore, $inCore) || str_ends_with($inCore, $dbCore)));
if (!$phoneMatches) {
    Response::fail('رقم الهاتف لا يطابق كود التفعيل', 403);
}

// Whether the employee had already linked the app before this request. Used to
// alert managers only on the first activation, not on every subsequent login.
$wasLinked = ((int) ($employee['has_linked_account'] ?? 0)) === 1;

$pdo = db();
try {
    $pdo->beginTransaction();

    Database::execute(
        "UPDATE employees SET status = 'active', has_linked_account = 1, updated_at = NOW() WHERE id = ?",
        [(int) $employee['id']]
    );

    $adminId = $employee['admin_id'] ? (int) $employee['admin_id'] : null;
    if (!$adminId) {
        $existing = Database::fetchOne(
            "SELECT id FROM admins WHERE tenant_id = ? AND phone = ? AND role = 'employee' LIMIT 1",
            [(int) $employee['tenant_id'], $employee['phone']]
        );
        if ($existing) {
            $adminId = (int) $existing['id'];
        } else {
            $adminId = AdminModel::create([
                'firebase_uid' => 'employee:' . $employee['id'],
                'tenant_id'    => (int) $employee['tenant_id'],
                'branch_id'    => $employee['branch_id'] ? (int) $employee['branch_id'] : null,
                'name'         => $employee['name'],
                'phone'        => $employee['phone'],
                'role'         => 'employee',
            ]);
        }
        Database::execute(
            "UPDATE employees SET admin_id = ? WHERE id = ?",
            [$adminId, (int) $employee['id']]
        );
    }

    ActivationCodeModel::markUsedByDevice((int) $codeRow['id'], $deviceId);

    $token = EmployeeAuthTokenModel::issue(
        (int) $employee['tenant_id'],
        (int) $employee['id'],
        $deviceId,
        $deviceModel,
        $platform,
        $appVersion
    );

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log('Employee login failed: ' . $e->getMessage());
    Response::fail('تعذّر تسجيل الدخول', 500);
}

// Notify the tenant's managers on every login (best-effort). The message
// distinguishes the first activation from a normal sign-in.
EmployeeActivationAlert::notify($employee, !$wasLinked);

Response::success([
    'success' => true,
    'token'   => $token,
    'employee' => [
        'id'            => (int) $employee['id'],
        'name'          => $employee['name'],
        'phone'         => $employee['phone'],
        'tenant_id'     => (int) $employee['tenant_id'],
        'tenant_name'   => $employee['tenant_name'],
        'branch_id'     => $employee['branch_id'] ? (int) $employee['branch_id'] : null,
        'branch_name'   => $employee['branch_name'],
        'job_title'     => $employee['job_title'],
        'profile_image' => $employee['profile_image'] ?? null,
    ],
]);
