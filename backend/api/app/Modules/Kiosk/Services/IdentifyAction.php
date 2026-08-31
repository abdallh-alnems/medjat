<?php

declare(strict_types=1);

namespace App\Modules\Kiosk\Services;

use App\Exceptions\ApiFailure;
use App\Models\Branch;
use App\Models\Employee;
use App\Modules\Attendance\Domain\AttendanceMethod;
use App\Modules\Attendance\Domain\Geofence;
use App\Modules\Kiosk\Domain\KioskCapture;
use App\Modules\Kiosk\Domain\KioskIdentifier;
use App\Shared\Face\FaceEmbedding;
use App\Shared\Face\FaceMatcher;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * Resolving an unknown face against the branch roster.
 *
 * The core of the feature, and where the trust model is enforced. The tablet
 * sends an embedding, never a verdict: a "matched" from a device would be
 * forged by a patched build, and unlike the employee app a kiosk could forge it
 * for anybody in the branch.
 *
 * A failed identification is a normal outcome of a normal interaction —
 * somebody stood in front of a camera and was not recognised — so it comes back
 * as an outcome the tablet renders as guidance, not as an error.
 *
 * On success this issues a short-lived punch ticket naming the resolved
 * employee. The punch step redeems that instead of accepting an employee id
 * from the client, so a tablet cannot identify as one person and punch as
 * another.
 */
final class IdentifyAction
{
    /** Long enough to confirm on screen, short enough to be useless if intercepted. */
    private const TICKET_TTL_SECONDS = 30;

    public function __construct(private readonly FaceMatcher $faces) {}

    /**
     * @param  array<array-key, mixed>  $input
     * @return array{outcome: string, payload: array<string, mixed>, log: array<string, mixed>, capture_ttl: int|null}
     */
    public function execute(array $input, Branch $branch, int $tenantId, int $stationId): array
    {
        $branchId = $branch->id;
        $faceSettings = $this->faces->settingsFor($branch, $tenantId);
        $matchSettings = KioskIdentifier::settingsFor($branch);
        $enforce = $faceSettings['enforce'];

        $latitude = isset($input['latitude']) ? Value::float($input['latitude']) : null;
        $longitude = isset($input['longitude']) ? Value::float($input['longitude']) : null;

        $context = [
            'threshold' => $matchSettings['threshold'],
            'margin' => $matchSettings['margin'],
            'latitude' => $latitude,
            'longitude' => $longitude,
        ];

        // ── The nonce ────────────────────────────────────────────────────
        // Single-use and claimed in SQL, so a recorded capture cannot be
        // replayed at the door.
        //
        // A missing or spent nonce is refused rather than recorded as an
        // outcome: nobody was identified, so there is nothing to log about
        // them, and the recognition log's outcomes are a closed vocabulary that
        // this is not part of.
        $nonce = Value::string($input['nonce'] ?? null);

        if ($nonce === '') {
            throw new ApiFailure('nonce is required', 422, 'nonce_required');
        }

        $claimed = DB::update(
            'UPDATE face_challenges SET consumed_at = NOW()'
            .' WHERE nonce = ? AND tenant_id = ? AND consumed_at IS NULL AND expires_at > NOW()',
            [$nonce, $tenantId],
        );

        if ($claimed === 0) {
            throw new ApiFailure(__('messages.kiosk_no_match'), 410, 'kiosk_nonce_spent');
        }

        $challenge = Value::nullableString(
            DB::table('face_challenges')->where('nonce', $nonce)->value('challenge')
        );
        $context['challenge'] = $challenge;

        // ── The probe ────────────────────────────────────────────────────
        if (Value::string($input['model_version'] ?? null) !== FaceEmbedding::MODEL_VERSION) {
            // Embeddings from a different model live in a different space;
            // comparing across them yields numbers that look plausible and mean
            // nothing.
            return $this->outcome('model_mismatch', $context, ['message_key' => 'kiosk_quality_low']);
        }

        $probe = FaceEmbedding::parse($input['embedding'] ?? null);

        if ($probe === null) {
            return $this->outcome('bad_embedding', $context, ['message_key' => 'kiosk_quality_low']);
        }

        // ── Liveness ─────────────────────────────────────────────────────
        $livenessPassed = ! empty($input['liveness_passed']);
        $context['liveness_passed'] = $livenessPassed;

        $livenessRequired = $faceSettings['liveness_required']
            && Value::int($branch->getAttribute('station_anti_spoofing_enabled'), 1) === 1;

        if ($livenessRequired && ! $livenessPassed && $enforce) {
            // At an unattended tablet, holding up a colleague's photograph is
            // the obvious attack and there is no declared identity to
            // contradict it.
            return $this->outcome('liveness_failed', $context, [
                'message_key' => 'kiosk_liveness_failed',
                'capture_path' => KioskCapture::store($input['image'] ?? null, $tenantId, $stationId),
                'capture_ttl' => KioskCapture::ttlSeconds($tenantId),
            ]);
        }

        // ── One to many ──────────────────────────────────────────────────
        $decision = KioskIdentifier::identify(
            $probe,
            KioskIdentifier::candidatesFor($tenantId, $branchId, FaceEmbedding::MODEL_VERSION),
            $matchSettings['threshold'],
            $matchSettings['margin'],
        );

        $context['score'] = $decision['score'];
        $context['runner_up'] = $decision['runner_up'];
        $context['candidates_searched'] = $decision['candidates'];

        if ($decision['outcome'] !== 'matched') {
            return $this->outcome($decision['outcome'], $context, [
                'message_key' => $decision['outcome'] === 'ambiguous' ? 'kiosk_ambiguous' : 'kiosk_no_match',
            ]);
        }

        $employeeId = (int) $decision['employee_id'];
        $employee = Employee::query()->where('id', $employeeId)->where('tenant_id', $tenantId)->first();

        if ($employee === null) {
            return $this->outcome('no_match', $context, ['message_key' => 'kiosk_no_match']);
        }

        $context['employee_id'] = $employeeId;

        // ── The same gates every other channel applies ───────────────────
        if (! in_array('kiosk', AttendanceMethod::resolveFor($employee, $tenantId), true)) {
            return $this->outcome('wrong_method', $context, ['message_key' => 'kiosk_wrong_method']);
        }

        if ($latitude !== null && $longitude !== null && ! $this->withinRange($branch, $latitude, $longitude)) {
            // A kiosk is a fixed device: out of range means the tablet moved,
            // not that the employee did.
            return $this->outcome('out_of_range', $context, ['message_key' => 'kiosk_out_of_range']);
        }

        $today = TenantClock::date($tenantId);
        $existing = DB::table('attendance')
            ->where('employee_id', $employeeId)->where('date', $today)->where('tenant_id', $tenantId)
            ->first(['id', 'check_in_time', 'check_out_time']);

        $checkedIn = $existing !== null && Value::string($existing->check_in_time) !== '';
        $nextAction = $checkedIn ? 'check_out' : 'check_in';

        if ($nextAction === 'check_out' && $existing !== null && Value::string($existing->check_out_time) !== '') {
            return $this->outcome('too_soon', $context, ['message_key' => 'kiosk_too_soon']);
        }

        // ── Accept ───────────────────────────────────────────────────────
        // log_only records the score without refusing anybody, the same tuning
        // ramp the selfie path uses. Whether enforcement was actually on is
        // recorded rather than assumed.
        $ticket = $this->issueTicket($tenantId, $employeeId);

        return $this->outcome('matched', $context + [
            'accepted' => true,
            'capture_path' => KioskCapture::store($input['image'] ?? null, $tenantId, $stationId),
            'capture_ttl' => KioskCapture::ttlSeconds($tenantId),
        ], [
            'payload' => [
                'outcome' => 'matched',
                'employee' => [
                    'id' => $employeeId,
                    'name' => $employee->name,
                    'photo_url' => $employee->getAttribute('face_photo_url'),
                ],
                'next_action' => $nextAction,
                'current_state' => ['checked_in_at' => $existing->check_in_time ?? null],
                'punch_ticket' => $ticket,
                'ticket_expires_in_seconds' => self::TICKET_TTL_SECONDS,
                'enforced' => $enforce,
            ],
        ]);
    }

