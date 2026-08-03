<?php
// Create a new company. The caller receives the highest role (general_manager).
// Companies have no owner — access is governed entirely by roles & permissions.
// Free tier for early adopters — no payment required for now.

require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    $input = [];
}

$token = $input['token'] ?? null;
if (!$token) {
    Response::fail('Token is required', 400, 'token_required');
}

$verifiedToken = Auth::verifyFirebaseToken($token);
$uid = $verifiedToken->claims()->get('sub');

$admin = Database::fetchOne(
    "SELECT id, tenant_id, name, email FROM admins WHERE firebase_uid = ? LIMIT 1",
    [$uid]
);
if (!$admin) {
    Response::fail('Sign in first', 401, 'sign_first');
}
if ($admin['tenant_id']) {
    Response::fail('You already belong to a company', 409, 'you_already_belong_company');
}

$companyName = trim($input['company_name'] ?? '');

if ($companyName === '') {
    Response::fail('Company name is required', 422, 'company_name_required');
}

// Locale settings are chosen during onboarding so the company never runs on a
// guessed default. All four stay optional: the app builds already in the stores
// send only company_name, and those companies must keep working — they simply
// fall back to the column defaults, exactly as before.
$timezone = null;
if (isset($input['timezone'])) {
    $timezone = trim((string) $input['timezone']);
    if (!in_array($timezone, timezone_identifiers_list(), true)) {
        Response::fail('Invalid timezone identifier', 422, 'invalid_timezone_identifier');
    }
}

$currency = null;
if (isset($input['currency'])) {
    $currency = strtoupper(trim((string) $input['currency']));
    if (!preg_match('/^[A-Z]{3}$/', $currency)) {
        Response::fail('currency must be a 3-letter ISO code (e.g. EGP)', 422, 'currency_3_letter_iso_code');
    }
}

$cycleStartDay = null;
if (isset($input['cycle_start_day'])) {
    $cycleStartDay = (int) $input['cycle_start_day'];
    if ($cycleStartDay < 1 || $cycleStartDay > 28) {
        Response::fail('cycle_start_day must be between 1 and 28', 422, 'cycle_start_day_between_1');
    }
}

$weekStartDay = null;
if (isset($input['week_start_day'])) {
    $weekStartDay = (int) $input['week_start_day'];
    if ($weekStartDay < 1 || $weekStartDay > 7) {
        Response::fail('week_start_day must be between 1 (Mon) and 7 (Sun)', 422, 'week_start_day_between_1');
    }
}

$pdo = db();
try {
    $pdo->beginTransaction();

    // Only the columns the admin actually supplied are written, so anything
    // omitted keeps its schema default instead of being overwritten with a
    // guess. `timezone_is_explicit` is what later tells the settings screen not
    // to re-suggest a timezone over a deliberate choice.
    $columns = ['name', 'is_active', 'email_verified_at'];
    $placeholders = ['?', '1', 'NOW()'];
    $values = [$companyName];

    if ($timezone !== null) {
        $columns[] = 'timezone';
        $placeholders[] = '?';
        $values[] = $timezone;
        $columns[] = 'timezone_is_explicit';
        $placeholders[] = '1';
    }
    if ($currency !== null) {
        $columns[] = 'currency';
        $placeholders[] = '?';
        $values[] = $currency;
    }
    if ($cycleStartDay !== null) {
        $columns[] = 'cycle_start_day';
        $placeholders[] = '?';
        $values[] = $cycleStartDay;
    }
    if ($weekStartDay !== null) {
        $columns[] = 'week_start_day';
        $placeholders[] = '?';
        $values[] = $weekStartDay;
    }

    $stmt = $pdo->prepare(
        'INSERT INTO tenants (' . implode(', ', $columns) . ')
         VALUES (' . implode(', ', $placeholders) . ')'
    );
    $stmt->execute($values);
    $tenantId = (int) $pdo->lastInsertId();

    $stmt = $pdo->prepare(
        "UPDATE admins
         SET tenant_id = ?, role = 'general_manager'
         WHERE id = ?"
    );
    $stmt->execute([$tenantId, $admin['id']]);

    $stmt = $pdo->prepare(
        "INSERT INTO audit_log (tenant_id, admin_id, action, target_type, target_id, ip)
         VALUES (?, ?, 'tenant.create', 'tenant', ?, ?)"
    );
    $stmt->execute([$tenantId, $admin['id'], $tenantId, $_SERVER['REMOTE_ADDR'] ?? '']);

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('Tenant create failed: ' . $e->getMessage());
    Response::fail('Failed to create company: ' . $e->getMessage(), 500, 'create_company_failed');
}

$tenant = Database::fetchOne(
    "SELECT id, name, currency, timezone, cycle_start_day, week_start_day FROM tenants WHERE id = ? LIMIT 1",
    [$tenantId]
);

Response::success([
    'success' => true,
    'tenant' => [
        'id' => (int) $tenant['id'],
        'name' => $tenant['name'],
        'currency' => $tenant['currency'],
        'timezone' => $tenant['timezone'],
        'cycle_start_day' => (int) $tenant['cycle_start_day'],
        'week_start_day' => (int) $tenant['week_start_day'],
    ],
    'user' => [
        'id' => (int) $admin['id'],
        'tenant_id' => $tenantId,
        'role' => 'general_manager',
        'role_key' => 'general_manager',
    ],
]);
