<?php
// Activate an employee account from a join link / QR code.
//
// The token is the secret: it is long, non-guessable and single-use, so unlike
// the manual phone+code path there is no phone to match — opening the link IS
// the proof. Consuming the row (used_at) invalidates the sibling `code` too.
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$token = trim((string) ($input['token'] ?? ''));
$deviceId = trim((string) ($input['device_id'] ?? ''));
$deviceModel = $input['device_model'] ?? null;
$platform = $input['platform'] ?? 'android';
$appVersion = $input['app_version'] ?? null;

if ($token === '' || $deviceId === '') {
    Response::fail('حقل مطلوب', 422, 'missing_fields');
}

if (!in_array($platform, ['android', 'ios'], true)) {
    $platform = 'android';
}

// --- Store-review demo QR ------------------------------------------------
// Mirrors the phone+code demo in employee_login.php: one configured token,
// encoded into a permanent demo QR, signs straight into the demo employee
// without consuming or expiring any activation row. This lets App Store /
// Google Play reviewers test the "Scan Join QR" flow on every submission.
// Inert in production unless REVIEW_DEMO_TOKEN and REVIEW_DEMO_PHONE are set.
$codeRow = null;
$isDemoLogin = false;
$demoToken = trim((string) getenv('REVIEW_DEMO_TOKEN'));
$demoPhone = trim((string) getenv('REVIEW_DEMO_PHONE'));

if ($demoToken !== '' && $demoPhone !== '' && hash_equals($demoToken, $token)) {
    $isDemoLogin = true;
    $demoCore = ltrim(preg_replace('/\D/', '', $demoPhone), '0');
    $employee = Database::fetchOne(
        "SELECT e.*, b.name as branch_name, t.name as tenant_name
         FROM employees e
         LEFT JOIN branches b ON b.id = e.branch_id
         LEFT JOIN tenants t ON t.id = e.tenant_id
         WHERE REPLACE(REPLACE(e.phone, '+', ''), ' ', '') LIKE ?
         ORDER BY e.id LIMIT 1",
        ['%' . $demoCore]
    );
    if (!$employee) {
        Response::fail('Demo account not configured', 404, 'join_link_invalid');
    }
} else {
    $codeRow = ActivationCodeModel::findByToken($token);
    if (!$codeRow) {
        Response::fail('رابط التفعيل غير صالح أو منتهي', 404, 'join_link_invalid');
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
        Response::fail('Employee not found', 404, 'join_link_invalid');
    }
}

if (($employee['status'] ?? '') === 'terminated') {
    Response::fail('الحساب موقوف', 403, 'account_suspended');
}

// Alert managers only on the first activation, not on later token logins.
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

    // Consuming this row also burns the sibling hand-typed code. The store-
    // review demo token consumes nothing, so the demo QR keeps working forever.
    if (!$isDemoLogin && $codeRow) {
        ActivationCodeModel::markUsedByDevice((int) $codeRow['id'], $deviceId);
    }

    $authToken = EmployeeAuthTokenModel::issue(
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
    error_log('Employee token activation failed: ' . $e->getMessage());
    Response::fail('تعذّر تسجيل الدخول', 500, 'login_failed');
}

// Notify the tenant's managers on every login (best-effort). The message
// distinguishes the first activation from a normal sign-in.
EmployeeActivationAlert::notify($employee, !$wasLinked);

Response::success([
    'success' => true,
    'token'   => $authToken,
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
