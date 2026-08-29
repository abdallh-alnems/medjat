<?php

declare(strict_types=1);

namespace App\Domain\Face;

use App\Domain\Attendance\AttendanceSecurityLog;
use App\Models\Branch;
use App\Models\Employee;
use App\Support\Value;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Scores a selfie attempt against the employee's enrolled face.
 *
 * The phone extracts the embedding; the server does the matching. A client that
 * reported its own verdict would be asking the thing under verification whether
 * it passed, so nothing here trusts an "accepted" flag from the request.
 *
 * Companies start in log_only: every attempt is scored and recorded, and nobody
 * is ever refused, so the threshold can be tuned against that company's own data
 * before it starts locking people out of their shift.
 */
final class FaceMatcher
{
    /**
     * Measured on 800 standard LFW pairs against the shipped mobilefacenet model
     * (2026-08-01): same-person cosine averaged 0.597, different-person 0.044.
     * At the earlier 0.650 the model rejected 52% of genuine pairs; 0.450 costs
     * 0.2% false accepts for 19% false rejects. LFW is harsher than a deliberate
     * check-in selfie, so expect better in the field — but tune per company from
     * face_verification_logs before switching to enforce.
     */
    public const DEFAULT_THRESHOLD = 0.450;

    /** Liveness challenges the server may ask for. */
    public const CHALLENGES = ['blink', 'turn_left', 'turn_right', 'smile'];

    /**
     * @param  array<array-key, mixed>  $input
     */
    public function verify(
        Employee $employee,
        int $tenantId,
        ?Branch $branch,
        string $purpose,
        array $input,
        ?float $latitude = null,
        ?float $longitude = null,
    ): FaceVerification {
        $settings = $this->settingsFor($branch, $tenantId);
        $threshold = $settings['threshold'];
        $branchId = $branch?->id;

        $context = new FaceLogContext($tenantId, $employee->id, $branchId, $purpose, $threshold, $latitude, $longitude, $input);

        // 1. The employee must actually be enrolled.
        $storedRaw = $employee->getAttribute('face_embedding');
        if ($storedRaw === null || $storedRaw === '') {
            $context->write('not_enrolled', false, null, false, null, null);

            return FaceVerification::refuse('not_enrolled', $threshold, 'لم يتم تسجيل بصمة الوجه لحسابك');
        }

        // 2. The stored vector must come from the model in use — comparing
        //    across models produces a number that means nothing.
        $storedVersion = Value::nullableString($employee->getAttribute('face_model_version'));
        if ($storedVersion !== null && $storedVersion !== FaceEmbedding::MODEL_VERSION) {
            $context->write('model_mismatch', false, null, false, null, null);

            return FaceVerification::refuse('model_mismatch', $threshold, 'يلزم إعادة تسجيل بصمة الوجه');
        }

        // 3. The single-use challenge. Without it a captured embedding could be
        //    submitted whenever its holder liked.
        $challenge = $this->consumeChallenge(Value::string($input['face_nonce'] ?? null), $tenantId, $employee->id, $purpose);
        if ($challenge === null) {
            $context->write('invalid_challenge', false, null, false, null, null);

            return FaceVerification::refuse('invalid_challenge', $threshold, 'انتهت صلاحية طلب التحقق، حاول مجدداً');
        }

        // 4. Liveness.
        $livenessPassed = (bool) ($input['liveness_passed'] ?? false);
        if ($settings['liveness_required'] && ! $livenessPassed) {
            $context->write('liveness_failed', false, null, false, $challenge, null);

            return FaceVerification::refuse('liveness_failed', $threshold, 'تعذّر التحقق من أن الصورة حية');
        }

        // 5. Both vectors must parse and be comparable.
        $candidate = FaceEmbedding::parse($input['face_embedding'] ?? null);
        $stored = FaceEmbedding::parse($storedRaw);

        if ($candidate === null || $stored === null || count($candidate) !== count($stored)) {
            $context->write('bad_embedding', false, null, $livenessPassed, $challenge, null);

            return FaceVerification::refuse('bad_embedding', $threshold, 'تعذّر التقاط الوجه، حاول مجدداً');
        }

        // 6. Has this employee sent these exact numbers before?
        //
        //    Runs before the score because the verdict does not depend on it: a
        //    replayed embedding scores exactly as well as it did the day it was
        //    captured, which is precisely why the score cannot catch this.
        $fingerprint = FaceEmbedding::fingerprint($candidate);
        $context->fingerprint = $fingerprint;

        if ($this->seenBefore($tenantId, $employee->id, $fingerprint)) {
            $enforceReplay = $this->replayEnforced($tenantId);

            AttendanceSecurityLog::record(
                $tenantId,
                $employee->id,
                $branchId,
                'replayed_embedding',
                $enforceReplay ? 'blocked' : 'flagged',
                $latitude,
                $longitude,
            );

            if ($enforceReplay) {
                $context->write('replayed_embedding', false, null, $livenessPassed, $challenge, null);

                return FaceVerification::refuse('replayed_embedding', $threshold, 'تم رصد محاولة إعادة استخدام');
            }

            // log_only: fall through and score normally. The pattern stays
            // visible through the security log without anyone being accused of
            // fraud on a signal nobody has tuned yet.
        }

        // 7. The decision.
        $score = FaceEmbedding::similarity($candidate, $stored);

        // The selfie is kept for audit only, never for matching. In log_only
        // mode it is the only way to review what a low score actually saw.
        $selfie = $this->storeAuditSelfie($input['image_base64'] ?? null, $tenantId, $employee->id);

        if ($score >= $threshold) {
            $context->write('matched', true, $score, $livenessPassed, $challenge, $selfie);

            return FaceVerification::accept('matched', $threshold, $score);
        }

        // Below the threshold: refused only once the company has left tuning
        // mode. The stored result is 'below_threshold' either way, so the audit
        // reads the same whether or not anybody was turned away.
        $accepted = ! $settings['enforce'];
        $context->write('below_threshold', $accepted, $score, $livenessPassed, $challenge, $selfie);

        return $accepted
            ? FaceVerification::accept('below_threshold', $threshold, $score)
            : FaceVerification::refuse('below_threshold', $threshold, 'لم يتم التعرف على الوجه', $score);
    }

