<?php

/**
 * Decides whether an employee may use the browser channel at all.
 *
 * Deliberately NOT part of AttendanceMethodResolver. The web is *where*
 * attendance is recorded from; an attendance method is *how identity is proven*.
 * `AttendanceMethodResolver::ALLOWED` already mixes those two ideas together
 * ('qr_gps' and 'wifi_gps' are constraints, 'manual' and 'device' are channels),
 * and adding 'web' to it would deepen a confusion the codebase already needs to
 * unwind. Keeping this separate is a decision, not an oversight — see spec
 * FR-023b.
 */
final class WebAccessPolicy {
    /**
     * @return array{allowed: bool, reason: ?string}
     *   reason is null when allowed, otherwise a code suitable for the caller to
     *   return and to write into attendance_security_logs.
     */
    public static function check(array $employee, int $tenantId): array {
        $tenant = TenantModel::findById($tenantId);
        if (!$tenant || (int) ($tenant['web_attendance_enabled'] ?? 0) !== 1) {
            return ['allowed' => false, 'reason' => 'web_not_permitted'];
        }

        // Union-with-any across the employee's categories, matching how category
        // attendance methods already resolve — administrators should meet one
        // mental model, not two. A company that sets nothing has the channel
        // available to everyone, so the simple case needs no configuration.
        $rows = Database::fetchAll(
            "SELECT ec.web_attendance_allowed
             FROM employee_categories ec
             JOIN employee_category_assignments eca
               ON eca.category_id = ec.id AND eca.tenant_id = ec.tenant_id
             WHERE eca.employee_id = ? AND eca.tenant_id = ?
               AND ec.is_active = 1 AND ec.web_attendance_allowed IS NOT NULL",
            [(int) ($employee['id'] ?? 0), $tenantId]
        );

        if ($rows === []) {
            return ['allowed' => true, 'reason' => null];
        }

        foreach ($rows as $row) {
            if ((int) $row['web_attendance_allowed'] === 1) {
                return ['allowed' => true, 'reason' => null];
            }
        }

        return ['allowed' => false, 'reason' => 'web_not_permitted'];
    }

    /** True when this company wants an image captured at each browser punch. */
    public static function photoRequired(int $tenantId): bool {
        $tenant = TenantModel::findById($tenantId);
        return (int) ($tenant['web_attendance_photo_required'] ?? 1) === 1;
    }

    /**
     * Refuses the request and records why.
     *
     * Every refusal is logged. A blocked attempt that leaves no trace is the
     * failure mode attendance_security_logs was created to end — the table
     * spent weeks silently discarding every row it was handed.
     */
    public static function refuse(
        int $tenantId,
        int $employeeId,
        string $reason,
        ?int $branchId = null,
        ?float $lat = null,
        ?float $lng = null
    ): void {
        AttendanceSecurityModel::log($tenantId, $employeeId, $branchId, $reason, 'blocked', $lat, $lng);
        Response::fail(I18n::t('web_attendance_not_allowed'), 403, strtoupper($reason));
    }
}
