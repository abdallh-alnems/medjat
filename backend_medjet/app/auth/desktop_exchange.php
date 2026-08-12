<?php
// Step 2 of desktop sign-in: the app received medjat://auth?code=…&state=… and
// trades the code for a Firebase custom token, which it exchanges for a real
// session through signInWithCustomToken — the same mechanism the support-desk
// impersonation link already uses.
//
// This endpoint is deliberately unauthenticated: the code *is* the credential.
// It is single-use, expires in two minutes, is stored only as a hash, and is
// bound to the state nonce the desktop app generated, so a code intercepted
// without that nonce is useless.

require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$code = $input['code'] ?? null;
$state = $input['state'] ?? null;

if (!is_string($code) || !is_string($state) || $code === '' || $state === '') {
    Response::fail('رمز الدخول غير مكتمل', 400);
}

$row = Database::fetchOne(
    "SELECT id, state_hash, firebase_uid
     FROM desktop_auth_codes
     WHERE code_hash = ? AND used_at IS NULL AND expires_at > NOW()
     LIMIT 1",
    [hash('sha256', $code)]
);

if (!$row || !hash_equals($row['state_hash'], hash('sha256', $state))) {
    Response::fail('انتهت صلاحية رمز الدخول أو استُخدم بالفعل', 401, 'desktop_code_invalid');
}

// Claim it before minting anything: the WHERE guard makes two racing requests
// resolve to exactly one winner.
$claimed = Database::execute(
    "UPDATE desktop_auth_codes SET used_at = NOW() WHERE id = ? AND used_at IS NULL",
    [(int) $row['id']]
);

if (!$claimed) {
    Response::fail('انتهت صلاحية رمز الدخول أو استُخدم بالفعل', 401, 'desktop_code_invalid');
}

try {
    $token = FirebaseInit::getAuth()->createCustomToken(
        (string) $row['firebase_uid'],
        ['desktop' => true]
    )->toString();
} catch (\Throwable $e) {
    error_log('Desktop sign-in token failed: ' . $e->getMessage());
    Response::fail('تعذّر إنشاء رمز الدخول', 500);
    return;
}

Response::success(['token' => $token]);
