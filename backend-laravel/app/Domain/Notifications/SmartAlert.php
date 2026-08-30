<?php

declare(strict_types=1);

namespace App\Domain\Notifications;

use App\Domain\Access\Permissions;
use App\Support\Value;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * The nightly alerts: something a manager should look at.
 *
 * Three things make this different from an ordinary notification. It goes to
 * whoever holds the relevant permission at the relevant branch, not to a named
 * person. It respects the recipient's own preferences, because an alert nobody
 * wants is how people learn to ignore the ones that matter. And it deduplicates
 * per day, so an outage that lasts a week produces one notice a day rather than
 * one per cron run.
 */
final class SmartAlert
{
    public function __construct(private readonly PushSender $push) {}

    /**
     * @param  array<string, mixed>  $data
     */
    public function dispatch(
        int $adminId,
        string $prefKey,
        string $type,
        string $titleAr,
        string $bodyAr,
        string $titleEn,
        string $bodyEn,
        array $data = [],
        ?string $dedupeKey = null,
    ): bool {
        try {
            if (! self::wanted($adminId, $prefKey)) {
                return false;
            }

            if ($dedupeKey !== null && self::sentToday($adminId, $dedupeKey)) {
                return false;
            }

            if ($dedupeKey !== null) {
                $data['dedupe_key'] = $dedupeKey;
            }

            $tenantId = Value::nullableInt(DB::table('admins')->where('id', $adminId)->value('tenant_id'));

            DB::table('notifications')->insert([
                'tenant_id' => $tenantId,
                'admin_id' => $adminId,
                'type' => $type,
                'title' => $titleEn,
                'title_ar' => $titleAr,
                'body' => $bodyEn,
                'body_ar' => $bodyAr,
                'data' => json_encode($data, JSON_UNESCAPED_UNICODE),
                'sent_via' => 'push,in_app',
                'created_at' => DB::raw('NOW()'),
            ]);

            $this->push->toAdmin($adminId, $titleAr, $bodyAr, self::stringly($data));

            return true;
        } catch (Throwable $e) {
            // One recipient's failure must not stop the rest of the run.
            Log::warning('Smart alert failed', [
                'admin_id' => $adminId, 'pref' => $prefKey, 'exception' => $e,
            ]);

            return false;
        }
    }

    /**
     * Who should hear about something at this branch.
     *
     * General managers and HR hear about everything, wherever it happened.
     * Everybody else hears about their own branch, and only if they hold the
     * permission that would let them act on it — telling somebody about a
     * problem they cannot fix is noise with a false sense of duty attached.
     *
     * @return list<int>
     */
    public static function recipientsForBranch(int $tenantId, ?int $branchId, string $permission): array
    {
        $admins = DB::table('admins')
            ->where('tenant_id', $tenantId)->where('is_active', 1)
            ->get(['id', 'role', 'branch_id'])
            ->all();

        $recipients = [];

        foreach ($admins as $row) {
            /** @var array<string, mixed> $admin */
            $admin = (array) $row;

            $adminId = Value::int($admin['id'] ?? null);
            $role = Value::string($admin['role'] ?? null);

            if ($role === 'general_manager' || $role === 'hr') {
                $recipients[$adminId] = $adminId;

                continue;
            }

            $adminBranch = Value::nullableInt($admin['branch_id'] ?? null);

            if ($branchId === null || $adminBranch === null || $adminBranch !== $branchId) {
                continue;
            }

            if (Permissions::holds($adminId, $tenantId, $role, $permission)) {
                $recipients[$adminId] = $adminId;
            }
        }

        return array_values($recipients);
    }

    /**
     * Whether this recipient still wants this kind of alert.
     *
     * Absent means yes: a new alert type reaches everybody until somebody turns
     * it off, rather than silently reaching nobody until they opt in.
     */
    private static function wanted(int $adminId, string $prefKey): bool
    {
        $stored = DB::table('admin_notification_prefs')->where('admin_id', $adminId)->value('prefs');

        if (! is_string($stored) || $stored === '') {
            return true;
        }

        $prefs = json_decode($stored, true);

        if (! is_array($prefs) || ! array_key_exists($prefKey, $prefs)) {
            return true;
        }

        return (bool) $prefs[$prefKey];
    }

    private static function sentToday(int $adminId, string $dedupeKey): bool
    {
        return DB::table('notifications')
            ->where('admin_id', $adminId)
            ->whereRaw("JSON_UNQUOTE(JSON_EXTRACT(data, '$.dedupe_key')) = ?", [$dedupeKey])
            // The database's own clock, matching the timestamp it wrote.
            ->whereRaw('DATE(created_at) = CURDATE()')
            ->exists();
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, string>
     */
    private static function stringly(array $data): array
    {
        $flat = [];

        foreach ($data as $key => $value) {
            $flat[$key] = is_scalar($value) ? (string) $value : json_encode($value);
        }

        /** @var array<string, string> */
        return array_map(static fn (mixed $v): string => Value::string($v), $flat);
    }
}
