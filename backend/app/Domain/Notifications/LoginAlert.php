<?php

declare(strict_types=1);

namespace App\Domain\Notifications;

use App\Domain\Audit\AuditLog;
use App\Mail\NewDeviceLoginMail;
use App\Models\Admin;
use App\Support\Value;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * Tells somebody their account was signed into from a device they have not used
 * before.
 *
 * Three conditions, each there to stop the alert becoming noise — and an alert
 * people learn to ignore is worse than none, because this is the one that
 * matters when an account is actually taken.
 *
 * Never throws: an alert that failed must not fail the sign-in it was about.
 */
final class LoginAlert
{
    /** Long enough that a flapping IP does not re-alert all afternoon. */
    private const REPEAT_WINDOW_HOURS = 24;

    public function __construct(private readonly PushSender $push) {}

    public function handle(Admin $admin, string $ip, string $userAgent): void
    {
        try {
            // The sign-in being alerted about is already in login_attempts —
            // it is recorded before this runs — so every count here includes
            // it, and "has this happened before" means a count above one.
            //
            // The original missed that on the second check: it asked whether
            // any successful attempt existed from this address and agent, which
            // was always true because it had just written one, so the alert
            // could never fire. The first check carried an OFFSET 1 for exactly
            // this reason, so the trap was known — it just was not applied
            // twice.
            $successfulLogins = DB::table('login_attempts')
                ->where('admin_id', $admin->id)->where('success', 1)
                ->count();

            // Nobody is told about the sign-in that created their account: a
            // first device is not a new one.
            if ($successfulLogins < 2) {
                return;
            }

            $timesFromThisDevice = DB::table('login_attempts')
                ->where('admin_id', $admin->id)->where('success', 1)
                ->where('ip', $ip)->where('user_agent', $userAgent)
                ->count();

            if ($timesFromThisDevice > 1) {
                return;
            }

            if ($this->alreadyWarned($admin->id, $ip, $userAgent)) {
                return;
            }

            $this->fire($admin, $ip, $userAgent);
        } catch (Throwable $e) {
            Log::warning('Login alert failed', ['admin_id' => $admin->id, 'exception' => $e]);
        }
    }

    private function alreadyWarned(int $adminId, string $ip, string $userAgent): bool
    {
        return DB::table('notifications')
            ->where('admin_id', $adminId)
            ->where('type', 'system')
            ->whereRaw("JSON_UNQUOTE(JSON_EXTRACT(data, '$.ip')) = ?", [$ip])
            ->whereRaw("JSON_UNQUOTE(JSON_EXTRACT(data, '$.user_agent')) = ?", [$userAgent])
            ->whereRaw('created_at >= DATE_SUB(NOW(), INTERVAL ? HOUR)', [self::REPEAT_WINDOW_HOURS])
            ->exists();
    }

    private function fire(Admin $admin, string $ip, string $userAgent): void
    {
        $at = now()->format('Y-m-d H:i');

        $titleAr = 'تسجيل دخول جديد';
        $title = 'New login';
        $bodyAr = "تم تسجيل دخول إلى حسابك من جهاز جديد بتاريخ {$at} (IP: {$ip}).";
        $body = "Your account was accessed from a new device on {$at} (IP: {$ip}).";

        DB::table('notifications')->insert([
            'tenant_id' => $admin->tenant_id,
            'admin_id' => $admin->id,
            'type' => 'system',
            'title' => $title,
            'title_ar' => $titleAr,
            'body' => $body,
            'body_ar' => $bodyAr,
            'data' => json_encode([
                'type' => 'new_login',
                'ip' => $ip,
                // Stored because the repeat check reads it back: the same
                // person on the same laptop should be told once, not daily.
                'user_agent' => $userAgent,
                'time' => $at,
            ], JSON_UNESCAPED_UNICODE),
            'sent_via' => 'push,email,in_app',
            'created_at' => DB::raw('NOW()'),
        ]);

        $this->push->toAdmin($admin->id, $titleAr, $bodyAr, ['type' => 'new_login', 'ip' => $ip]);

        if ($admin->tenant_id !== null) {
            AuditLog::record($admin->tenant_id, $admin->id, 'login.new_device', 'admin', $admin->id, [
                'ip' => $ip,
                'ua' => $userAgent,
            ]);
        }

        $email = Value::nullableString($admin->getAttribute('email'));

        if ($email !== null && $email !== '') {
            try {
                Mail::to($email)->send(new NewDeviceLoginMail($at, $ip));
            } catch (Throwable $e) {
                // The in-app notice already landed; the email is the extra.
                Log::warning('Login alert email failed', ['admin_id' => $admin->id, 'exception' => $e]);
            }
        }
    }
}