    /**
     * Branch settings win over company ones: a warehouse and a head office do
     * not need the same strictness.
     *
     * @return array{threshold: float, liveness_required: bool, enforce: bool}
     */
    public function settingsFor(?Branch $branch, int $tenantId): array
    {
        $tenant = DB::table('tenants')->where('id', $tenantId)
            ->first(['face_match_threshold', 'face_liveness_required', 'face_enforce_mode']);

        $threshold = $tenant?->face_match_threshold;
        if ($branch !== null && $branch->getAttribute('face_match_threshold') !== null) {
            $threshold = $branch->getAttribute('face_match_threshold');
        }

        $liveness = $tenant === null ? 1 : $tenant->face_liveness_required;
        if ($branch !== null && $branch->getAttribute('face_liveness_required') !== null) {
            $liveness = $branch->getAttribute('face_liveness_required');
        }

        return [
            'threshold' => is_numeric($threshold) ? (float) $threshold : self::DEFAULT_THRESHOLD,
            'liveness_required' => Value::int($liveness, 1) === 1,
            'enforce' => Value::string($tenant?->face_enforce_mode, 'log_only') === 'enforce',
        ];
    }

    /** The challenge word, or null when the nonce is spent, expired or unknown. */
    private function consumeChallenge(string $nonce, int $tenantId, int $employeeId, string $purpose): ?string
    {
        if ($nonce === '') {
            return null;
        }

        // Claimed with the guard in the UPDATE so two racing requests cannot
        // both spend it, and expiry compared by the database's clock.
        $claimed = DB::update(
            'UPDATE face_challenges
                SET consumed_at = NOW()
              WHERE nonce = ? AND tenant_id = ? AND employee_id = ? AND purpose = ?
                AND consumed_at IS NULL AND expires_at > NOW()',
            [$nonce, $tenantId, $employeeId, $purpose]
        );

        if ($claimed < 1) {
            return null;
        }

        return Value::nullableString(DB::table('face_challenges')->where('nonce', $nonce)->value('challenge'));
    }

    private function seenBefore(int $tenantId, int $employeeId, string $fingerprint): bool
    {
        return DB::table('face_verification_logs')
            ->where('tenant_id', $tenantId)
            ->where('employee_id', $employeeId)
            ->where('embedding_hash', $fingerprint)
            ->exists();
    }

    private function replayEnforced(int $tenantId): bool
    {
        return Value::string(
            DB::table('tenants')->where('id', $tenantId)->value('face_replay_mode'),
            'log_only'
        ) === 'enforce';
    }

    private function storeAuditSelfie(mixed $imageBase64, int $tenantId, int $employeeId): ?string
    {
        if (! is_string($imageBase64) || $imageBase64 === '') {
            return null;
        }

        $data = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $imageBase64) ?? '', true);

        if ($data === false || $data === '' || @getimagesizefromstring($data) === false) {
            return null;
        }

        $path = sprintf('face_attempts/face_%d_%d_%d_%s.jpg', $tenantId, $employeeId, time(), bin2hex(random_bytes(4)));
        Storage::disk('uploads')->put($path, $data);

        return $path;
    }
}
