<?php

declare(strict_types=1);

namespace App\Shared\Async;

use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Work that happens once the caller has already been answered.
 *
 * The old backend had core/Background.php: it called fastcgi_finish_request(),
 * closed the connection, and only then sent the email and the push. Signing in
 * did not wait on SMTP. The port lost that — every Mail::send() and every FCM
 * call moved back onto the request's critical path, so an administrator signing
 * in now waits for a mail server in another country before their screen moves.
 *
 * This puts it back. `terminating` callbacks run after Symfony's Response::send(),
 * which itself calls fastcgi_finish_request() where the SAPI has it — so under
 * PHP-FPM this is the same mechanism as before, and everywhere else the work
 * still runs, just without the early flush.
 *
 * Deliberately not the queue. A queued job needs a worker process, and this
 * codebase has never had one: introducing that dependency at cutover would mean
 * every notification in the product silently stops the first time the worker
 * dies. When a worker does exist, these call sites become ShouldQueue one at a
 * time, and this class is what they replace.
 *
 * Never throws. Every caller of this treats delivery as best-effort, and by the
 * time the task runs there is no response left to fail.
 */
final class AfterResponse
{
    /**
     * @param  string  $what  Names the work in the log line when it fails.
     * @param  callable(): void  $task  Runs after the response has been sent.
     * @param  array<string, mixed>  $context  Logged alongside the failure.
     */
    public static function run(string $what, callable $task, array $context = []): void
    {
        $guarded = static function () use ($what, $task, $context): void {
            try {
                $task();
            } catch (Throwable $e) {
                Log::warning($what.' failed', $context + ['exception' => $e]);
            }
        };

        // A command has no response to come after. The nightly alert run walks
        // every company and pushes as it goes: deferring there would hold every
        // message in memory until the run ended and then fire them in one
        // burst, which is worse than sending each as it is decided. Tests run
        // in console too, which is why they keep observing these side effects
        // synchronously.
        if (app()->runningInConsole()) {
            $guarded();

            return;
        }

        app()->terminating($guarded);
    }
}
