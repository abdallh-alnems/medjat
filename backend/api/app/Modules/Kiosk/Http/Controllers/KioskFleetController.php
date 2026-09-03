<?php

declare(strict_types=1);

namespace App\Modules\Kiosk\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Kiosk\Domain\KioskCapture;
use App\Modules\Kiosk\Domain\KioskEmployeeCode;
use App\Modules\Kiosk\Domain\KioskIdentifier;
use App\Modules\Kiosk\Domain\KioskStation;
use App\Modules\Kiosk\Domain\RecognitionLog;
use App\Shared\Http\ApiResponse;
use App\Shared\RemoteConfig\RemoteConfigGate;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Ports of api/app/kiosk/{list,set_pin,recognition_logs,capture}.php.
 *
 * The management app's view of the fleet: which tablets are alive, which would
 * stop working if the minimum version were raised, how identification is
 * actually performing, and the evidence behind a disputed punch.
 */
final class KioskFleetController
{
    public function __construct(private readonly RemoteConfigGate $gate) {}

    /**
     * Surfaces two things that are otherwise discovered from support calls:
     * which stations a version bump would take offline, and which branches have
     * grown past the roster size one-to-many identification can hold.
     */
    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = Value::int($request->input('branch_id')) ?: null;

        if ($branchId !== null && ! self::branchExists($branchId, $tenantId)) {
            throw new ApiFailure(__('messages.branch_not_found'), 404, 'not_found');
        }

        $gate = $this->gate->forApp('permedjat_kiosk');
        $stations = [];
        $wouldBlock = 0;

        foreach (KioskStation::listForTenant($tenantId, $branchId) as $station) {
            $version = Value::nullableString($station['app_version'] ?? null);

            // A null version means it was paired before it ever reported one;
            // treated as current rather than as broken, so a fresh pairing is
            // not flagged.
            $belowMinimum = $version !== null && $gate->isBelowMinimum($version);
            $status = Value::string($station['status'] ?? null);

            if ($belowMinimum && $status === 'active') {
                $wouldBlock++;
            }

            $stations[] = [
                'id' => Value::int($station['id'] ?? null),
                'name' => $station['name'] ?? null,
                'status' => $status,
                'branch' => [
                    'id' => Value::int($station['branch_id'] ?? null),
                    'name' => $station['branch_name'] ?? null,
                ],
                'device_model' => $station['device_model'] ?? null,
                'app_version' => $version,
                'below_min_version' => $belowMinimum,
                'last_seen_at' => $station['last_seen_at'] ?? null,
                'is_offline' => Value::int($station['is_offline'] ?? null) === 1,
                'punch_count' => Value::int($station['punch_count'] ?? null),
                'last_punch_at' => $station['last_punch_at'] ?? null,
                'paired_at' => $station['paired_at'] ?? null,
                'revoked_at' => $station['revoked_at'] ?? null,
            ];
        }

