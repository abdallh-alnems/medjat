<?php

declare(strict_types=1);

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Config;

/**
 * The two transactional emails on the auth path: verify your address, and reset
 * your password.
 *
 * One Mailable rather than two, because they differ only in their strings — the
 * layout, the branding and the Firebase action link are identical, and keeping
 * them together is what stops the two drifting apart visually.
 */
final class AuthActionMail extends Mailable
{
    use Queueable, SerializesModels;

    public const VERIFY = 'verify';

    public const RESET = 'reset';

    public function __construct(
        private readonly string $kind,
        private readonly string $lang,
        private readonly string $name,
        private readonly string $link,
    ) {}

    public function envelope(): Envelope
    {
        $app = $this->appName();
        $english = $this->lang === 'en';

        $subject = match (true) {
            $this->kind === self::VERIFY && $english => "Verify your email · {$app}",
            $this->kind === self::VERIFY => "تفعيل بريدك الإلكتروني · {$app}",
            $english => "Reset your password · {$app}",
            default => "إعادة تعيين كلمة المرور · {$app}",
        };

        return new Envelope(subject: $subject);
    }

    public function content(): Content
    {
        $strings = $this->strings();

        return new Content(
            view: 'mail.auth-action',
            with: [
                'lang' => $this->lang,
                'appName' => $this->appName(),
                'logoUrl' => Config::string('medjat.mail.logo_url'),
                'link' => $this->link,
                'greeting' => $this->greeting(),
                'title' => $strings['title'],
                'intro' => $strings['intro'],
                'button' => $strings['button'],
                'ignore' => $strings['ignore'],
            ],
        );
    }

    private function greeting(): string
    {
        if (trim($this->name) === '') {
            return '';
        }

        return $this->lang === 'en' ? "Hi {$this->name}," : "مرحبًا {$this->name}،";
    }

    /**
     * @return array{title: string, intro: string, button: string, ignore: string}
     */
    private function strings(): array
    {
        $app = $this->appName();
        $english = $this->lang === 'en';

        if ($this->kind === self::VERIFY) {
            return $english
                ? [
                    'title' => 'Confirm your email address',
                    'intro' => "Thanks for creating your {$app} account. Tap the button below to activate your account and get started.",
                    'button' => 'Activate my account',
                    'ignore' => "If you didn't create this account, you can safely ignore this email.",
                ]
                : [
                    'title' => 'فعّل بريدك الإلكتروني',
                    'intro' => "شكرًا لإنشائك حساب {$app}. اضغط الزر بالأسفل لتفعيل حسابك والبدء في استخدام التطبيق.",
                    'button' => 'تفعيل حسابي',
                    'ignore' => 'إذا لم تُنشئ هذا الحساب، يمكنك تجاهل هذه الرسالة بأمان.',
                ];
        }

        return $english
            ? [
                'title' => 'Reset your password',
                'intro' => 'We received a request to reset your password. Tap the button below to choose a new one.',
                'button' => 'Reset my password',
                'ignore' => "If you didn't request this, you can safely ignore this email — your password will stay the same.",
            ]
            : [
                'title' => 'إعادة تعيين كلمة المرور',
                'intro' => 'وصلنا طلب لإعادة تعيين كلمة المرور الخاصة بك. اضغط الزر بالأسفل لاختيار كلمة مرور جديدة.',
                'button' => 'إعادة تعيين كلمة المرور',
                'ignore' => 'إذا لم تطلب ذلك، يمكنك تجاهل هذه الرسالة بأمان ولن تتغير كلمة المرور.',
            ];
    }

    private function appName(): string
    {
        return Config::string('app.name');
    }
}
