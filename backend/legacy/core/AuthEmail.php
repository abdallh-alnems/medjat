<?php

/**
 * Branded, bilingual (ar/en) transactional auth emails.
 * The action button links to Firebase's own default action page (verify / reset);
 * only the email design is customized here.
 * Free design — edit the strings/markup here to control exactly what users see.
 */
final class AuthEmail {
    // ── Email verification (signup) ─────────────────────────
    public static function verifySubject(string $lang): string {
        $app = self::appName();
        return $lang === 'en'
            ? "Verify your email · {$app}"
            : "تفعيل بريدك الإلكتروني · {$app}";
    }

    public static function verifyHtml(string $lang, string $name, string $link): string {
        $app = self::appName();
        $strings = $lang === 'en'
            ? [
                'title'  => 'Confirm your email address',
                'intro'  => "Thanks for creating your {$app} account. Tap the button below to activate your account and get started.",
                'button' => 'Activate my account',
                'ignore' => "If you didn't create this account, you can safely ignore this email.",
            ]
            : [
                'title'  => 'فعّل بريدك الإلكتروني',
                'intro'  => "شكرًا لإنشائك حساب {$app}. اضغط الزر بالأسفل لتفعيل حسابك والبدء في استخدام التطبيق.",
                'button' => 'تفعيل حسابي',
                'ignore' => 'إذا لم تُنشئ هذا الحساب، يمكنك تجاهل هذه الرسالة بأمان.',
            ];
        return self::render($lang, $name, $link, $strings);
    }

    // ── Password reset (forgot password) ────────────────────
    public static function resetSubject(string $lang): string {
        $app = self::appName();
        return $lang === 'en'
            ? "Reset your password · {$app}"
            : "إعادة تعيين كلمة المرور · {$app}";
    }

    public static function resetHtml(string $lang, string $name, string $link): string {
        $app = self::appName();
        $strings = $lang === 'en'
            ? [
                'title'  => 'Reset your password',
                'intro'  => "We received a request to reset the password for your {$app} account. Tap the button below to choose a new password.",
                'button' => 'Reset password',
                'ignore' => "If you didn't request this, you can safely ignore this email — your password won't change.",
            ]
            : [
                'title'  => 'إعادة تعيين كلمة المرور',
                'intro'  => "تلقّينا طلبًا لإعادة تعيين كلمة مرور حسابك في {$app}. اضغط الزر بالأسفل لاختيار كلمة مرور جديدة.",
                'button' => 'إعادة تعيين كلمة المرور',
                'ignore' => 'إذا لم تطلب ذلك، يمكنك تجاهل هذه الرسالة بأمان — لن تتغيّر كلمة مرورك.',
            ];
        return self::render($lang, $name, $link, $strings);
    }

    // ── Shared layout ───────────────────────────────────────
    private static function render(string $lang, string $name, string $link, array $s): string {
        $app = htmlspecialchars(self::appName());
        $brand = self::sanitizeColor(getenv('APP_BRAND_COLOR') ?: '#2E7D6B');
        $logoUrl = getenv('APP_LOGO_URL') ?: '';
        $safeLink = htmlspecialchars($link, ENT_QUOTES);
        $name = htmlspecialchars(trim($name));

        $dir = $lang === 'en' ? 'ltr' : 'rtl';
        $align = $lang === 'en' ? 'left' : 'right';
        $greeting = $lang === 'en'
            ? ($name !== '' ? "Hi {$name}," : 'Hello,')
            : ($name !== '' ? "مرحبًا {$name}،" : 'مرحبًا،');
        $footer = $lang === 'en'
            ? '© ' . date('Y') . " {$app}. All rights reserved."
            : '© ' . date('Y') . " {$app}. جميع الحقوق محفوظة.";

        $logoBlock = $logoUrl !== ''
            ? '<img src="' . htmlspecialchars($logoUrl, ENT_QUOTES) . '" alt="' . $app . '" style="height:48px;width:auto;display:inline-block;" />'
            : '<span style="font-size:24px;font-weight:700;color:' . $brand . ';">' . $app . '</span>';

        return '<!DOCTYPE html><html dir="' . $dir . '" lang="' . $lang . '">'
            . '<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>'
            . '<body style="margin:0;padding:0;background:#f4f6f8;">'
            . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f8;padding:32px 12px;">'
            . '<tr><td align="center">'
            . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.06);">'
            . '<tr><td align="center" style="padding:32px 32px 8px;">' . $logoBlock . '</td></tr>'
            . '<tr><td style="padding:16px 32px 8px;direction:' . $dir . ';text-align:' . $align . ';font-family:\'IBM Plex Sans Arabic\',-apple-system,Segoe UI,Tahoma,Arial,sans-serif;">'
            . '<h1 style="margin:0 0 12px;font-size:20px;color:#1a1a1a;">' . $s['title'] . '</h1>'
            . '<p style="margin:0 0 8px;font-size:15px;color:#444;line-height:1.7;">' . $greeting . '</p>'
            . '<p style="margin:0 0 24px;font-size:15px;color:#444;line-height:1.7;">' . $s['intro'] . '</p>'
            . '</td></tr>'
            . '<tr><td align="center" style="padding:0 32px 28px;">'
            . '<a href="' . $safeLink . '" style="display:inline-block;background:' . $brand . ';color:#ffffff;text-decoration:none;font-size:16px;font-weight:600;padding:14px 36px;border-radius:10px;font-family:\'IBM Plex Sans Arabic\',-apple-system,Segoe UI,Tahoma,Arial,sans-serif;">' . $s['button'] . '</a>'
            . '</td></tr>'
            . '<tr><td style="padding:20px 32px 32px;border-top:1px solid #eef0f2;direction:' . $dir . ';text-align:' . $align . ';font-family:\'IBM Plex Sans Arabic\',Tahoma,Arial,sans-serif;">'
            . '<p style="margin:0 0 6px;font-size:12px;color:#aaa;line-height:1.6;">' . $s['ignore'] . '</p>'
            . '<p style="margin:0;font-size:12px;color:#bbb;">' . $footer . '</p>'
            . '</td></tr>'
            . '</table></td></tr></table></body></html>';
    }

    private static function appName(): string {
        return getenv('APP_NAME') ?: 'Permedjat';
    }

    private static function sanitizeColor(string $color): string {
        return preg_match('/^#[0-9a-fA-F]{3,8}$/', $color) ? $color : '#2E7D6B';
    }
}
