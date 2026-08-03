<?php
require_once __DIR__ . '/../../config/bootstrap.php';

/**
 * The raw punch feed, straight from the terminals.
 *
 * This is the screen to open when someone says "the machine didn't record me":
 * either the punch is here and shows why it was not applied, or it never
 * arrived at all — which is a very different conversation.
 */

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

// Readable by whoever runs attendance day to day, and by whoever set the
// devices up — a role with one permission but not the other must not hit a
// 403 on a screen it can reach.
PermissionMiddleware::checkAny($auth, ['manage_attendance', 'manage_company_settings']);

$filters = [
    'device_id' => isset($_GET['device_id']) ? (int) $_GET['device_id'] : null,
    'state' => $_GET['state'] ?? null,
    'employee_id' => isset($_GET['employee_id']) ? (int) $_GET['employee_id'] : null,
    'date_from' => $_GET['date_from'] ?? null,
    'date_to' => $_GET['date_to'] ?? null,
];

if ($filters['state'] !== null
    && !in_array($filters['state'], ['applied', 'duplicate', 'unmatched', 'ignored', 'failed'], true)) {
    $filters['state'] = null;
}
foreach (['date_from', 'date_to'] as $key) {
    if (!empty($filters[$key])) {
        $filters[$key] = Validator::date((string) $filters[$key], $key);
    }
}

$limit = isset($_GET['limit']) ? (int) $_GET['limit'] : 100;

$punches = array_map(static function (array $p): array {
    return [
        'id' => (int) $p['id'],
        'device_id' => (int) $p['device_id'],
        'device_name' => $p['device_name'] ?: $p['serial_number'],
        'device_user_id' => $p['device_user_id'],
        'device_user_name' => $p['device_user_name'],
        'employee_id' => $p['employee_id'] !== null ? (int) $p['employee_id'] : null,
        'employee_name' => $p['employee_name'],
        'punched_at' => $p['punched_at'],
        'direction' => $p['direction'],
        'state' => $p['state'],
        'note' => $p['note'],
        'attendance_id' => $p['attendance_id'] !== null ? (int) $p['attendance_id'] : null,
        'recognition' => ZktecoAdms::recognitionMethod(
            $p['verify_mode'] !== null ? (int) $p['verify_mode'] : null
        ),
    ];
}, DevicePunchModel::listForTenant($tenantId, $filters, $limit));

Response::success(['punches' => $punches]);
