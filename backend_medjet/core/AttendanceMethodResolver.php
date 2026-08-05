<?php

/**
 * Resolves the attendance methods in effect for a specific employee, applying
 * overrides most-specific-first:
 *
 *   1) employee override   (employees.attendance_methods)
 *   2) category union      (employee_categories.attendance_methods, UNIONed
 *                           across all of the employee's categories that set one)
 *   3) branch override     (branches.attendance_methods)
 *   4) company default     (tenants.attendance_methods)
 *
 * NULL at a level means "inherit the next level". Always returns a non-empty,
 * de-duplicated list of valid methods, defaulting to ['qr_gps'].
 */
final class AttendanceMethodResolver {
    // 'device' (a biometric terminal at the branch) and 'manual' are listed so
    // a company can be set to those alone, which is how the employee app is
    // told to stop offering self check-in. Neither is a self-service method:
    // the device path authorises itself by serial number + User ID link, and
    // never consults this resolver.
    // 'kiosk' is a shared branch tablet. Like 'device' it is not a self-service
    // method — the employee holds no credential and the tablet authorises
    // itself with a branch-scoped token — but unlike 'device' it DOES consult
    // this resolver, so that a company can put its factory floor on the kiosk
    // while office staff stay on gps_only.
    public const ALLOWED = ['qr_gps', 'gps_only', 'face_selfie', 'wifi_gps', 'device', 'manual', 'kiosk'];

    public static function resolveForEmployee(array $employee, int $tenantId): array {
        // 1) employee override
        $methods = self::decode($employee['attendance_methods'] ?? null);
        if (!empty($methods)) {
            return $methods;
        }

        // 2) union of the employee's category overrides
        $catUnion = self::categoryUnion((int) ($employee['id'] ?? 0), $tenantId);
        if (!empty($catUnion)) {
            return $catUnion;
        }

        // 3) branch override
        $branchId = (int) ($employee['branch_id'] ?? 0);
        if ($branchId > 0) {
            $branch = BranchModel::findById($branchId, $tenantId);
            if ($branch) {
                $branchMethods = self::decode($branch['attendance_methods'] ?? null);
                if (!empty($branchMethods)) {
                    return $branchMethods;
                }
            }
        }

        // 4) company default
        $tenant = TenantModel::findById($tenantId);
        $tenantMethods = self::decode($tenant['attendance_methods'] ?? null);
        return !empty($tenantMethods) ? $tenantMethods : ['qr_gps'];
    }

    /** Union of attendance methods from the employee's active categories that set an override. */
    private static function categoryUnion(int $employeeId, int $tenantId): array {
        if ($employeeId <= 0) {
            return [];
        }
        $rows = Database::fetchAll(
            "SELECT ec.attendance_methods
             FROM employee_categories ec
             JOIN employee_category_assignments eca
               ON eca.category_id = ec.id AND eca.tenant_id = ec.tenant_id
             WHERE eca.employee_id = ? AND eca.tenant_id = ?
               AND ec.is_active = 1 AND ec.attendance_methods IS NOT NULL",
            [$employeeId, $tenantId]
        );
        $union = [];
        foreach ($rows as $r) {
            foreach (self::decode($r['attendance_methods']) as $m) {
                $union[$m] = true;
            }
        }
        return array_keys($union);
    }

    /** Decode a JSON column into a clean list of valid, de-duplicated methods. */
    private static function decode($json): array {
        if ($json === null || $json === '') {
            return [];
        }
        $arr = is_array($json) ? $json : json_decode($json, true);
        if (!is_array($arr)) {
            return [];
        }
        return array_values(array_unique(array_filter(
            $arr,
            static fn($m) => in_array($m, self::ALLOWED, true)
        )));
    }
}
