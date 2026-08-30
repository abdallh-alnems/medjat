<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Domain;

use App\Support\Value;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Tells the people who can act on something that it is waiting.
 *
 * Addressed to a permission rather than to a person: "whoever can approve
 * documents at this company" survives somebody leaving, which a hard-coded
 * recipient does not.
 *
 * Never throws, for the same reason as the employee notifier — a submission
 * that succeeded must not fail because nobody could be told about it.
 */
final class ManagerAlert
{
    public function __construct(private readonly PushSender $push) {}

    /**
     * @param  array<string, string>  $data
     */
    public function notify(
        int $tenantId,
        string $type,
        string $titleAr,
        string $titleEn,
        string $bodyAr,
        string $bodyEn,
        ?int $aboutEmployeeId = null,
        array $data = [],
    ): void {
        try {
            // General managers and HR: the roles that can act on an approval.
            // A company with neither is misconfigured, not a reason to fail the
            // thing being announced.
            $admins = DB::table('admins')
                ->where('tenant_id', $tenantId)
                ->where('is_active', 1)
                ->whereIn('role', ['general_manager', 'hr'])
                ->pluck('id');

            foreach ($admins as $adminId) {
                DB::table('notifications')->insert([
                    'tenant_id' => $tenantId,
                    'admin_id' => Value::int($adminId),
                    'employee_id' => $aboutEmployeeId,
                    'type' => $type,
                    'title' => $titleEn,
                    'title_ar' => $titleAr,
                    'body' => $bodyEn,
                    'body_ar' => $bodyAr,
                    'data' => json_encode($data, JSON_UNESCAPED_UNICODE),
                    'sent_via' => 'push,in_app',
                    'created_at' => DB::raw('NOW()'),
                ]);

                // Arabic, because the management app is Arabic-first and a
                // push is read on a lock screen with no language toggle.
                $this->push->toAdmin(Value::int($adminId), $titleAr, $bodyAr, $data);
            }
        } catch (Throwable $e) {
            Log::warning('Manager alert failed', ['tenant_id' => $tenantId, 'type' => $type, 'exception' => $e]);
        }
    }
}
