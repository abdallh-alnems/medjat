<?php

declare(strict_types=1);

namespace App\Domain\Notifications;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Tells an employee something happened.
 *
 * Two deliveries, deliberately: a row the app reads in its own list, and a push
 * to whatever handset is registered. The row is what makes the notification
 * survive a phone that was off, and the push is what makes it timely — neither
 * on its own is enough.
 *
 * Never throws. A notification that fails to send must not undo the thing it
 * was describing: an approved document stays approved whether or not the
 * employee's phone was reachable.
 */
final class Notifier
{
    public function __construct(private readonly PushSender $push) {}

    /**
     * @param  array<string, string>  $data
     */
    public function notifyEmployee(
        int $tenantId,
        int $employeeId,
        string $type,
        string $titleEn,
        string $titleAr,
        string $bodyEn,
        string $bodyAr,
        array $data = [],
    ): void {
        try {
            DB::table('notifications')->insert([
                'tenant_id' => $tenantId,
                'employee_id' => $employeeId,
                'type' => $type,
                'title' => $titleEn,
                'title_ar' => $titleAr,
                'body' => $bodyEn,
                'body_ar' => $bodyAr,
                'data' => json_encode($data, JSON_UNESCAPED_UNICODE),
                'sent_via' => 'push,in_app',
                'created_at' => DB::raw('NOW()'),
            ]);

            // Arabic, because the employee surface is Arabic-first and the push
            // is read on a lock screen where there is no language toggle.
            $this->push->toEmployee($employeeId, $titleAr, $bodyAr, $data);
        } catch (Throwable $e) {
            Log::warning('Employee notification failed', [
                'employee_id' => $employeeId,
                'type' => $type,
                'exception' => $e,
            ]);
        }
    }
}
