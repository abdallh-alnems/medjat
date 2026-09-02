<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Shared\Async\AfterResponse;
use Illuminate\Support\Facades\Log;
use RuntimeException;
use Tests\TestCase;

/**
 * The replacement for the old backend's core/Background.php.
 *
 * Two properties matter and neither is obvious from reading the call sites: the
 * work runs, and a failure in it never reaches the caller. Everything routed
 * through here — every push, every transactional email — is announcing
 * something that has already happened, so an exception escaping would fail the
 * sign-in or the approval that had already succeeded.
 */
final class AfterResponseTest extends TestCase
{
    public function test_the_work_runs(): void
    {
        $ran = false;

        AfterResponse::run('Test task', function () use (&$ran): void {
            $ran = true;
        });

        // Console context, which the suite runs in: the task runs inline rather
        // than waiting for a response that is never sent. That is deliberate —
        // the nightly alert run pushes as it walks, and deferring there would
        // hold every message until the end and fire them in one burst.
        $this->assertTrue($ran);
    }

    public function test_a_failure_is_logged_and_never_thrown(): void
    {
        Log::shouldReceive('warning')
            ->once()
            ->withArgs(function (string $message, array $context): bool {
                return $message === 'Sending the thing failed'
                    && $context['admin_id'] === 7
                    && $context['exception'] instanceof RuntimeException;
            });

        AfterResponse::run('Sending the thing', static function (): void {
            throw new RuntimeException('the mail server is down');
        }, ['admin_id' => 7]);

        // Reaching here is the assertion: the caller was not disturbed.
        $this->addToAssertionCount(1);
    }
}
