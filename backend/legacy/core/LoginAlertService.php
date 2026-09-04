<?php

final class LoginAlertService {
    public static function handle(array $admin, string $ip, string $userAgent): void {
        try {
            $adminId = (int) $admin['id'];
            if ($adminId <= 0) {
                return;
            }

            $hasPriorLogin = Database::fetchOne(
                "SELECT 1 FROM login_attempts WHERE admin_id = ? AND success = 1 LIMIT 1 OFFSET 1",
                [$adminId]
            );
            if (!$hasPriorLogin) {
                return;
            }

            $knownDevice = Database::fetchOne(
                "SELECT 1 FROM login_attempts WHERE admin_id = ? AND success = 1 AND ip = ? AND user_agent = ? LIMIT 1",
                [$adminId, $ip, $userAgent]
            );
            if ($knownDevice) {
                return;
            }

            $recentAlert = Database::fetchOne(
                "SELECT 1 FROM notifications
                 WHERE admin_id = ?
                   AND type = 'system'
                   AND title = 'New login'
                   AND data->>'$.ip' = ?
                   AND data->>'$.user_agent' = ?
                   AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
                 LIMIT 1",
                [$adminId, $ip, $userAgent]
            );
            if ($recentAlert) {
                return;
            }

            self::fireAlert($admin, $ip, $userAgent);
        } catch (Exception $e) {
            error_log('LoginAlertService error: ' . $e->getMessage());
        }
    }

    private static function fireAlert(array $admin, string $ip, string $userAgent): void {
        $adminId = (int) $admin['id'];
        $tenantId = isset($admin['tenant_id']) ? (int) $admin['tenant_id'] : 0;
        $time = date('Y-m-d H:i');

        $titleAr = 'تسجيل دخول جديد';
        $title = 'New login';
        $bodyAr = "تم تسجيل دخول إلى حسابك من جهاز جديد بتاريخ {$time} (IP: {$ip}).";
        $body = "Your account was accessed from a new device on {$time} (IP: {$ip}).";

        $dataJson = json_encode([
            'type' => 'new_login',
            'ip' => $ip,
            'user_agent' => $userAgent,
            'time' => $time,
        ], JSON_UNESCAPED_UNICODE);

        NotificationService::sendToUser($adminId, $title, $body, ['type' => 'new_login', 'ip' => $ip]);

        Database::execute(
            "INSERT INTO notifications (tenant_id, admin_id, type, title, title_ar, body, body_ar, data, sent_via)
             VALUES (?, ?, 'system', ?, ?, ?, ?, ?, 'push,email,in_app')",
            [
                $tenantId > 0 ? $tenantId : null,
                $adminId,
                $title,
                $titleAr,
                $body,
                $bodyAr,
                $dataJson,
            ]
        );

        if ($tenantId > 0) {
            AuditLogModel::log(
                $tenantId,
                $adminId,
                'login.new_device',
                'admin',
                $adminId,
                ['ip' => $ip, 'ua' => $userAgent]
            );
        }

        if (!empty($admin['email'])) {
            self::sendEmailAlert($admin['email'], $time, $ip);
        }
    }

    private static function sendEmailAlert(string $to, string $time, string $ip): void {
        try {
            $html = '<!DOCTYPE html><html dir="rtl" lang="ar">'
                . '<head><meta charset="UTF-8"></head>'
                . '<body style="font-family:\'IBM Plex Sans Arabic\',Tahoma,Arial,sans-serif;direction:rtl;text-align:right;padding:24px;background:#f9f9f9;">'
                . '<div style="max-width:480px;margin:0 auto;background:#fff;border-radius:12px;padding:32px;box-shadow:0 2px 8px rgba(0,0,0,0.06);">'
                . '<h2 style="color:#1a1a1a;margin:0 0 16px;">تسجيل دخول جديد</h2>'
                . '<p style="color:#444;font-size:15px;line-height:1.7;">تم تسجيل دخول جديد إلى حسابك في Permedjat.</p>'
                . '<table style="width:100%;margin:16px 0;font-size:14px;color:#555;">'
                . '<tr><td style="padding:6px 0;font-weight:600;">التاريخ والوقت:</td><td style="padding:6px 0;">' . htmlspecialchars($time) . '</td></tr>'
                . '<tr><td style="padding:6px 0;font-weight:600;">عنوان IP:</td><td style="padding:6px 0;">' . htmlspecialchars($ip) . '</td></tr>'
                . '</table>'
                . '<hr style="border:none;border-top:1px solid #eee;margin:20px 0;">'
                . '<p style="color:#888;font-size:13px;line-height:1.6;">إن لم تكن أنت، غيّر كلمة السر فوراً.</p>'
                . '</div></body></html>';

            EmailService::send($to, 'تسجيل دخول جديد إلى حسابك في Permedjat', $html);
        } catch (Exception $e) {
            error_log('LoginAlertService email error: ' . $e->getMessage());
        }
    }
}
