<?php
// Step 1 of desktop sign-in: the user has just authenticated in their real
// browser (where passkeys work) and asks for a code to hand back to the app.
//
// Called from the web login page when it carries a ?desktop=<state> parameter.
// The caller is already authenticated, so the code is only ever minted for the
// account that is signed in right there in the browser.

require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());

$state = $auth['input']['state'] ?? null;
if (!is_string($state) || strlen($state) < 16 || strlen($state) > 128) {
    Response::fail('state غير صالح', 400);
}

// 32 bytes of entropy; the browser gets the plaintext, we keep only the hash.
$code = bin2hex(random_bytes(32));

// Housekeeping: this admin's spent and expired codes are of no further use.
Database::execute(
    "DELETE FROM desktop_auth_codes
     WHERE admin_id = ? AND (used_at IS NOT NULL OR expires_at <= NOW())",
    [$auth['admin_id']]
);

// The window is deliberately short — the browser redirects to the app the
// instant it has the code. Expiry is computed in SQL so PHP's UTC clock and
// MySQL's server zone cannot disagree and hand out a code that is born expired.
Database::execute(
    "INSERT INTO desktop_auth_codes
        (code_hash, state_hash, admin_id, firebase_uid, expires_at)
     VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 120 SECOND))",
    [hash('sha256', $code), hash('sha256', $state), $auth['admin_id'], $auth['uid']]
);

Response::success([
    'code' => $code,
    'expires_in_seconds' => 120,
]);
