<?php
/**
 * The supervisor's crew, with today's state for each person.
 *
 * Returns today's check-in/check-out times alongside each name so the app can
 * show who is already marked without a second call — a foreman on a site with
 * one bar of signal should pay for one round trip, not two.
 *
 * Input:  (nothing beyond the employee token)
 * Output: is_supervisor, photo_required, members[]
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$supervisorId = (int) $auth['employee_id'];

$members = CrewModel::membersFor($supervisorId, $tenantId);

Response::success([
    // Derived from whether anybody points at this employee, never from a flag.
    // An empty crew and "not a supervisor" are the same state by construction.
    'is_supervisor'  => $members !== [],
    'photo_required' => CrewModel::photoRequired($tenantId),
    'members'        => array_map(static function (array $m): array {
        return [
            'id'             => (int) $m['id'],
            'name'           => $m['name'],
            'job_title'      => $m['job_title'],
            'profile_image'  => $m['profile_image'] ?? null,
            'check_in_time'  => $m['check_in_time'] ?? null,
            'check_out_time' => $m['check_out_time'] ?? null,
        ];
    }, $members),
]);
