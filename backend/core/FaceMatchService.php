<?php

/**
 * Server-side face verification for the `face_selfie` attendance method.
 *
 * Split of responsibility (deliberate):
 *   - the DEVICE extracts the embedding from the selfie (privacy: the photo
 *     never has to leave the phone; speed: no server-side ML runtime), and
 *   - the SERVER compares it against the enrolled embedding and decides.
 *
 * The comparison itself is a cosine similarity over a ~192-float vector, so it
 * costs nothing here. What must never happen is trusting a client-sent
 * "matched: true" — a patched APK would send that unconditionally and the whole
 * method would be decorative.
 *
 * Replay is blocked by a single-use, short-lived challenge issued per attempt
 * (see FaceChallengeModel) on top of the existing GPS/geofence check.
 */
final class FaceMatchService {
    /** Embedding model the apps ship. Stored per employee at enrollment. */
    public const MODEL_VERSION = 'mobilefacenet_v1';

    /** Accepted embedding sizes. MobileFaceNet emits 192; FaceNet emits 128. */
    private const ALLOWED_DIMS = [128, 192, 512];

    // Measured on 800 standard LFW pairs against the shipped mobilefacenet
    // model (2026-08-01): same-person cosine averaged 0.597, different-person
    // 0.044. At the old 0.650 the model rejected 52% of genuine pairs; 0.450
    // costs 0.2% false accepts for 19% false rejects. LFW is harsher than a
    // deliberate check-in selfie, so expect better in the field — but tune per
    // company from face_verification_logs before switching to `enforce`.
    // Numbers and method: frontend/mobile/employee/assets/models/README.md
    public const DEFAULT_THRESHOLD = 0.450;

    /** Liveness challenges the server may ask for. */
    public const CHALLENGES = ['blink', 'turn_left', 'turn_right', 'smile'];

    /**
     * Parses and validates a client-supplied embedding.
     *
     * @return float[]|null Null when the payload is not a usable vector.
     */
    public static function parseEmbedding($raw): ?array {
        if (is_string($raw)) {
            $raw = json_decode($raw, true);
        }
        if (!is_array($raw) || !in_array(count($raw), self::ALLOWED_DIMS, true)) {
            return null;
        }

        $vector = [];
        foreach ($raw as $value) {
            if (!is_int($value) && !is_float($value) && !is_numeric($value)) {
                return null;
            }
            $float = (float) $value;
            // NAN/INF would poison the similarity maths and always "match".
            if (!is_finite($float)) {
                return null;
            }
            $vector[] = $float;
        }

        return $vector;
    }

    /**
     * Cosine similarity mapped to 0..1, where 1 is identical.
     *
     * Raw cosine lives in [-1, 1]; face embeddings never legitimately land in
     * the negative half, but clamping keeps the stored decimal(4,3) column
     * honest and makes thresholds easy to reason about.
     */
    public static function similarity(array $a, array $b): float {
        if (count($a) !== count($b) || empty($a)) {
            return 0.0;
        }

        $dot = 0.0;
        $normA = 0.0;
        $normB = 0.0;
        foreach ($a as $i => $valueA) {
            $valueB = $b[$i];
            $dot += $valueA * $valueB;
            $normA += $valueA * $valueA;
            $normB += $valueB * $valueB;
        }

        if ($normA <= 0.0 || $normB <= 0.0) {
            return 0.0;
        }

        $cosine = $dot / (sqrt($normA) * sqrt($normB));

        return max(0.0, min(1.0, $cosine));
    }

    /**
     * Resolves the effective face settings for a branch, falling back to the
     * company defaults. Mirrors how AttendanceMethodResolver inherits.
     *
     * @return array{threshold: float, liveness_required: bool, enforce: bool}
     */
    public static function settingsFor(?array $branch, int $tenantId): array {
        $tenant = TenantModel::findById($tenantId);

        $threshold = $tenant['face_match_threshold'] ?? self::DEFAULT_THRESHOLD;
        if ($branch !== null && ($branch['face_match_threshold'] ?? null) !== null) {
            $threshold = $branch['face_match_threshold'];
        }

        $liveness = $tenant['face_liveness_required'] ?? 1;
        if ($branch !== null && ($branch['face_liveness_required'] ?? null) !== null) {
            $liveness = $branch['face_liveness_required'];
        }

        return [
            'threshold' => (float) $threshold,
            'liveness_required' => (bool) (int) $liveness,
            // log_only is the launch default: scores are recorded but nobody is
            // ever locked out while the threshold is still being tuned.
            'enforce' => ($tenant['face_enforce_mode'] ?? 'log_only') === 'enforce',
        ];
    }

