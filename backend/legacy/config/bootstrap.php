<?php

if (defined('PERMEDJAT_BOOTSTRAPPED')) {
    return;
}

require_once __DIR__ . '/env.php';

// PHP defaults to UTC while MySQL runs in the server's local zone, so any code
// mixing date() with NOW() disagrees by hours. Anchor PHP to the zone most
// tenants live in; per-tenant work resolves its own zone through TenantClock,
// and this only decides what a caller that never asks for one gets.
date_default_timezone_set(getenv('APP_TIMEZONE') ?: 'Africa/Cairo');

require_once __DIR__ . '/database.php';
require_once __DIR__ . '/cors.php';
require_once __DIR__ . '/firebase.php';

// Application classes load on demand instead of being listed here one by one.
//
// Every file under core/ and database/models/ declares exactly one global class
// named after the file, so the class name is the path. This replaces 92 explicit
// require_once lines that had to be edited whenever a class was added, and 121
// more spread across the endpoints.
//
// A hand-written loader rather than composer's classmap on purpose: vendor/ is
// owned by the server and never deployed, so a classmap would need a
// `composer dump-autoload` step on the server and could silently drift from the
// repo. This has no build step and behaves identically on both sides. Moving
// either directory is a one-line change here.
spl_autoload_register(static function (string $class): void {
    if (strpbrk($class, '\\/.') !== false) {
        return; // namespaced or malformed — not ours, let the next loader try
    }
    $roots = [__DIR__ . '/../core/', __DIR__ . '/../database/models/'];

    // Common case: the class sits directly in one of the two roots. Two stat
    // calls and no directory walk.
    foreach ($roots as $dir) {
        $file = $dir . $class . '.php';
        if (is_file($file)) {
            require_once $file;
            return;
        }
    }

    // Some classes are grouped in a sub-directory (core/payroll_export/, and its
    // exporters/). Scanning is only reached when the flat lookup misses, and the
    // map is built once per request.
    static $nested = null;
    if ($nested === null) {
        $nested = [];
        foreach ($roots as $dir) {
            $it = new RecursiveIteratorIterator(
                new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS)
            );
            foreach ($it as $f) {
                if ($f->isFile() && $f->getExtension() === 'php') {
                    $nested[$f->getBasename('.php')] = $f->getPathname();
                }
            }
        }
    }
    if (isset($nested[$class])) {
        require_once $nested[$class];
    }
});

// Browser attendance channel (specs/004-web-attendance-checkin).

setCorsHeaders();

// API access gate: every request from the mobile apps carries an HTTP Basic
// credential (SECURITY_USER:SECURITY_KEY). When both are configured we require
// a match, so the API can't be called directly without the shared app secret.
// Disabled automatically when unset (local dev), and never applies to CLI cron
// scripts or a caller presenting the valid CRON_SECRET.
(static function (): void {
    $user = (string) getenv('SECURITY_USER');
    $key  = (string) getenv('SECURITY_KEY');
    if ($user === '' || $key === '' || PHP_SAPI === 'cli') {
        return;
    }

    // Attendance terminals (device/iclock.php) cannot send the app secret —
    // the firmware has no field for it. They authenticate by serial number
    // instead, and an unclaimed serial can do nothing but say hello.
    if (defined('PERMEDJAT_DEVICE_ENDPOINT')) {
        return;
    }

    $cronSecret = (string) getenv('CRON_SECRET');
    $providedCron = (string) ($_SERVER['HTTP_X_CRON_SECRET'] ?? $_GET['cron_secret'] ?? '');
    if ($cronSecret !== '' && hash_equals($cronSecret, $providedCron)) {
        return;
    }

    // Apache/LiteSpeed populates PHP_AUTH_* for Basic auth; fall back to the raw
    // Authorization header (needs CGIPassAuth/rewrite to be forwarded to PHP).
    $u = $_SERVER['PHP_AUTH_USER'] ?? null;
    $k = $_SERVER['PHP_AUTH_PW'] ?? null;
    if ($u === null) {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
        if (stripos($header, 'Basic ') === 0) {
            $decoded = base64_decode(substr($header, 6), true);
            if ($decoded !== false && strpos($decoded, ':') !== false) {
                [$u, $k] = explode(':', $decoded, 2);
            }
        }
    }

    $ok = $u !== null && hash_equals($user, (string) $u) && hash_equals($key, (string) $k);
    if (!$ok) {
        http_response_code(401);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'status' => 'error',
            'code' => 401,
            'message' => 'Unauthorized',
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
})();

define('PERMEDJAT_BOOTSTRAPPED', true);
