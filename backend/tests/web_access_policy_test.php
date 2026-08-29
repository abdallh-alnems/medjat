<?php
/**
 * Standalone unit test for WebAccessPolicy::check — the gate that decides
 * whether an employee may record attendance from a browser at all.
 *
 * This is the release-safety property of the whole browser channel (spec
 * SC-006): a company that has never touched the setting must be refused, and
 * deploying the feature must therefore change nothing for anybody. It is worth
 * an automated test rather than a one-off manual check, because the failure is
 * silent — nobody notices a channel that is open until it has been used.
 *
 * No database: TenantModel and Database are stubbed before the class under test
 * is loaded, in the same standalone style as late_tier_test.php.
 *
 * Run:
 *   /Applications/MAMP/bin/php/php8.4.15/bin/php backend/tests/web_access_policy_test.php
 */

// ── Stubs ────────────────────────────────────────────────────────────────────

final class TenantModel {
    /** @var array<int, array<string, mixed>|null> */
    public static array $tenants = [];

    public static function findById(int $id): ?array {
        return self::$tenants[$id] ?? null;
    }
}

final class Database {
    /** @var list<array<string, mixed>> */
    public static array $categoryRows = [];

    public static function fetchAll(string $sql, array $params = []): array {
        return self::$categoryRows;
    }
}

final class AttendanceSecurityModel {
    public static array $logged = [];

    public static function log(
        int $tenantId,
        int $employeeId,
        ?int $branchId,
        string $reason,
        string $action,
        ?float $lat = null,
        ?float $lng = null
    ): void {
        self::$logged[] = ['reason' => $reason, 'action' => $action];
    }
}

final class Response {
    public static function fail(string $message, int $code = 400, ?string $errorCode = null): void {
        throw new RuntimeException('refused:' . $errorCode);
    }
}

final class I18n {
    public static function t(string $key): string {
        return $key;
    }
}


// ── Harness ──────────────────────────────────────────────────────────────────

$failures = 0;
$count = 0;

function check(string $name, $expected, $actual): void {
    global $failures, $count;
    $count++;
    if ($expected === $actual) {
        echo "  ✓ {$name}\n";
    } else {
        $failures++;
        echo "  ✗ {$name}\n";
        echo "      expected: " . var_export($expected, true) . "\n";
        echo "      actual:   " . var_export($actual, true) . "\n";
    }
}

$allowed = static function (?array $tenant = null, array $categoryRows = []): bool {
    TenantModel::$tenants = [1 => $tenant];
    Database::$categoryRows = $categoryRows;
    return WebAccessPolicy::check(['id' => 7], 1)['allowed'];
};

$reason = static function (?array $tenant = null, array $categoryRows = []): ?string {
    TenantModel::$tenants = [1 => $tenant];
    Database::$categoryRows = $categoryRows;
    return WebAccessPolicy::check(['id' => 7], 1)['reason'];
};

echo "WebAccessPolicy::check — company switch:\n";

// The property the whole release rests on. A company created before the feature
// existed has no row value at all; one that has seen the migration has 0.
check('company that never opted in → refused', false, $allowed(['id' => 1]));
check('… and the reason is web_not_permitted', 'web_not_permitted', $reason(['id' => 1]));
check('company explicitly disabled → refused', false, $allowed(['web_attendance_enabled' => 0]));
check('missing tenant → refused', false, $allowed(null));
check('company enabled, no categories → allowed', true, $allowed(['web_attendance_enabled' => 1]));
check('enabled as string "1" → allowed', true, $allowed(['web_attendance_enabled' => '1']));

echo "\nWebAccessPolicy::check — category exceptions (union-with-any):\n";

$on = ['web_attendance_enabled' => 1];

check(
    'every category inherits (no rows) → allowed',
    true,
    $allowed($on, [])
);
check(
    'single category allows → allowed',
    true,
    $allowed($on, [['web_attendance_allowed' => 1]])
);
check(
    'single category refuses → refused',
    false,
    $allowed($on, [['web_attendance_allowed' => 0]])
);
check(
    'one of two categories allows → allowed (union, not intersection)',
    true,
    $allowed($on, [['web_attendance_allowed' => 0], ['web_attendance_allowed' => 1]])
);
check(
    'both categories refuse → refused',
    false,
    $allowed($on, [['web_attendance_allowed' => 0], ['web_attendance_allowed' => 0]])
);
// The company switch is the outer gate: a category cannot open a channel the
// company has not opened, which is what makes the company switch a real switch.
check(
    'category allows but company disabled → refused',
    false,
    $allowed(['web_attendance_enabled' => 0], [['web_attendance_allowed' => 1]])
);

echo "\nWebAccessPolicy::photoRequired:\n";

TenantModel::$tenants = [1 => ['web_attendance_photo_required' => 1]];
check('explicitly on → true', true, WebAccessPolicy::photoRequired(1));
TenantModel::$tenants = [1 => ['web_attendance_photo_required' => 0]];
check('explicitly off → false', false, WebAccessPolicy::photoRequired(1));
// Defaults on, mirroring the migration: a company that enables the weakest
// channel keeps the one control that says who pressed the button unless it
// deliberately removes it.
TenantModel::$tenants = [1 => []];
check('unset → defaults to true', true, WebAccessPolicy::photoRequired(1));

echo "\nWebAccessPolicy::refuse:\n";

AttendanceSecurityModel::$logged = [];
$threw = false;
try {
    WebAccessPolicy::refuse(1, 7, 'web_not_permitted', null);
} catch (RuntimeException $e) {
    $threw = ($e->getMessage() === 'refused:WEB_NOT_PERMITTED');
}
check('refuses with an uppercased error code', true, $threw);
// A blocked attempt that leaves no trace is the failure attendance_security_logs
// was created to end; the table spent weeks silently discarding every row.
check('writes exactly one security log row', 1, count(AttendanceSecurityModel::$logged));
check('logged as blocked', 'blocked', AttendanceSecurityModel::$logged[0]['action'] ?? null);

echo "\n{$count} checks, {$failures} failed\n";
exit($failures === 0 ? 0 : 1);
