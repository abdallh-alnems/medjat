<?php
/**
 * Face-verification audit for HR.
 *
 * Two shapes, chosen by `view`:
 *   - `employee` → the recent attempts for one employee (dispute handling)
 *   - `distribution` → score histogram across the company (threshold tuning)
 *
 * The distribution view is what turns `log_only` mode into a decision: run for
 * a couple of weeks, see where genuine matches cluster versus the rejections,
 * then set the threshold on real data before switching to `enforce`.
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_attendance');

$input = $auth['input'];
$view = $input['view'] ?? 'employee';

if ($view === 'distribution') {
    $days = (int) ($input['days'] ?? 30);
    $rows = FaceVerificationLogModel::scoreDistribution($tenantId, $days);

    Response::success([
        'days' => $days,
        'threshold' => (float) (TenantModel::findById($tenantId)['face_match_threshold'] ?? FaceMatchService::DEFAULT_THRESHOLD),
        'buckets' => array_map(static fn($r) => [
            'score' => (float) $r['bucket'],
            'result' => $r['result'],
            'attempts' => (int) $r['attempts'],
        ], $rows),
    ]);
}

$employeeId = (int) ($input['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}
PermissionMiddleware::checkBranchAccess($auth, (int) $employee['branch_id']);

$logs = FaceVerificationLogModel::recentForEmployee($employeeId, $tenantId, (int) ($input['limit'] ?? 20));

Response::success([
    'employee_id' => $employeeId,
    'logs' => array_map(static fn($r) => [
        'id' => (int) $r['id'],
        'purpose' => $r['purpose'],
        'result' => $r['result'],
        'accepted' => (bool) $r['accepted'],
        'match_score' => $r['match_score'] !== null ? (float) $r['match_score'] : null,
        'threshold' => $r['threshold'] !== null ? (float) $r['threshold'] : null,
        'liveness_passed' => (bool) $r['liveness_passed'],
        'challenge' => $r['challenge'],
        'selfie_path' => $r['selfie_path'],
        'created_at' => $r['created_at'],
    ], $logs),
]);
