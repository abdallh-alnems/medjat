<?php

final class AttendanceSecurityModel {
    public static function log(
        int $tenantId,
        int $employeeId,
        ?int $branchId,
        string $reason,
        string $action,
        ?float $lat = null,
        ?float $lng = null
    ): void {
        try {
            $ip = $_SERVER['REMOTE_ADDR'] ?? null;
            $platform = isset($_SERVER['HTTP_X_PLATFORM'])
                ? substr((string) $_SERVER['HTTP_X_PLATFORM'], 0, 20) : null;
            $appVersion = isset($_SERVER['HTTP_X_APP_VERSION'])
                ? substr((string) $_SERVER['HTTP_X_APP_VERSION'], 0, 20) : null;

            Database::execute(
                "INSERT INTO attendance_security_logs
                    (tenant_id, employee_id, branch_id, reason, action, latitude, longitude, ip_address, platform, app_version)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [$tenantId, $employeeId, $branchId, $reason, $action, $lat, $lng, $ip, $platform, $appVersion]
            );
        } catch (Exception $e) {
            error_log('Security log failed: ' . $e->getMessage());
        }
    }
}