    private function withinRange(Branch $branch, float $latitude, float $longitude): bool
    {
        $branchLatitude = $branch->getAttribute('latitude');
        $branchLongitude = $branch->getAttribute('longitude');

        // A branch without coordinates cannot be geofenced, and refusing every
        // punch there would take the kiosk out of service over a missing
        // setting.
        if (! is_numeric($branchLatitude) || ! is_numeric($branchLongitude)) {
            return true;
        }

        $radius = Value::int($branch->getAttribute('station_gps_radius_meters'), 30);
        $distance = Geofence::metresBetween(
            (float) $branchLatitude, (float) $branchLongitude, $latitude, $longitude
        );

        return $distance <= $radius;
    }

    /**
     * The ticket is a face challenge row: single-use, short-lived, and already
     * claimed atomically by the punch step, so it needs no second mechanism.
     */
    private function issueTicket(int $tenantId, int $employeeId): string
    {
        $ticket = bin2hex(random_bytes(32));

        DB::insert(
            'INSERT INTO face_challenges (tenant_id, employee_id, nonce, challenge, purpose, expires_at)'
            ." VALUES (?, ?, ?, 'blink', 'check_in', DATE_ADD(NOW(), INTERVAL ? SECOND))",
            [$tenantId, $employeeId, $ticket, self::TICKET_TTL_SECONDS],
        );

        return $ticket;
    }

    /**
     * Every exit goes through here, so there is no path that identifies
     * somebody without leaving a row.
     *
     * @param  array<string, mixed>  $context
     * @param  array<string, mixed>  $extra
     * @return array{outcome: string, payload: array<string, mixed>, log: array<string, mixed>, capture_ttl: int|null}
     */
    private function outcome(string $outcome, array $context, array $extra): array
    {
        $log = $context + [
            'result' => $outcome,
            'method' => 'face',
            'purpose' => 'check_in',
            'capture_path' => $extra['capture_path'] ?? null,
        ];

        $payload = $extra['payload'] ?? null;

        if (! is_array($payload)) {
            $payload = [
                'outcome' => $outcome,
                'message_key' => Value::string($extra['message_key'] ?? null) ?: 'kiosk_'.$outcome,
            ];
        }

        /** @var array<string, mixed> $payload */

        return [
            'outcome' => $outcome,
            'payload' => $payload,
            'log' => $log,
            'capture_ttl' => isset($extra['capture_ttl']) ? Value::int($extra['capture_ttl']) : null,
        ];
    }
}
