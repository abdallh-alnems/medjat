<?php
/**
 * Resolve an unknown face against the branch roster.
 *
 * The core of the feature, and the place where the trust model is enforced. The
 * tablet sends an **embedding**, never a verdict: a `matched: true` from a
 * device would be forged by a patched build, and unlike the employee app a
 * kiosk could forge it *for anybody in the branch*.
 *
 * A failed identification answers **200 with an `outcome`**, not 4xx. It is a
 * normal result of a normal interaction — somebody stood in front of a camera
 * and was not recognised — and the tablet must render it as guidance rather
 * than as an error.
 *
 * On success this returns a short-lived `punch_ticket` naming the resolved
 * employee. The punch step redeems that ticket instead of accepting an
 * `employee_id` from the client, so a tablet cannot identify as one person and
 * punch as another.
 *
 * Input: nonce, embedding[], model_version, liveness_passed, image,
 *        latitude, longitude
 */
require_once __DIR__ . '/../../config/bootstrap.php';
require_once __DIR__ . '/../../core/KioskIdentifier.php';
require_once __DIR__ . '/../../core/KioskCapture.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$kiosk = Auth::authenticateKiosk(db());

$tenantId  = $kiosk['tenant_id'];
$branchId  = $kiosk['branch_id'];
$stationId = $kiosk['station_id'];
$input     = $kiosk['input'];

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch || empty($branch['station_enabled'])) {
    Response::fail(I18n::t('kiosk_pair_branch_disabled'), 403, 'kiosk_pair_branch_disabled');
}

$faceSettings  = FaceMatchService::settingsFor($branch, $tenantId);
$matchSettings = KioskIdentifier::settingsFor($branch);
$enforce       = $faceSettings['enforce'];

$lat = isset($input['latitude'])  ? (float) $input['latitude']  : null;
$lng = isset($input['longitude']) ? (float) $input['longitude'] : null;

/**
 * Records the attempt and answers. Every exit from this endpoint goes through
 * here, so there is no path that identifies somebody without leaving a row —
 * FR-013 is structural rather than remembered.
 */
$finish = function (string $outcome, array $extra = []) use (
    $tenantId, $stationId, $branchId, $matchSettings, $lat, $lng, $branch
): void {
    $logId = StationRecognitionLogModel::record([
        'tenant_id'          => $tenantId,
        'station_id'         => $stationId,
        'branch_id'          => $branchId,
        'employee_id'        => $extra['employee_id'] ?? null,
        'purpose'            => 'check_in',
        'method'             => 'face',
        'result'             => $outcome,
        'accepted'           => $extra['accepted'] ?? false,
        'match_score'        => $extra['score'] ?? null,
        'runner_up_score'    => $extra['runner_up'] ?? null,
        'threshold'          => $matchSettings['threshold'],
        'margin'             => $matchSettings['margin'],
        'candidates_searched'=> $extra['candidates'] ?? null,
        'liveness_passed'    => $extra['liveness_passed'] ?? false,
        'challenge'          => $extra['challenge'] ?? null,
        'capture_path'       => $extra['capture_path'] ?? null,
        'latitude'           => $lat,
        'longitude'          => $lng,
    ], $extra['capture_ttl'] ?? null);

    if ($outcome === 'matched' && !empty($extra['accepted'])) {
        // The punch step reads the method and confidence back off this row
        // rather than trusting the tablet to restate them.
        Response::success($extra['payload'] + ['recognition_log_id' => $logId]);
    }

    Response::success([
        'outcome'     => $outcome,
        'message_key' => $extra['message_key'] ?? ('kiosk_' . $outcome),
        'code_fallback_available' => (bool) ($branch['station_code_fallback_enabled'] ?? 1),
    ]);
};

// ---- 1. Consume the nonce ---------------------------------------------------
// Single-use and checked in SQL, so a recorded capture cannot be replayed.
$nonce = (string) ($input['nonce'] ?? '');
if ($nonce === '') {
    Response::fail('nonce is required', 422, 'nonce_required');
}

$consumed = Database::execute(
    "UPDATE face_challenges SET consumed_at = NOW()
      WHERE nonce = ? AND tenant_id = ? AND consumed_at IS NULL AND expires_at > NOW()",
    [$nonce, $tenantId]
);
if ($consumed === 0) {
    Response::fail(I18n::t('kiosk_no_match'), 410, 'kiosk_nonce_spent');
}

$challengeRow = Database::fetchOne(
    "SELECT challenge FROM face_challenges WHERE nonce = ? LIMIT 1",
    [$nonce]
);
$challengeName = $challengeRow['challenge'] ?? null;

// ---- 2. Validate the probe --------------------------------------------------
$modelVersion = (string) ($input['model_version'] ?? '');
if ($modelVersion !== FaceMatchService::MODEL_VERSION) {
    // Embeddings from a different model live in a different space; comparing
    // across them yields numbers that look plausible and mean nothing.
    $finish('model_mismatch', ['challenge' => $challengeName, 'message_key' => 'kiosk_quality_low']);
}

