<?php

/**
 * ZKTeco ADMS ("push") endpoint — the only door in this codebase that is not
 * opened by a logged-in human.
 *
 * A terminal cannot send a bearer token, a Firebase ID token, or HTTP Basic
 * credentials; the firmware simply has nowhere to put them. What it does send,
 * on every single request, is its serial number, and a serial number that no
 * company has claimed can do nothing here but leave a "device seen" mark. That
 * is the whole authorisation model, and it is why claiming is one-way and
 * exclusive (see AttendanceDeviceModel::claim).
 *
 * Hard rules for this file:
 *   - ALWAYS answer 200 with a plain-text body. A device that gets an error
 *     re-sends the same batch on a loop until it does get a 200, and meanwhile
 *     records nothing new.
 *   - Never let an exception escape. The punch has already been stored by the
 *     time anything interesting can fail.
 */

// Tells bootstrap to skip the app-secret gate: this request comes from
// hardware, not from one of the mobile apps.
define('MEDJAT_DEVICE_ENDPOINT', true);

require_once __DIR__ . '/../config/bootstrap.php';

header('Content-Type: text/plain; charset=utf-8');
header('Cache-Control: no-store');

/** Everything below answers with plain text and exits. */
function deviceReply(string $body): void {
    global $__device, $__logContext;
    if (!empty($__device['debug_logging'])) {
        logProtocol($__logContext, $body, $__device);
    }
    echo $body;
    exit;
}

function logProtocol(array $ctx, string $response, ?array $device): void {
    try {
        Database::execute(
            "INSERT INTO device_protocol_logs
                (device_id, serial_number, method, path, query_string, body, response, client_ip)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $device['id'] ?? null,
                $ctx['serial'] ?: null,
                $ctx['method'],
                $ctx['action'],
                mb_substr($ctx['query'], 0, 500),
                mb_substr($ctx['body'], 0, 60000),
                mb_substr($response, 0, 8000),
                $ctx['ip'],
            ]
        );
    } catch (Throwable $e) {
        error_log('Device protocol log failed: ' . $e->getMessage());
    }
}

/** Current UTC offset in whole hours for the company the device belongs to. */
function tenantOffsetHours(?array $device): int {
    $tz = 'Africa/Cairo';
    if ($device && $device['tenant_id'] !== null) {
        $tenant = TenantModel::findById((int) $device['tenant_id']);
        if (!empty($tenant['timezone'])) {
            $tz = $tenant['timezone'];
        }
    }
    try {
        $offset = (new DateTimeZone($tz))->getOffset(new DateTime('now', new DateTimeZone('UTC')));
        return (int) round($offset / 3600);
    } catch (Exception $e) {
        return 2;
    }
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$requestUri = $_SERVER['REQUEST_URI'] ?? '';
$path = strtolower((string) parse_url($requestUri, PHP_URL_PATH));

// Normal routing gives us /iclock/<action>. `action` is the fallback for local
// testing, where the script is called directly by filename.
$action = 'cdata';
if (preg_match('#/iclock/([a-z]+)#', $path, $m)) {
    $action = $m[1];
} elseif (!empty($_GET['action'])) {
    $action = strtolower(preg_replace('/[^a-z]/i', '', (string) $_GET['action']));
}

$serial = AttendanceDeviceModel::normaliseSerial($_GET['SN'] ?? $_GET['sn'] ?? '');
$body = file_get_contents('php://input') ?: '';

$__logContext = [
    'serial' => $serial,
    'method' => $method,
    'action' => $action,
    'query' => $_SERVER['QUERY_STRING'] ?? '',
    'body' => $body,
    'ip' => $_SERVER['HTTP_CF_CONNECTING_IP'] ?? $_SERVER['REMOTE_ADDR'] ?? null,
];
$__device = null;

// A request with no serial number is not a device we can help. Answer OK so it
// stops retrying rather than spinning.
if ($serial === '') {
    echo 'OK';
    exit;
}

try {
    $__device = AttendanceDeviceModel::recordContact($serial, $__logContext['ip']);
} catch (Throwable $e) {
    error_log('Device contact failed for ' . $serial . ': ' . $e->getMessage());
    echo 'OK';
    exit;
}

$device = $__device;
$deviceId = (int) $device['id'];

if ($device['status'] === 'disabled') {
    // Registered but switched off in the app. Stay polite: the terminal keeps
    // its own log and will deliver it when re-enabled.
    deviceReply('OK');
}

try {
    switch ($action) {
        // ----------------------------------------------------------
        // Handshake + data upload
        // ----------------------------------------------------------
        case 'cdata':
            if ($method === 'GET') {
                AttendanceDeviceModel::updateInfo($deviceId, [
                    'model' => $_GET['DeviceType'] ?? $_GET['model'] ?? null,
                    'firmware' => $_GET['pushver'] ?? null,
                ]);
                deviceReply(ZktecoAdms::handshakeResponse($serial, tenantOffsetHours($device)));
            }

            $table = strtoupper((string) ($_GET['table'] ?? ''));

            if ($table === 'ATTLOG') {
                $count = DevicePunchIngestor::ingestAttlog($device, $body);
                deviceReply('OK: ' . $count);
            }

            if ($table === 'OPERLOG') {
                DevicePunchIngestor::ingestOperlog($device, $body);
                deviceReply('OK');
            }

            // OPTIONS carries the device's self-description on some firmware.
            if ($table === 'OPTIONS' || $table === '') {
                $fields = ZktecoAdms::parseFields(str_replace(["\r\n", "\n"], "\t", $body));
                AttendanceDeviceModel::updateInfo($deviceId, [
                    'model' => $fields['DeviceName'] ?? $fields['~DeviceName'] ?? null,
                    'firmware' => $fields['FWVersion'] ?? $fields['~ZKFPVersion'] ?? null,
                    'user_count' => isset($fields['UserCount']) ? (int) $fields['UserCount'] : null,
                ]);
                deviceReply('OK');
            }

            // ATTPHOTO and friends: acknowledged, not stored.
            deviceReply('OK');

        // ----------------------------------------------------------
        // Command poll
        // ----------------------------------------------------------
        case 'getrequest':
            if ($device['tenant_id'] === null) {
                deviceReply('OK');
            }
            DeviceCommandModel::pruneStale($deviceId);
            $commands = DeviceCommandModel::claimQueued($deviceId);
            deviceReply(ZktecoAdms::commandResponse($commands));

        // ----------------------------------------------------------
        // Command result
        // ----------------------------------------------------------
        case 'devicecmd':
            $fields = [];
            parse_str(str_replace(["\r\n", "\n", "\t"], '&', $body), $fields);
            $commandId = isset($fields['ID']) ? (int) $fields['ID'] : 0;
            if ($commandId > 0) {
                DeviceCommandModel::complete($commandId, $deviceId, $fields['Return'] ?? null);
            }
            deviceReply('OK');

        // ----------------------------------------------------------
        // Keepalive / biometric payloads we acknowledge and drop
        // ----------------------------------------------------------
        case 'ping':
        case 'fdata':
        case 'edata':
        case 'querydata':
        default:
            deviceReply('OK');
    }
} catch (Throwable $e) {
    error_log('Device endpoint error (' . $serial . '/' . $action . '): ' . $e->getMessage());
    // Still a 200: the punches were stored before anything here could fail, and
    // an error status would only make the terminal resend them.
    deviceReply('OK');
}
