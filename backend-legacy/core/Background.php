<?php

/**
 * Runs work *after* the HTTP response has been sent to the client, so slow
 * side-effects (email, FCM push, audit writes) never sit on the request's
 * critical path.
 *
 * On PHP-FPM / LiteSpeed the response is flushed and the connection closed
 * first (`fastcgi_finish_request` / `litespeed_finish_request`), so the user
 * gets an instant reply while the deferred task runs in the background. On
 * servers that expose neither (e.g. Apache mod_php), the task still runs during
 * shutdown — after the script's `exit` — just without the early flush.
 */
final class Background {
    /** @var callable[] */
    private static array $tasks = [];
    private static bool $registered = false;

    /** Queue a task to run once the response has been delivered. */
    public static function defer(callable $task): void {
        self::$tasks[] = $task;

        if (self::$registered) {
            return;
        }
        self::$registered = true;

        // Keep processing even if the client disconnects after the flush.
        ignore_user_abort(true);
        register_shutdown_function([self::class, 'run']);
    }

    /** Shutdown handler: flush the response, then drain the queued tasks. */
    public static function run(): void {
        if (function_exists('fastcgi_finish_request')) {
            fastcgi_finish_request();
        } elseif (function_exists('litespeed_finish_request')) {
            litespeed_finish_request();
        }

        foreach (self::$tasks as $task) {
            try {
                $task();
            } catch (\Throwable $e) {
                error_log('Background task error: ' . $e->getMessage());
            }
        }
        self::$tasks = [];
    }
}