$probe = FaceMatchService::parseEmbedding($input['embedding'] ?? null);
if ($probe === null) {
    $finish('bad_embedding', ['challenge' => $challengeName, 'message_key' => 'kiosk_quality_low']);
}

// ---- 3. Liveness ------------------------------------------------------------
$livenessPassed = !empty($input['liveness_passed']);
$livenessRequired = $faceSettings['liveness_required'] && !empty($branch['station_anti_spoofing_enabled']);

if ($livenessRequired && !$livenessPassed && $enforce) {
    // At an unattended tablet, holding up a colleague's photograph is the
    // obvious attack and there is no declared identity to contradict it.
    $capture = KioskCapture::store($input['image'] ?? null, $tenantId, $stationId);
    $finish('liveness_failed', [
        'challenge'    => $challengeName,
        'capture_path' => $capture,
        'capture_ttl'  => KioskCapture::ttlSeconds($tenantId),
        'message_key'  => 'kiosk_liveness_failed',
    ]);
}

// ---- 4. One-to-many ---------------------------------------------------------
$candidates = KioskIdentifier::candidatesFor($tenantId, $branchId, $modelVersion);
$decision = KioskIdentifier::identify(
    $probe,
    $candidates,
    $matchSettings['threshold'],
    $matchSettings['margin']
);

$common = [
    'score'           => $decision['score'],
    'runner_up'       => $decision['runner_up'],
    'candidates'      => $decision['candidates'],
    'liveness_passed' => $livenessPassed,
    'challenge'       => $challengeName,
];

if ($decision['outcome'] !== 'matched') {
    $finish($decision['outcome'], $common + [
        'message_key' => $decision['outcome'] === 'ambiguous' ? 'kiosk_ambiguous' : 'kiosk_no_match',
    ]);
}

$employeeId = $decision['employee_id'];
$employee = EmployeeModel::findById($employeeId, $tenantId);

// ---- 5. Post-identification checks -----------------------------------------
$methods = AttendanceMethodResolver::resolveForEmployee($employee, $tenantId);
if (!in_array('kiosk', $methods, true)) {
    $finish('wrong_method', $common + ['employee_id' => $employeeId, 'message_key' => 'kiosk_wrong_method']);
}

if ($lat !== null && $lng !== null) {
    $radius = (int) ($branch['station_gps_radius_meters'] ?? 30);
    $distance = GpsService::distanceInMeters(
        (float) $branch['latitude'], (float) $branch['longitude'], $lat, $lng
    );
    if ($distance > $radius) {
        // A kiosk is a fixed device: out of range means the tablet moved, not
        // that the employee did.
        $finish('out_of_range', $common + ['employee_id' => $employeeId, 'message_key' => 'kiosk_out_of_range']);
    }
}

$today = TenantClock::now($tenantId)->format('Y-m-d');
$existing = Database::fetchOne(
    "SELECT id, check_in_time, check_out_time FROM attendance
      WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
    [$employeeId, $today, $tenantId]
);

$nextAction = (!$existing || empty($existing['check_in_time'])) ? 'check_in' : 'check_out';

if ($nextAction === 'check_out' && !empty($existing['check_out_time'])) {
    $finish('too_soon', $common + ['employee_id' => $employeeId, 'message_key' => 'kiosk_too_soon']);
}

// ---- 6. Accept --------------------------------------------------------------
// log_only records the score without refusing anybody, the same tuning ramp
// face_selfie uses. `accepted` reflects whether enforcement was actually on.
$capture = KioskCapture::store($input['image'] ?? null, $tenantId, $stationId);
$ticket = bin2hex(random_bytes(32));

Database::execute(
    "INSERT INTO face_challenges (tenant_id, employee_id, nonce, challenge, purpose, expires_at)
     VALUES (?, ?, ?, 'blink', 'check_in', DATE_ADD(NOW(), INTERVAL 30 SECOND))",
    [$tenantId, $employeeId, $ticket]
);

$finish('matched', $common + [
    'employee_id'  => $employeeId,
    'accepted'     => true,
    'capture_path' => $capture,
    'capture_ttl'  => KioskCapture::ttlSeconds($tenantId),
    'payload'      => [
        'outcome'  => 'matched',
        'employee' => [
            'id'        => $employeeId,
            'name'      => $employee['name'],
            'photo_url' => $employee['face_photo_url'] ?? null,
        ],
        'next_action'   => $nextAction,
        'current_state' => [
            'checked_in_at' => $existing['check_in_time'] ?? null,
        ],
        'punch_ticket'  => $ticket,
        'ticket_expires_in_seconds' => 30,
        'enforced'      => $enforce,
    ],
]);
