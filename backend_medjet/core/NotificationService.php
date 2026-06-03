<?php

final class NotificationService {
    public static function sendToUser(int $adminId, string $title, string $body, ?array $data = null): bool {
        $tokens = Database::fetchAll(
            "SELECT fcm_token FROM admin_devices WHERE admin_id = ? AND is_active = 1",
            [$adminId]
        );

        if (empty($tokens)) {
            return false;
        }

        return self::sendMulticast(
            array_column($tokens, 'fcm_token'),
            $title,
            $body,
            $data
        );
    }

    public static function sendToTenant(int $tenantId, string $title, string $body, ?array $data = null): int {
        $tokens = Database::fetchAll(
            "SELECT ud.fcm_token FROM admin_devices ud
             JOIN admins a ON a.id = ud.admin_id
             WHERE a.tenant_id = ? AND ud.is_active = 1",
            [$tenantId]
        );

        if (empty($tokens)) {
            return 0;
        }

        $success = self::sendMulticast(
            array_column($tokens, 'fcm_token'),
            $title,
            $body,
            $data
        );

        return $success ? count($tokens) : 0;
    }

    /**
     * Push to the tenant's managers only (everyone who isn't a plain employee
     * or a still-pending admin). Used for admin-facing alerts such as an
     * employee activating their account.
     */
    public static function sendToTenantManagers(int $tenantId, string $title, string $body, ?array $data = null): int {
        $tokens = Database::fetchAll(
            "SELECT ud.fcm_token FROM admin_devices ud
             JOIN admins a ON a.id = ud.admin_id
             WHERE a.tenant_id = ?
               AND a.role NOT IN ('employee', 'pending')
               AND ud.is_active = 1",
            [$tenantId]
        );

        if (empty($tokens)) {
            return 0;
        }

        $success = self::sendMulticast(
            array_column($tokens, 'fcm_token'),
            $title,
            $body,
            $data
        );

        return $success ? count($tokens) : 0;
    }

    public static function sendToBranch(int $branchId, int $tenantId, string $title, string $body, ?array $data = null): int {
        $tokens = Database::fetchAll(
            "SELECT ud.fcm_token FROM admin_devices ud
             JOIN admins a ON a.id = ud.admin_id
             WHERE a.branch_id = ? AND a.tenant_id = ? AND ud.is_active = 1",
            [$branchId, $tenantId]
        );

        if (empty($tokens)) {
            return 0;
        }

        $success = self::sendMulticast(
            array_column($tokens, 'fcm_token'),
            $title,
            $body,
            $data
        );

        return $success ? count($tokens) : 0;
    }

    private static function sendMulticast(array $tokens, string $title, string $body, ?array $data = null): bool {
        try {
            $messaging = FirebaseInit::getMessaging();
            if (!$messaging) {
                return false;
            }

            $notification = [
                'title' => $title,
                'body' => $body,
            ];

            $message = [
                'notification' => $notification,
                'data' => $data ?: [],
                'android' => ['priority' => 'high'],
            ];

            $report = $messaging->sendMulticast($message, $tokens);
            return $report->successes()->count() > 0;
        } catch (Exception $e) {
            error_log('FCM send error: ' . $e->getMessage());
            return false;
        }
    }
}