        return ApiResponse::success([
            'stations' => $stations,
            'min_version' => $gate->minVersion,
            // Surfaced explicitly so the screen can warn before anybody raises
            // the minimum version: a directly-installed kiosk has no store to
            // be sent to, so somebody must physically visit each tablet.
            'would_block_count' => $wouldBlock,
            'version_gate_stale' => $gate->stale,
            'rosters' => $this->rosters($tenantId, $branchId),
        ]);
    }

    /**
     * Issues the personal fallback code. Shown once and not recoverable
     * afterwards; a reset invalidates the previous code immediately, because
     * the usual reason to reset is that the old one was shared.
     */
    public function setPin(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->input('employee_id'));

        $employee = DB::table('employees')
            ->where('id', $employeeId)->where('tenant_id', $tenantId)
            ->first(['id', 'name', 'branch_id', 'kiosk_pin_hash']);

        if ($employee === null) {
            throw new ApiFailure(__('messages.employee_not_found'), 404, 'not_found');
        }

        $branchId = Value::int($employee->branch_id);

        if ($branchId <= 0) {
            throw new ApiFailure(
                __('messages.kiosk_code_without_branch'),
                422,
                'employee_without_branch',
            );
        }

        if ($request->boolean('clear')) {
            KioskEmployeeCode::clearFor($employeeId, $tenantId);

            return ApiResponse::success([
                'employee_id' => $employeeId,
                'cleared' => true,
                'has_code' => false,
            ]);
        }

        return ApiResponse::success([
            'employee_id' => $employeeId,
            'name' => $employee->name,
            'code' => KioskEmployeeCode::issueFor($employeeId, $tenantId, $branchId),
            'replaced_previous' => $employee->kiosk_pin_hash !== null,
            'has_code' => true,
        ]);
    }

    /**
     * Attempts and scores, for tuning. The capture path is deliberately absent:
     * scores and outcomes are attendance data, and the image behind them is
     * biometric evidence that costs a different permission.
     */
    public function recognitionLogs(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = Value::int($request->input('branch_id')) ?: null;

        if ($branchId !== null && ! self::branchExists($branchId, $tenantId)) {
            throw new ApiFailure(__('messages.branch_not_found'), 404, 'not_found');
        }

        if (Value::string($request->input('view'), 'list') === 'distribution') {
            return $this->distribution($tenantId, $branchId);
        }

        $logs = RecognitionLog::search($tenantId, [
            'branch_id' => $branchId,
            'station_id' => Value::int($request->input('station_id')) ?: null,
            'result' => Value::string($request->input('result')) ?: null,
            'date_from' => Value::string($request->input('date_from')) ?: null,
            'date_to' => Value::string($request->input('date_to')) ?: null,
        ], min(500, max(1, Value::int($request->input('limit'), 100))));

        return ApiResponse::success([
            'view' => 'list',
            'logs' => array_map(static function (array $log): array {
                $score = is_numeric($log['match_score'] ?? null) ? (float) $log['match_score'] : null;
                $runnerUp = is_numeric($log['runner_up_score'] ?? null) ? (float) $log['runner_up_score'] : null;

                return [
                    'id' => Value::int($log['id'] ?? null),
                    'created_at' => $log['created_at'] ?? null,
                    'branch' => ['id' => Value::int($log['branch_id'] ?? null), 'name' => $log['branch_name'] ?? null],
                    'station' => ['id' => Value::int($log['station_id'] ?? null), 'name' => $log['station_name'] ?? null],
                    'employee' => $log['employee_id'] === null ? null : [
                        'id' => Value::int($log['employee_id']),
                        'name' => $log['employee_name'] ?? null,
                    ],
                    'purpose' => $log['purpose'] ?? null,
                    'method' => $log['method'] ?? null,
                    'result' => $log['result'] ?? null,
                    'accepted' => Value::int($log['accepted'] ?? null) === 1,
                    'match_score' => $score,
                    'runner_up' => $runnerUp,
                    // The gap is what the margin rule is set from, so it is
                    // computed here rather than left to the reader.
                    'margin_gap' => $score !== null && $runnerUp !== null ? round($score - $runnerUp, 3) : null,
                    'threshold' => is_numeric($log['threshold'] ?? null) ? (float) $log['threshold'] : null,
                    'margin' => is_numeric($log['margin'] ?? null) ? (float) $log['margin'] : null,
                    'candidates' => Value::nullableInt($log['candidates_searched'] ?? null),
                    'liveness_passed' => Value::int($log['liveness_passed'] ?? null) === 1,
                    'attendance_id' => Value::nullableInt($log['attendance_id'] ?? null),
                    // Whether an image exists, not the image itself.
                    'has_capture' => Value::int($log['has_capture'] ?? null) === 1,
                ];
            }, $logs),
        ]);
    }

    /**
     * The capture behind one attempt.
     *
     * With one-to-many identification nobody declared who they were, so this
     * image is the only thing that can settle "that was not me" — and for the
     * same reason it is the most sensitive artefact the feature produces, which
     * is why every access is written to the audit log.
     */
    public function capture(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $logId = Value::int($request->input('recognition_log_id'));

        $log = DB::table('station_recognition_logs')
            ->where('id', $logId)->where('tenant_id', $tenantId)
            ->first(['id', 'branch_id', 'employee_id', 'capture_path', 'capture_expires_at', 'created_at']);

        if ($log === null) {
            throw new ApiFailure(__('messages.recognition_attempt_not_found'), 404, 'not_found');
        }

        $storedPath = Value::string($log->capture_path);
        $relative = $storedPath === '' ? null : KioskCapture::relativePath($storedPath);

        // Either the retention window passed and the purge ran, or the attempt
        // was one whose capture is deliberately not kept. Saying so plainly
        // beats returning a broken image.
        if ($relative === null || ! Storage::disk('uploads')->exists($relative)) {
            throw new ApiFailure(__('messages.capture_no_longer_available'), 410, 'kiosk_capture_expired', [
                'expired_at' => $log->capture_expires_at,
            ]);
        }

        // Viewing another person's biometric evidence is itself an auditable act.
        AuditLog::record($tenantId, $adminId, 'kiosk_capture_view', 'station_recognition_log', $logId, [
            'employee_id' => $log->employee_id,
            'branch_id' => $log->branch_id,
            'attempt_at' => $log->created_at,
        ]);

        return ApiResponse::success([
            'recognition_log_id' => $logId,
            'employee_id' => Value::nullableInt($log->employee_id),
            'captured_at' => $log->created_at,
            'expires_at' => $log->capture_expires_at,
            // Inline rather than a static URL: the uploads directory is not
            // web-served, and a guessable path would defeat the permission this
            // endpoint enforces.
            'image_base64' => 'data:image/jpeg;base64,'.base64_encode(
                Value::string(Storage::disk('uploads')->get($relative))
            ),
        ]);
    }

    private function distribution(int $tenantId, ?int $branchId): JsonResponse
    {
        $buckets = RecognitionLog::distribution($tenantId, $branchId);

        // The two numbers a threshold is actually chosen between: genuine
        // matches should cluster high and everything else low, and where they
        // stop overlapping is the operating point.
        $matched = 0;
        $rejected = 0;

        foreach ($buckets as $bucket) {
            $attempts = Value::int($bucket['attempts'] ?? null);

            if (Value::string($bucket['result'] ?? null) === 'matched') {
                $matched += $attempts;
            } else {
                $rejected += $attempts;
            }
        }

        return ApiResponse::success([
            'view' => 'distribution',
            'buckets' => $buckets,
            'summary' => [
                'matched_attempts' => $matched,
                'rejected_attempts' => $rejected,
                'current_defaults' => [
                    'threshold' => KioskIdentifier::DEFAULT_THRESHOLD,
                    'margin' => KioskIdentifier::DEFAULT_MARGIN,
                ],
            ],
            // A reminder rather than a number: these figures are only
            // meaningful once a branch has produced a few thousand attempts.
            'note_key' => 'kiosk_tuning_needs_volume',
        ]);
    }

    /**
     * How many faces each active branch is matching against.
     *
     * False-accept risk compounds across the roster, so there is a branch size
     * beyond which no threshold holds the target mis-attribution rate. Reported
     * rather than enforced: refusing to serve a branch that grew would be worse
     * than telling its administrator that face-only identification has reached
     * its limit and the personal code should carry more of the load.
     *
     * @return list<array<string, mixed>>
     */
    private function rosters(int $tenantId, ?int $branchId): array
    {
        $rows = DB::table('attendance_stations as s')
            ->join('branches as b', 'b.id', '=', 's.branch_id')
            ->leftJoin('employees as e', function (JoinClause $join): void {
                $join->on('e.branch_id', '=', 's.branch_id')
                    ->on('e.tenant_id', '=', 's.tenant_id')
                    ->where('e.status', '!=', 'terminated')
                    ->whereNotNull('e.face_embedding');
            })
            ->where('s.tenant_id', $tenantId)
            ->where('s.status', 'active')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('s.branch_id', $branchId))
            ->groupBy('s.branch_id', 'b.name')
            ->get(['s.branch_id', 'b.name as branch_name', DB::raw('COUNT(e.id) AS enrolled')]);

        $rosters = $rows->map(static function (object $row): array {
            $enrolled = Value::int($row->enrolled);

            return [
                'branch_id' => Value::int($row->branch_id),
                'branch_name' => $row->branch_name,
                'enrolled' => $enrolled,
                'warn_above' => KioskIdentifier::ROSTER_WARN_ABOVE,
                'over_ceiling' => $enrolled > KioskIdentifier::ROSTER_WARN_ABOVE,
            ];
        })->all();

        return array_values($rosters);
    }

    private static function branchExists(int $branchId, int $tenantId): bool
    {
        return DB::table('branches')->where('id', $branchId)->where('tenant_id', $tenantId)->exists();
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        return $admin;
    }
}
