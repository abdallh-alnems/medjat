<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Services;

use App\Modules\Notifications\Domain\PushSender;
use App\Shared\Async\AfterResponse;
use App\Support\Value;
use Illuminate\Support\Facades\DB;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;

/**
 * The production sender, over FCM.
 *
 * The Messaging client is resolved on first use, not on construction. Every
 * caller of this treats delivery as best-effort — a push that fails must not
 * fail the thing it was announcing — and building the client reads the
 * credentials file, so constructing it eagerly would turn a missing file into a
 * 500 on sign-in, payroll approval and everything else that might notify
 * somebody. Deferring it puts that failure inside the try/catch where every
 * other delivery failure already lives.
 */
final class FirebasePushSender implements PushSender
{
    /** @var callable(): Messaging */
    private $factory;

    private ?Messaging $messaging = null;

    /**
     * @param  callable(): Messaging  $factory
     */
    public function __construct(callable $factory)
    {
        $this->factory = $factory;
    }

    private function messaging(): Messaging
    {
        return $this->messaging ??= ($this->factory)();
    }

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

        // An empty key would produce a malformed data block rather than a
        // refused send, so it is dropped here.
        $payload = array_filter($data, static fn (string $key): bool => $key !== '', ARRAY_FILTER_USE_KEY);

        // The token lookup above stays on the request — it is one indexed read,
        // and its answer is what the return value means. The round trip to
        // Google is what waits. `true` here is "accepted for delivery", which
        // is what the contract promises and all it ever promised: the send was
        // already best-effort when it was synchronous.
        AfterResponse::run('Push delivery', function () use ($tokens, $title, $body, $payload): void {
            $message = CloudMessage::new()
                ->withNotification(Notification::create($title, $body))
                ->withData($payload);

            /** @var list<string> $tokens */
            $this->messaging()->sendMulticast($message, $tokens);
        }, ['admin_id' => $adminId]);

        return true;
    }

    /**
     * @param  array<string, string>  $data
     */
    public function toTopic(string $topic, array $data): bool
    {
        if ($topic === '') {
            return false;
        }

        // Data-only, deliberately: this is a signal the app acts on, not
        // something to show. A notification block here would put "system
        // maintenance" on every lock screen in the country.
        $payload = array_filter($data, static fn (string $key): bool => $key !== '', ARRAY_FILTER_USE_KEY);

        AfterResponse::run('Topic push', function () use ($topic, $payload): void {
            $this->messaging()->send(CloudMessage::new()->toTopic($topic)->withData($payload));
        }, ['topic' => $topic]);

        return true;
    }
}
