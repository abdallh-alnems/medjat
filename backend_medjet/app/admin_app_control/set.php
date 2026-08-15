<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$admin = AdminAuth::require('superadmin');

$input = json_decode(file_get_contents('php://input'), true) ?? [];
$app = trim($input['app'] ?? '');
$minVersion = isset($input['min_version']) ? trim($input['min_version']) : null;
$maintenance = $input['maintenance'] ?? null;

Validator::required($app, 'app');

// Every app RemoteConfigService knows about. The kiosk was left out while it
// carried no Firebase SDK, which made its card in the admin panel — rendered
// from get.php, which always listed three — answer 422 on save. It now
// subscribes to maintenance_medjat_kiosk like the others.
$validApps = ['medjat_app', 'medjat_central', 'medjat_kiosk'];
Validator::enum($app, $validApps, 'app');

if ($minVersion !== null && $minVersion !== '') {
    if (!preg_match('/^\d+(\.\d+){0,3}$/', $minVersion)) {
        Response::fail('Invalid version format. Use dotted numeric (e.g. 1.2.0)', 422, 'invalid_version_format_dotted_numeric');
    }
}

if ($maintenance !== null) {
    if (!is_bool($maintenance)) {
        Response::fail('Maintenance must be a boolean', 422, 'maintenance_boolean');
    }
}

$hasChange = ($minVersion !== null && $minVersion !== '') || $maintenance !== null;
if (!$hasChange) {
    Response::fail('No changes provided. Send min_version and/or maintenance.', 422, 'changes_provided_send_min_version');
}

$result = [];

if ($minVersion !== null && $minVersion !== '') {
    $versionResult = RemoteConfigService::setVersion($app, $minVersion);
    $result['min_version'] = $versionResult['min_version'];

    AdminAuth::logAction('app_control.set_version', 'remote_config', null, [
        'app' => $app,
        'from' => $versionResult['previous_min_version'],
        'to' => $minVersion,
    ]);
}

if ($maintenance !== null) {
    $maintenanceResult = RemoteConfigService::setMaintenance($app, $maintenance);
    $result['maintenance'] = $maintenanceResult['maintenance'];

    AdminAuth::logAction('app_control.set_maintenance', 'remote_config', null, [
        'app' => $app,
        'from' => $maintenanceResult['previous_maintenance'],
        'to' => $maintenance,
    ]);

    // Push an instant signal to every device of the target app so maintenance
    // takes effect immediately, without waiting for the Remote Config realtime
    // stream (which only reacts while the app is foregrounded). Subscribers
    // listen on the per-app topic "maintenance_<app>".
    NotificationService::sendToTopic("maintenance_{$app}", [
        'type' => 'maintenance_mode',
        'app' => $app,
        'enabled' => $maintenance ? '1' : '0',
    ]);
}

$result['app'] = $app;
Response::success($result);
