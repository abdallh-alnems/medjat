<?php
/**
 * Kiosk identification activity, and the score distribution behind it.
 *
 * This endpoint is what makes the feature **tunable**, and an untunable face
 * threshold is how a company ends up switching the whole thing off. The
 * starting operating point (0.550 / 0.080) is derived from LFW pairs, not from
 * anybody's branch; the only way to set it honestly is to read what a real
 * branch actually produces.
 *
 * `capture_path` is deliberately absent from the response. Scores and outcomes
 * are attendance data; the image behind them is biometric evidence and costs a
 * different permission (`kiosk_evidence`) through a different endpoint.
 *
 * Input: branch_id, station_id, result, date_from, date_to, limit,
 *        view ("list" | "distribution")
 */
require_once __DIR__ . '/../../config/bootstrap.php';
require_once __DIR__ . '/../../core/KioskIdentifier.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_attendance');

$input = $auth['input'];
$branchId = isset($input['branch_id']) && $input['branch_id'] !== '' ? (int) $input['branch_id'] : null;

if ($branchId !== null && !BranchModel::findById($branchId, $tenantId)) {
    Response::notFound('Branch');
}

if (($input['view'] ?? 'list') === 'distribution') {
    $buckets = StationRecognitionLogModel::distribution($tenantId, $branchId);

    // The two numbers a threshold is actually chosen between. Genuine matches
    // should cluster high and everything else low; where they stop overlapping
    // is the operating point.
    $matched = array_values(array_filter($buckets, static fn($b) => $b['result'] === 'matched'));
    $rejected = array_values(array_filter($buckets, static fn($b) => $b['result'] !== 'matched'));

    Response::success([
        'view'     => 'distribution',
        'buckets'  => $buckets,
        'summary'  => [
            'matched_attempts'  => array_sum(array_column($matched, 'attempts')),
            'rejected_attempts' => array_sum(array_column($rejected, 'attempts')),
            'current_defaults'  => [
                'threshold' => KioskIdentifier::DEFAULT_THRESHOLD,
                'margin'    => KioskIdentifier::DEFAULT_MARGIN,
            ],
        ],
        // A reminder rather than a number: these figures are only meaningful
        // once a branch has produced a few thousand attempts.
        'note_key' => 'kiosk_tuning_needs_volume',
    ]);
}

$logs = StationRecognitionLogModel::search($tenantId, [
    'branch_id'  => $branchId,
    'station_id' => isset($input['station_id']) && $input['station_id'] !== '' ? (int) $input['station_id'] : null,
    'result'     => $input['result'] ?? null,
    'date_from'  => $input['date_from'] ?? null,
    'date_to'    => $input['date_to'] ?? null,
], min(500, max(1, (int) ($input['limit'] ?? 100))));

Response::success([
    'view' => 'list',
    'logs' => array_map(static fn(array $l): array => [
        'id'            => (int) $l['id'],
        'created_at'    => $l['created_at'],
        'branch'        => ['id' => (int) $l['branch_id'], 'name' => $l['branch_name']],
        'station'       => ['id' => (int) $l['station_id'], 'name' => $l['station_name']],
        'employee'      => $l['employee_id'] !== null
            ? ['id' => (int) $l['employee_id'], 'name' => $l['employee_name']]
            : null,
        'purpose'       => $l['purpose'],
        'method'        => $l['method'],
        'result'        => $l['result'],
        'accepted'      => (bool) $l['accepted'],
        'match_score'   => $l['match_score'] !== null ? (float) $l['match_score'] : null,
        'runner_up'     => $l['runner_up_score'] !== null ? (float) $l['runner_up_score'] : null,
        'margin_gap'    => ($l['match_score'] !== null && $l['runner_up_score'] !== null)
            ? round((float) $l['match_score'] - (float) $l['runner_up_score'], 3)
            : null,
        'threshold'     => $l['threshold'] !== null ? (float) $l['threshold'] : null,
        'margin'        => $l['margin'] !== null ? (float) $l['margin'] : null,
        'candidates'    => $l['candidates_searched'] !== null ? (int) $l['candidates_searched'] : null,
        'liveness_passed' => (bool) $l['liveness_passed'],
        'attendance_id' => $l['attendance_id'] !== null ? (int) $l['attendance_id'] : null,
        // Whether an image EXISTS, not the image itself.
        'has_capture'   => (bool) $l['has_capture'],
    ], $logs),
]);
