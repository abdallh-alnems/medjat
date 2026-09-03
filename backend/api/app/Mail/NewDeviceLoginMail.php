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
 * "Your account was accessed from a new device."
 *
 * No button, deliberately. A security notice that asks somebody to click
 * something is training them to click things in security notices, which is
 * exactly what the phishing version of this email will look like.
 */
final class NewDeviceLoginMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        private readonly string $at,
        private readonly string $ip,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: 'تسجيل دخول جديد إلى حسابك في '.$this->appName());
    }

    public function content(): Content
    {
        return new Content(
            view: 'mail.message',
            with: [
                'lang' => 'ar',
                'appName' => $this->appName(),
                'logoUrl' => Config::string('permedjat.mail.logo_url'),
                'title' => 'تسجيل دخول جديد',
                'intro' => 'تم تسجيل دخول جديد إلى حسابك في '.$this->appName().'.',
                'rows' => [
                    'التاريخ والوقت:' => $this->at,
                    'عنوان IP:' => $this->ip,
                ],
                'footnote' => 'إن لم تكن أنت، غيّر كلمة السر فوراً.',
            ],
        );
    }

    private function appName(): string
    {
        return Config::string('app.name', 'Medjat');
    }
}
