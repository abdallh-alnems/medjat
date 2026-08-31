<?php

declare(strict_types=1);

namespace App\Mail;

use App\Modules\Team\Domain\ManagerInvitation;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Config;

/**
 * "Join this company's team on Medjat."
 *
 * One message whether a colleague sent it or the support desk did while
 * onboarding a new client. The person receiving it cannot tell, and should not
 * care: same code, same landing page, same window.
 */
final class TeamInvitationMail extends Mailable
{
    use Queueable, SerializesModels;

    /** @var array<string, string> */
    private const ROLE_LABELS = [
        'general_manager' => 'مدير عام',
        'hr' => 'موارد بشرية',
        'branch_manager' => 'مدير فرع',
        'attendance' => 'مسؤول حضور',
        'viewer' => 'مشاهد',
    ];

    public function __construct(
        private readonly string $code,
        private readonly string $role,
        private readonly string $companyName,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: 'دعوة للانضمام إلى فريق على '.$this->appName());
    }

    public function content(): Content
    {
        $roleLabel = self::ROLE_LABELS[$this->role] ?? $this->role;

        return new Content(
            view: 'mail.message',
            with: [
                'lang' => 'ar',
                'appName' => $this->appName(),
                'logoUrl' => Config::string('medjat.mail.logo_url'),
                'title' => 'دعوة للانضمام',
                'intro' => "تمت دعوتك للانضمام إلى فريق «{$this->companyName}» بصفة {$roleLabel}."
                    .' افتح الرابط أدناه أو أدخل الرمز في التطبيق.',
                'code' => $this->code,
                'link' => ManagerInvitation::joinUrl($this->code),
                'button' => 'انضم إلى الفريق',
                'footnote' => 'تنتهي صلاحية الدعوة خلال '.ManagerInvitation::VALIDITY_HOURS
                    .' ساعة. إن لم تكن تتوقع هذه الرسالة، تجاهلها.',
            ],
        );
    }

    private function appName(): string
    {
        return Config::string('app.name', 'Medjat');
    }
}
