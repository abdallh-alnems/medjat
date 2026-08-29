<?php

declare(strict_types=1);

namespace App\Services\Notifications;

use App\Domain\Notifications\PushSender;
use App\Support\Value;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Throwable;

/**
 * The production sender, over FCM.
 */
final class FirebasePushSender implements PushSender
{
    public function __construct(private readonly Messaging $messaging) {}

    /**
     * @param  array<string, string>  $data
     */
    public function toEmployee(int $employeeId, string $title, string $body, array $data = []): bool
    {
        // An employee's devices hang off their admins row, which is where the
        // push tokens live for both apps.
        $adminId = DB::table('employees')->where('id', $employeeId)->value('admin_id');

        if ($adminId === null) {
            return false;
        }

        return $this->toAdmin(Value::int($adminId), $title, $body, $data);
    }

    /**
     * @param  array<string, string>  $data
     */
    public function toAdmin(int $adminId, string $title, string $body, array $data = []): bool
    {
        $tokens = DB::table('admin_devices')
            ->where('admin_id', $adminId)
            ->where('is_active', 1)
            ->pluck('fcm_token')
            ->filter(static fn (mixed $token): bool => is_string($token) && $token !== '')
            ->values()
            ->all();

        if ($tokens === []) {
            return false;
        }

        try {
            // An empty key would produce a malformed data block rather than a
            // refused send, so it is dropped here.
            $payload = array_filter($data, static fn (string $key): bool => $key !== '', ARRAY_FILTER_USE_KEY);

            $message = CloudMessage::new()
                ->withNotification(Notification::create($title, $body))
                ->withData($payload);

            /** @var list<string> $tokens */
            $this->messaging->sendMulticast($message, $tokens);

            return true;
        } catch (Throwable $e) {
            Log::warning('Push delivery failed', ['admin_id' => $adminId, 'exception' => $e]);

            return false;
        }
    }
}