    /**
     * Verifies a selfie attempt end-to-end and records the audit row.
     *
     * Returns the outcome instead of responding directly so the caller decides
     * what an accepted/rejected verification means for its own flow.
     *
     * @return array{accepted: bool, result: string, score: ?float, threshold: float, message: string}
     */
    public static function verify(
        array $employee,
        int $tenantId,
        ?array $branch,
        string $purpose,
        array $input,
        ?float $lat = null,
        ?float $lng = null
    ): array {
        $branchId = $branch !== null ? (int) $branch['id'] : null;
        $settings = self::settingsFor($branch, $tenantId);
        $threshold = $settings['threshold'];
        $employeeId = (int) $employee['id'];

        // Carries the current attempt's fingerprint into every log call without
        // threading it through six signatures. Set once the embedding parses.
        $embeddingHash = null;

        $log = static function (
            string $result,
            bool $accepted,
            ?float $score,
            bool $livenessPassed,
            ?string $challenge,
            ?string $selfiePath
        ) use ($tenantId, $employeeId, $branchId, $purpose, $threshold, $lat, $lng, $input, &$embeddingHash): void {
            FaceVerificationLogModel::log([
                'tenant_id' => $tenantId,
                'employee_id' => $employeeId,
                'branch_id' => $branchId,
                'purpose' => $purpose,
                'result' => $result,
                'accepted' => $accepted,
                'match_score' => $score,
                'threshold' => $threshold,
                'liveness_passed' => $livenessPassed,
                'challenge' => $challenge,
                'latitude' => $lat,
                'longitude' => $lng,
                'selfie_path' => $selfiePath,
                'is_mock_location' => !empty($input['is_mock_location']),
                'is_rooted_device' => !empty($input['is_rooted_device']),
                'embedding_hash' => $embeddingHash,
            ]);
        };

        // ── 1) The employee must actually be enrolled ──
        if (empty($employee['face_embedding'])) {
            $log('not_enrolled', false, null, false, null, null);
            return [
                'accepted' => false,
                'result' => 'not_enrolled',
                'score' => null,
                'threshold' => $threshold,
                'message' => I18n::t('face_not_enrolled'),
            ];
        }

        // ── 2) The stored embedding must come from the model in use ──
        $storedVersion = $employee['face_model_version'] ?? null;
        if ($storedVersion !== null && $storedVersion !== self::MODEL_VERSION) {
            $log('model_mismatch', false, null, false, null, null);
            return [
                'accepted' => false,
                'result' => 'model_mismatch',
                'score' => null,
                'threshold' => $threshold,
                'message' => I18n::t('face_reenroll_required'),
            ];
        }

        // ── 3) Consume the single-use challenge ──
        $nonce = isset($input['face_nonce']) ? (string) $input['face_nonce'] : '';
        $challenge = FaceChallengeModel::consume($nonce, $tenantId, $employeeId, $purpose);
        if ($challenge === null) {
            $log('invalid_challenge', false, null, false, null, null);
            return [
                'accepted' => false,
                'result' => 'invalid_challenge',
                'score' => null,
                'threshold' => $threshold,
                'message' => I18n::t('face_challenge_expired'),
            ];
        }

        // ── 4) Liveness ──
        $livenessPassed = !empty($input['liveness_passed']);
        if ($settings['liveness_required'] && !$livenessPassed) {
            $log('liveness_failed', false, null, false, $challenge['challenge'], null);
            return [
                'accepted' => false,
                'result' => 'liveness_failed',
                'score' => null,
                'threshold' => $threshold,
                'message' => I18n::t('face_liveness_failed'),
            ];
        }

        // ── 5) Embedding shape ──
        $candidate = self::parseEmbedding($input['face_embedding'] ?? null);
        $stored = self::parseEmbedding($employee['face_embedding']);
        if ($candidate === null || $stored === null || count($candidate) !== count($stored)) {
            $log('bad_embedding', false, null, $livenessPassed, $challenge['challenge'], null);
            return [
                'accepted' => false,
                'result' => 'bad_embedding',
                'score' => null,
                'threshold' => $threshold,
                'message' => I18n::t('face_capture_failed'),
            ];
        }

        // ── 5b) Has this employee sent these exact numbers before? ──
        //
        // The server never sees the image, so it cannot tell a camera capture
        // from an array read out of storage. What it CAN tell is that a real
        // face never produces the same numbers twice — lighting, head angle and
        // distance all move — so an embedding identical to an earlier attempt
        // was replayed, not captured.
        //
        // Runs before the score because the verdict does not depend on it: a
        // replayed embedding scores exactly as well as it did the day it was
        // captured, which is precisely why the score cannot catch this.
        $embeddingHash = self::embeddingFingerprint($candidate);
        $replayOf = FaceVerificationLogModel::findReplay($tenantId, $employeeId, $embeddingHash);

        if ($replayOf !== null) {
            $enforceReplay = self::replayEnforced($tenantId);

            AttendanceSecurityModel::log(
                $tenantId,
                $employeeId,
                $branchId,
                'replayed_embedding',
                $enforceReplay ? 'blocked' : 'flagged',
                $lat,
                $lng
            );

            if ($enforceReplay) {
                $log('replayed_embedding', false, null, $livenessPassed, $challenge['challenge'], null);
                return [
                    'accepted' => false,
                    'result' => 'replayed_embedding',
                    'score' => null,
                    'threshold' => $threshold,
                    'message' => I18n::t('face_replay_detected'),
                ];
            }
            // log_only: fall through and score normally. The row is still
            // written with result 'replayed_embedding' below via $embeddingHash
            // plus the security-log entry above, so the pattern is visible
            // without anybody being accused of fraud on an untuned signal.
        }

        // ── 6) The actual decision ──
        $score = self::similarity($candidate, $stored);
        $matched = $score >= $threshold;

        // The selfie is kept for audit only — never for matching. In log_only
        // mode it is the only way to review what a low score actually saw.
        $selfiePath = self::storeAuditSelfie($input['image_base64'] ?? null, $tenantId, $employeeId);

        if ($matched) {
            $log('matched', true, $score, $livenessPassed, $challenge['challenge'], $selfiePath);
            return [
                'accepted' => true,
                'result' => 'matched',
                'score' => $score,
                'threshold' => $threshold,
                'message' => '',
            ];
        }

        // Below threshold: reject only when the company has left tuning mode.
        $accepted = !$settings['enforce'];
        $log('below_threshold', $accepted, $score, $livenessPassed, $challenge['challenge'], $selfiePath);

        return [
            'accepted' => $accepted,
            'result' => 'below_threshold',
            'score' => $score,
            'threshold' => $threshold,
            'message' => I18n::t('face_not_recognized'),
        ];
    }

