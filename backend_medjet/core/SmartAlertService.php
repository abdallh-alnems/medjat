<?php

final class SmartAlertService
{
    private const DEFAULT_PREFS = [
        'late_absence'      => true,
        'missing_checkout'  => true,
        'document_expiry'   => true,
        'compliance_expiry' => true,
        'leave_events'      => true,
        'payroll_events'    => true,
        'break_events'      => true,
    ];

    public static function dispatch(
        int    $adminId,
        string $prefKey,
        string $type,
        string $titleAr,
        string $bodyAr,
        string $titleEn,
        string $bodyEn,
        ?array $data = null,
        ?string $dedupeKey = null
    ): void {
        try {
            if (!self::prefEnabled($adminId, $prefKey)) {
                return;
            }

            if ($dedupeKey !== null && self::alreadySentToday($adminId, $dedupeKey)) {
                return;
            }

            $notificationData = $data ?? [];
            if ($dedupeKey !== null) {
                $notificationData['dedupe_key'] = $dedupeKey;
            }

            $tenantId = self::getTenantIdForAdmin($adminId);

            Database::execute(
                "INSERT INTO notifications (tenant_id, admin_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'push,in_app', NOW())",
                [
                    $tenantId,
                    $adminId,
                    $type,
                    $titleEn,
                    $titleAr,
                    $bodyEn,
                    $bodyAr,
                    json_encode($notificationData, JSON_UNESCAPED_UNICODE),
                ]
            );

            NotificationService::sendToUser($adminId, $titleEn, $bodyEn, $notificationData);
        } catch (Throwable $e) {
            error_log('SmartAlertService::dispatch error: ' . $e->getMessage());
        }
    }

    public static function recipientsForBranch(int $tenantId, ?int $branchId, string $perm): array
    {
        $admins = Database::fetchAll(
            "SELECT a.id, a.role, a.branch_id
             FROM admins a
             WHERE a.tenant_id = ? AND a.is_active = 1",
            [$tenantId]
        );

        $recipients = [];
        foreach ($admins as $admin) {
            $role = $admin['role'];
            if ($role === 'general_manager' || $role === 'hr') {
                $recipients[] = (int) $admin['id'];
                continue;
            }

            if ($branchId !== null && $admin['branch_id'] != null && (int) $admin['branch_id'] === (int) $branchId) {
                $rolePerms = RoleModel::getPermissions((int) $admin['id'], $tenantId);
                if ($rolePerms === '*' || (is_array($rolePerms) && in_array($perm, $rolePerms, true))) {
                    $recipients[] = (int) $admin['id'];
                }
            }
        }

        return array_unique($recipients);
    }

    private static function prefEnabled(int $adminId, string $prefKey): bool
    {
        $row = Database::fetchOne(
            "SELECT prefs FROM admin_notification_prefs WHERE admin_id = ? LIMIT 1",
            [$adminId]
        );

        if (!$row) {
            return true;
        }

        $prefs = json_decode($row['prefs'], true);
        if (!is_array($prefs) || !array_key_exists($prefKey, $prefs)) {
            return true;
        }

        return (bool) $prefs[$prefKey];
    }

    private static function alreadySentToday(int $adminId, string $dedupeKey): bool
    {
        $row = Database::fetchOne(
            "SELECT id FROM notifications
             WHERE admin_id = ?
               AND JSON_UNQUOTE(JSON_EXTRACT(data, '$.dedupe_key')) = ?
               AND DATE(created_at) = CURDATE()
             LIMIT 1",
            [$adminId, $dedupeKey]
        );

        return $row !== null;
    }

    private static function getTenantIdForAdmin(int $adminId): ?int
    {
        $row = Database::fetchOne(
            "SELECT tenant_id FROM admins WHERE id = ? LIMIT 1",
            [$adminId]
        );
        return $row ? (int) $row['tenant_id'] : null;
    }
}
