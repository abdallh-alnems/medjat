<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true);

$firebaseToken = $input['token'] ?? null;

if ($firebaseToken) {
    $verifiedToken = Auth::verifyFirebaseToken($firebaseToken);
    $uid = $verifiedToken->claims()->get('sub');
    $email = $verifiedToken->claims()->get('email');
    $name = $verifiedToken->claims()->get('name');

    $admin = Database::fetchOne(
        "SELECT id, username, display_name, role, is_active, firebase_uid
         FROM super_admins
         WHERE firebase_uid = ? OR email = ? LIMIT 1",
        [$uid, $email]
    );

    if (!$admin) {
        Response::fail('Admin account not found', 404);
    }

    if (!$admin['is_active']) {
        Response::fail('Admin account disabled', 403);
    }

    if (!$admin['firebase_uid']) {
        Database::execute(
            "UPDATE super_admins SET firebase_uid = ? WHERE id = ?",
            [$uid, $admin['id']]
        );
    }

    $token = bin2hex(random_bytes(32));
    $hash = hash('sha256', $token);
    $expires = date('Y-m-d H:i:s', time() + AdminAuth::TOKEN_LIFETIME_HOURS * 3600);

    Database::execute(
        "INSERT INTO super_admin_sessions (admin_id, token_hash, expires_at, ip, user_agent) VALUES (?,?,?,?,?)",
        [$admin['id'], $hash, $expires, $_SERVER['REMOTE_ADDR'] ?? '', substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255)]
    );

    Database::execute(
        "UPDATE super_admins SET last_login_at = NOW(), last_login_ip = ? WHERE id = ?",
        [$_SERVER['REMOTE_ADDR'] ?? '', $admin['id']]
    );

    AdminAuth::logAction('auth.firebase_login', 'super_admin', $admin['id']);

    Response::success([
        'token' => $token,
        'expires_at' => $expires,
        'user' => [
            'id' => (int) $admin['id'],
            'name' => $admin['display_name'] ?? $admin['username'],
            'email' => $email,
            'role_key' => $admin['role'],
        ],
    ]);
} else {
    $username = $input['username'] ?? null;
    $password = $input['password'] ?? null;

    Validator::required($username, 'username');
    Validator::required($password, 'password');

    $ip = $_SERVER['REMOTE_ADDR'] ?? '';
    $ua = $_SERVER['HTTP_USER_AGENT'] ?? '';

    $result = AdminAuth::login($username, $password, $ip, $ua);

    Response::success($result);
}
