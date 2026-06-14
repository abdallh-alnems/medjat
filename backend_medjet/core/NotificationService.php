<?php

final class NotificationService {
    /**
     * Push the SAME notification to many admin accounts in one shot. Collects
     * every active device token for the given admin ids and sends them via FCM
     * multicast in chunks of 500 (the FCM per-call limit), so a bulk action on
     * hundreds of employees is a few HTTP calls instead of one-per-employee.
     * Returns the number of chunks that reported at least one success.
     */
    public static function sendToManyAdmins(array $adminIds, string $title, string $body, ?array $data = null): int {
        $ids = array_values(array_unique(array_map('intval', array_filter($adminIds))));
        if (empty($ids)) {
            return 0;
        }
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $rows = Database::fetchAll(
            "SELECT fcm_token FROM admin_devices
             WHERE is_active = 1 AND admin_id IN ($placeholders)",
            $ids
        );
        $tokens = array_values(array_filter(array_column($rows, 'fcm_token')));
        if (empty($tokens)) {
            return 0;
        }

        $sent = 0;
        foreach (array_chunk($tokens, 500) as $chunk) {
            try {
                if (self::sendMulticast($chunk, $title, $body, $data)) {
                    $sent++;
                }
            } catch (Throwable $e) {
                error_log('sendToManyAdmins chunk failed: ' . $e->getMessage());
            }
        }
        return $sent;
    }

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

    /**
     * Push to a single employee's device(s). The employee app registers its FCM
     * token under the employee's linked admin account (employees.admin_id), so
     * we resolve the tokens through that relationship.
     */
    public static function sendToEmployee(int $employeeId, string $title, string $body, ?array $data = null): bool {
        $tokens = Database::fetchAll(
            "SELECT ad.fcm_token FROM admin_devices ad
             JOIN employees e ON e.admin_id = ad.admin_id
             WHERE e.id = ? AND ad.is_active = 1",
            [$employeeId]
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

    public static function sendToSupportTeam(string $title, string $body, ?array $data = null): bool {
        $tokens = Database::fetchAll(
            "SELECT fcm_token FROM super_admin_devices WHERE is_active = 1"
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

    /**
     * Full notification to a single employee: persists an in-app row (visible in
     * the employee app's notification list, which filters by the recipient's
     * account id = employees.admin_id) and fires an FCM push. Arabic strings are
     * used for the push since both apps are Arabic-first; the in-app row keeps
     * both languages so the app can localise.
     */
    public static function notifyEmployee(
        int $tenantId,
        int $employeeId,
        string $type,
        string $titleEn,
        string $titleAr,
        string $bodyEn,
        string $bodyAr,
        ?array $data = null
    ): void {
        $emp = Database::fetchOne(
            "SELECT admin_id FROM employees WHERE id = ? AND tenant_id = ?",
            [$employeeId, $tenantId]
        );
        $accountId = ($emp && $emp['admin_id']) ? (int) $emp['admin_id'] : null;
        if ($accountId !== null) {
            try {
                Database::execute(
                    "INSERT INTO notifications
                        (tenant_id, admin_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'push,in_app', NOW())",
                    [
                        $tenantId, $accountId, $employeeId, $type,
                        $titleEn, $titleAr, $bodyEn, $bodyAr,
                        $data ? json_encode($data, JSON_UNESCAPED_UNICODE) : null,
                    ]
                );
            } catch (Exception $e) {
                error_log('notifyEmployee insert error: ' . $e->getMessage());
            }
        }
        self::sendToEmployee($employeeId, $titleAr, $bodyAr, $data);
    }

    /**
     * Full notification to the tenant's managers (anyone who isn't a plain
     * employee or pending admin): one in-app row per manager + an FCM push.
     */
    public static function notifyManagers(
        int $tenantId,
        string $type,
        string $titleEn,
        string $titleAr,
        string $bodyEn,
        string $bodyAr,
        ?array $data = null
    ): void {
        $managers = Database::fetchAll(
            "SELECT id FROM admins
             WHERE tenant_id = ? AND role NOT IN ('employee', 'pending')",
            [$tenantId]
        );
        $payload = $data ? json_encode($data, JSON_UNESCAPED_UNICODE) : null;
        foreach ($managers as $m) {
            try {
                Database::execute(
                    "INSERT INTO notifications
                        (tenant_id, admin_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'push,in_app', NOW())",
                    [$tenantId, (int) $m['id'], $type, $titleEn, $titleAr, $bodyEn, $bodyAr, $payload]
                );
            } catch (Exception $e) {
                error_log('notifyManagers insert error: ' . $e->getMessage());
            }
        }
        self::sendToTenantManagers($tenantId, $titleAr, $bodyAr, $data);
    }

    /**
     * Send a silent (data-only) high-priority message to an FCM topic.
     * Used for instant control signals (e.g. maintenance mode) that every
     * device subscribed to the app's topic should react to immediately,
     * even while backgrounded. No visible notification is shown.
     */
    public static function sendToTopic(string $topic, array $data): bool {
        try {
            $messaging = FirebaseInit::getMessaging();
            if (!$messaging) {
                return false;
            }

            $stringData = [];
            foreach ($data as $key => $value) {
                $stringData[(string) $key] = is_scalar($value)
                    ? (string) $value
                    : json_encode($value, JSON_UNESCAPED_UNICODE);
            }

            $message = [
                'topic' => $topic,
                'data' => $stringData,
                'android' => ['priority' => 'high'],
                'apns' => [
                    'headers' => [
                        'apns-priority' => '5',
                        'apns-push-type' => 'background',
                    ],
                    'payload' => ['aps' => ['content-available' => 1]],
                ],
            ];

            $messaging->send($message);
            return true;
        } catch (Exception $e) {
            error_log('FCM topic send error: ' . $e->getMessage());
            return false;
        }
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

            // FCM requires every data value to be a string; non-string values
            // (e.g. integer ids) make the whole send fail. Coerce them here so
            // every caller is safe.
            $stringData = [];
            foreach (($data ?: []) as $key => $value) {
                $stringData[(string) $key] = is_scalar($value)
                    ? (string) $value
                    : json_encode($value, JSON_UNESCAPED_UNICODE);
            }

            $message = [
                'notification' => $notification,
                'data' => $stringData,
                'android' => [
                    'priority' => 'high',
                    'notification' => [
                        'sound' => 'default',
                        'default_sound' => true,
                        'default_vibrate_timings' => true,
                        'notification_priority' => 'PRIORITY_HIGH',
                    ],
                ],
                'apns' => [
                    'payload' => ['aps' => ['sound' => 'default']],
                ],
            ];

            $report = $messaging->sendMulticast($message, $tokens);
            return $report->successes()->count() > 0;
        } catch (Exception $e) {
            error_log('FCM send error: ' . $e->getMessage());
            return false;
        }
    }
}
