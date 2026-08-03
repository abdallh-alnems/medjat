<?php

/**
 * Resolves "now" in a tenant's own timezone.
 *
 * The server runs PHP in UTC while MySQL runs in the server's local zone, so a
 * bare date()/NOW() pair disagrees by hours. Every read path already resolves
 * "today" from `tenants.timezone` (dashboard, live attendance, attendance
 * history, the absence cron); this class exists so the WRITE path — the one
 * that stamps check_in_time / check_out_time — resolves it the same way instead
 * of stamping UTC.
 *
 * The tenant's zone is authoritative, not the employee's phone: payroll is
 * computed against the company's working hours, so an employee travelling
 * abroad is still measured against their own company's clock.
 */
final class TenantClock {
    /** Used when a tenant has no timezone set, or has an unparseable one. */
    public const FALLBACK = 'Africa/Cairo';

    /** @var array<int, DateTimeZone> resolved zones, per request */
    private static array $zones = [];

    public static function zone(int $tenantId): DateTimeZone {
        if (isset(self::$zones[$tenantId])) {
            return self::$zones[$tenantId];
        }

        $tenant = TenantModel::findById($tenantId);
        $name = $tenant['timezone'] ?? null;

        try {
            $zone = new DateTimeZone($name !== null && $name !== '' ? $name : self::FALLBACK);
        } catch (Exception $e) {
            // A tenant row can only hold a validated identifier (settings/company.php
            // checks it against timezone_identifiers_list), but a hand-edited row
            // must not be able to break check-in.
            error_log("Invalid timezone '{$name}' for tenant {$tenantId}, using " . self::FALLBACK);
            $zone = new DateTimeZone(self::FALLBACK);
        }

        return self::$zones[$tenantId] = $zone;
    }

    public static function now(int $tenantId): DateTime {
        return new DateTime('now', self::zone($tenantId));
    }

    /** Today's date (Y-m-d) as the tenant experiences it. */
    public static function date(int $tenantId): string {
        return self::now($tenantId)->format('Y-m-d');
    }

    /** The wall-clock time (H:i:s) as the tenant experiences it. */
    public static function time(int $tenantId): string {
        return self::now($tenantId)->format('H:i:s');
    }
}
