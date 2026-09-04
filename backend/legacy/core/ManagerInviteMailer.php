<?php

/**
 * The "join this company's team" invitation email.
 *
 * Extracted from app/managers/invite.php so the super-admin panel can send the
 * exact same message when it onboards a new client. The person receiving it
 * cannot tell (and should not care) whether their own colleague invited them or
 * we did — same code, same landing page, same 72-hour validity.
 *
 * Everything here is deliberately best-effort: the invitation row is already
 * committed by the time we get called, and the code is also returned in the API
 * response for in-person / WhatsApp sharing. A dead SMTP server must never cost
 * anyone their invitation.
 */
final class ManagerInviteMailer {
    private const ROLE_LABELS = [
        'general_manager' => 'مدير عام',
        'hr' => 'موارد بشرية',
        'branch_manager' => 'مدير فرع',
        'attendance' => 'مسؤول حضور',
        'viewer' => 'مشاهد',
    ];

    /**
     * Public URL of the bridge page that opens the app via its custom scheme and
     * falls back to web/store. Derived from the current request so it works on
     * whatever host the backend is being served from (api.permedjat.com live,
     * localhost:8888 under MAMP).
     */
    public static function joinUrl(string $code): string {
        $scriptName = $_SERVER['SCRIPT_NAME'] ?? '';
        // Every endpoint lives under api/ (api/app, api/admin, api/device) while
        // join_team.php sits at the backend root, so cutting the path at /api/
        // yields the root regardless of what the deployment folder is called.
        $apiPos = strpos($scriptName, '/api/');
        $backendRoot = $apiPos !== false ? substr($scriptName, 0, $apiPos) : '';
        $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
        $host = $_SERVER['HTTP_HOST'] ?? 'api.permedjat.com';

        return $scheme . '://' . $host . $backendRoot
            . '/join_team.php?code=' . rawurlencode($code);
    }

    /**
     * Queue the invitation email. Sent through Background::defer so the slow
     * SMTP round-trip never blocks the API response.
     */
    public static function queue(string $email, string $code, string $role, string $companyName): void {
        $joinUrl = self::joinUrl($code);
        $webBase = rtrim((string) (getenv('CENTRAL_WEB_URL') ?: ''), '/');

        Background::defer(static function () use ($email, $code, $role, $companyName, $webBase, $joinUrl) {
            try {
                EmailService::send(
                    $email,
                    'دعوة للانضمام إلى فريق على Permedjat',
                    self::html($code, $role, $companyName, $joinUrl, $webBase)
                );
            } catch (\Throwable $e) {
                error_log('Invite email failed: ' . $e->getMessage());
            }
        });
    }

    public static function html(
        string $code,
        string $role,
        string $companyName,
        string $joinUrl,
        string $webBase = ''
    ): string {
        $roleLabel = self::ROLE_LABELS[$role] ?? $role;
        $safeCompany = htmlspecialchars($companyName, ENT_QUOTES, 'UTF-8');
        $safeRole = htmlspecialchars($roleLabel, ENT_QUOTES, 'UTF-8');
        $safeCode = htmlspecialchars($code, ENT_QUOTES, 'UTF-8');

        $intro = $companyName !== ''
            ? "تمت دعوتك للانضمام إلى فريق «{$safeCompany}» على Permedjat بدور <strong>{$safeRole}</strong>."
            : "تمت دعوتك للانضمام إلى فريق على Permedjat بدور <strong>{$safeRole}</strong>.";

        $safeJoin = htmlspecialchars($joinUrl, ENT_QUOTES, 'UTF-8');
        $linkBlock =
            '<p style="text-align:center;margin:24px 0;">'
            . '<a href="' . $safeJoin . '" style="display:inline-block;background:#2E7D6B;color:#fff;'
            . 'text-decoration:none;padding:14px 32px;border-radius:8px;font-weight:600;font-size:16px;">'
            . 'فتح التطبيق والانضمام</a>'
            . '</p>';
        if ($webBase !== '') {
            $webUrl = htmlspecialchars(
                $webBase . '/onboarding?code=' . rawurlencode($code),
                ENT_QUOTES,
                'UTF-8'
            );
            $linkBlock .=
                '<p style="text-align:center;margin:-8px 0 8px;">'
                . '<a href="' . $webUrl . '" style="color:#2E7D6B;font-size:14px;">أو الفتح من المتصفح</a>'
                . '</p>';
        }

        return '<!DOCTYPE html><html dir="rtl" lang="ar">'
            . '<head><meta charset="UTF-8"></head>'
            . '<body style="font-family:\'IBM Plex Sans Arabic\',Tahoma,Arial,sans-serif;direction:rtl;text-align:right;padding:24px;background:#f9f9f9;">'
            . '<div style="max-width:480px;margin:0 auto;background:#fff;border-radius:12px;padding:32px;box-shadow:0 2px 8px rgba(0,0,0,0.06);">'
            . '<h2 style="color:#1a1a1a;margin:0 0 16px;">دعوة للانضمام إلى الفريق</h2>'
            . '<p style="color:#444;font-size:15px;line-height:1.7;">' . $intro . '</p>'
            . '<p style="color:#444;font-size:15px;line-height:1.7;">استخدم رمز الدعوة التالي:</p>'
            . '<div style="text-align:center;margin:16px 0;">'
            . '<span style="display:inline-block;border:2px solid #2E7D6B;border-radius:8px;padding:14px 28px;'
            . 'font-size:28px;font-weight:700;letter-spacing:6px;color:#2E7D6B;">' . $safeCode . '</span>'
            . '</div>'
            . $linkBlock
            . '<p style="color:#444;font-size:14px;line-height:1.8;">'
            . 'افتح تطبيق Permedjat للإدارة (أو الموقع)، ثم اختر «الانضمام إلى شركة» وأدخل هذا الرمز. '
            . 'إن لم يكن لديك حساب بعد، أنشئ حسابًا بنفس هذا البريد الإلكتروني أولًا.'
            . '</p>'
            . '<hr style="border:none;border-top:1px solid #eee;margin:20px 0;">'
            . '<p style="color:#888;font-size:13px;line-height:1.6;">هذا الرمز صالح لمدة 72 ساعة ويُستخدم مرة واحدة. إن لم تكن تتوقع هذه الدعوة، تجاهل هذه الرسالة.</p>'
            . '</div></body></html>';
    }
}
