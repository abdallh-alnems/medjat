<?php
/**
 * Issue a single-use nonce and a liveness challenge, before the capture.
 *
 * Reuses `face_challenges`, with one difference from the selfie flow that the
 * migration had to make room for: `employee_id` is **NULL** here. The phone
 * knows whose face it is about to capture; a kiosk does not, and cannot — that
 * is the entire point of one-to-many.
 *
 * `expires_at` is computed in SQL. PHP runs UTC on this server while MySQL runs
 * the tenant zone, so a PHP-computed expiry is born hours in the past and every
 * challenge would be rejected as stale the moment it was issued.
 *
 * Input: purpose (punch|enroll)
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$kiosk = Auth::authenticateKiosk(db());

$purpose = ($kiosk['input']['purpose'] ?? 'punch') === 'enroll' ? 'enroll' : 'check_in';

$challenge = FaceMatchService::CHALLENGES[array_rand(FaceMatchService::CHALLENGES)];
$nonce = bin2hex(random_bytes(32));

Database::execute(
    "INSERT INTO face_challenges (tenant_id, employee_id, nonce, challenge, purpose, expires_at)
     VALUES (?, NULL, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 60 SECOND))",
    [$kiosk['tenant_id'], $nonce, $challenge, $purpose]
);

Response::success([
    'nonce'              => $nonce,
    'challenge'          => $challenge,
    'expires_in_seconds' => 60,
]);
