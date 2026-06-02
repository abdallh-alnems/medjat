<?php
require_once __DIR__ . '/../../config/bootstrap.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    RateLimiter::enforceIpLimit();
    Auth::requireGet();
    $auth = Auth::authenticateEmployee(db());

    $row = Database::fetchOne(
        "SELECT prefs FROM admin_notification_prefs WHERE admin_id = ? LIMIT 1",
        [$auth['admin_id']]
    );

    $defaultPrefs = [
        'late_absence'     => true,
        'missing_checkout' => true,
        'document_expiry'  => true,
        'leave_events'     => true,
        'payroll_events'   => true,
    ];

    if ($row) {
        $prefs = json_decode($row['prefs'], true);
        if (!is_array($prefs)) {
            $prefs = $defaultPrefs;
        }
    } else {
        $prefs = $defaultPrefs;
    }

    Response::success(['prefs' => $prefs]);
} elseif ($method === 'POST') {
    RateLimiter::enforceIpLimit();
    Auth::requirePost();
    $auth = Auth::authenticateEmployee(db());

    $input = $auth['input'];
    $prefs = $input['prefs'] ?? null;

    if (!is_array($prefs)) {
        Response::fail('prefs must be an object', 400);
    }

    $validKeys = ['late_absence', 'missing_checkout', 'document_expiry', 'leave_events', 'payroll_events'];
    $clean = [];
    foreach ($validKeys as $key) {
        $clean[$key] = isset($prefs[$key]) ? (bool) $prefs[$key] : true;
    }

    $encoded = json_encode($clean, JSON_UNESCAPED_UNICODE);

    Database::execute(
        "INSERT INTO admin_notification_prefs (admin_id, tenant_id, prefs, updated_at)
         VALUES (?, ?, ?, NOW())
         ON DUPLICATE KEY UPDATE prefs = VALUES(prefs), updated_at = NOW()",
        [$auth['admin_id'], $auth['tenant_id'] ?: null, $encoded]
    );

    Response::success(['prefs' => $clean]);
} else {
    Response::fail('Method not allowed', 405);
}