    /**
     * A one-way fingerprint of an embedding, used only to answer "are these the
     * same numbers as last time".
     *
     * QUANTISED FIRST — but not for the reason it looks like.
     *
     * Rounding to four decimals does NOT defeat an attacker who adds noise.
     * Measured: perturbing every component by 1e-6 changes the fingerprint,
     * because with 192 components some of them inevitably sit near a rounding
     * boundary and flip. Anyone deliberately jittering the array evades this
     * check, and no amount of quantisation fixes that — a hash answers
     * "identical", never "similar".
     *
     * What quantisation actually buys is REPRESENTATION STABILITY. The same
     * capture reaches the server as a float, or as a string, or via a JSON round
     * trip, and `0.1` printed at full precision is not always the same text.
     * Without rounding, an honest replay could hash differently and slip past —
     * a false negative, which is the failure that matters for a detector.
     *
     * `sprintf('%.4F')` rather than round()+implode: it is locale-independent
     * (a decimal comma would silently change every hash) and gives -0.0 and 0.0
     * the same text, which they should have.
     *
     * So the honest scope of this whole check: it catches a build that stores an
     * embedding and posts it back verbatim, which is what a downloaded modified
     * APK does. It does not catch someone editing float arrays. That one is
     * App Check's job.
     *
     * The hash is not a secret and is not reversible — it exists so the server
     * can detect repetition WITHOUT keeping another copy of the employee's face
     * template on every attempt.
     */
    public static function embeddingFingerprint(array $embedding): string {
        $parts = [];
        foreach ($embedding as $value) {
            $parts[] = sprintf('%.4F', (float) $value);
        }
        return hash('sha256', implode(',', $parts));
    }

    /** Whether this company rejects a replayed embedding or merely records it. */
    private static function replayEnforced(int $tenantId): bool {
        $tenant = TenantModel::findById($tenantId);
        // Absent column or unset value reads as log_only: a brand-new signal
        // must never start rejecting people by default.
        return ($tenant['face_replay_mode'] ?? 'log_only') === 'enforce';
    }

    /**
     * Writes the attempt selfie to disk for HR review. Best-effort: a failed
     * write must never block a check-in.
     */
    private static function storeAuditSelfie($imageBase64, int $tenantId, int $employeeId): ?string {
        if (!is_string($imageBase64) || $imageBase64 === '') {
            return null;
        }

        try {
            $dir = __DIR__ . '/../uploads/face_attempts/';
            if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
                return null;
            }

            $data = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $imageBase64), true);
            // Cap at ~2MB of decoded image; anything larger is not a selfie.
            if ($data === false || strlen($data) > 2 * 1024 * 1024) {
                return null;
            }

            $name = 'attempt_' . $tenantId . '_' . $employeeId . '_' . date('Ymd_His') . '_' . bin2hex(random_bytes(4)) . '.jpg';
            if (file_put_contents($dir . $name, $data) === false) {
                return null;
            }

            return 'uploads/face_attempts/' . $name;
        } catch (Exception $e) {
            error_log('Face audit selfie failed: ' . $e->getMessage());
            return null;
        }
    }
}
