<?php
// Create a new company. Caller becomes the Owner.
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
    Response::fail('Token is required', 400);
}

$verifiedToken = Auth::verifyFirebaseToken($token);
$uid = $verifiedToken->claims()->get('sub');

$admin = Database::fetchOne(
    "SELECT id, tenant_id, name, email FROM admins WHERE firebase_uid = ? LIMIT 1",
    [$uid]
);
if (!$admin) {
    Response::fail('Sign in first', 401);
}
if ($admin['tenant_id']) {
    Response::fail('You already belong to a company', 409);
}

$companyName = trim($input['company_name'] ?? '');

if ($companyName === '') {
    Response::fail('Company name is required', 422);
}

$pdo = db();
try {
    $pdo->beginTransaction();

    $stmt = $pdo->prepare(
        "INSERT INTO tenants (name, owner_name, owner_email, plan, is_active, email_verified_at)
         VALUES (?, ?, ?, 'starter', 1, NOW())"
    );
    $stmt->execute([
        $companyName,
        $admin['name'],
        $admin['email'],
    ]);
    $tenantId = (int) $pdo->lastInsertId();

    $starterPlan = Database::fetchOne(
        "SELECT id FROM plans WHERE name = 'starter' LIMIT 1"
    );
    if ($starterPlan) {
        $stmt = $pdo->prepare(
            "INSERT INTO subscriptions (tenant_id, plan_id, start_date, end_date, status)
             VALUES (?, ?, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'trial')"
        );
        $stmt->execute([$tenantId, $starterPlan['id']]);
    }

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
    Response::fail('Failed to create company: ' . $e->getMessage(), 500);
}

$tenant = Database::fetchOne(
    "SELECT id, name, plan, currency, timezone FROM tenants WHERE id = ? LIMIT 1",
    [$tenantId]
);

Response::success([
    'success' => true,
    'tenant' => [
        'id' => (int) $tenant['id'],
        'name' => $tenant['name'],
        'plan' => $tenant['plan'],
        'currency' => $tenant['currency'],
        'timezone' => $tenant['timezone'],
    ],
    'user' => [
        'id' => (int) $admin['id'],
        'tenant_id' => $tenantId,
        'role' => 'general_manager',
        'role_key' => 'general_manager',
    ],
]);
