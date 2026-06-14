<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());

// Single active session: clear the active device so the session row is clean
// and no stale device is treated as "logged in" until the next login.
Database::execute(
    "UPDATE admins SET active_device_id = NULL WHERE id = ?",
    [(int) $auth['admin_id']]
);

Response::success(['success' => true]);
