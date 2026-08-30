<?php

/**
 * Ends the presenting browser session.
 *
 * POST, like every other write here — PUT and DELETE are not used anywhere in
 * this backend.
 *
 * Idempotent: logging out twice is a success. A second call arriving because the
 * employee double-tapped, or because the tab was restored, must not greet them
 * with an error on the way out.
 */

require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$token = WebSessionService::currentToken($input);

if ($token !== null) {
    WebSessionService::revokeCurrent($token, 'web_logout');
}

Response::success(['success' => true]);
