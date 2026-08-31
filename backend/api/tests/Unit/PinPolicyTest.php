<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Shared\Access\PinPolicy;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

/**
 * The PIN rules. Six digits is a small space, so these rules are most of what
 * stands between the browser channel and a dictionary.
 */
final class PinPolicyTest extends TestCase
{
    /**
     * @return list<array{string, string}>
     */
    public static function rejectedPins(): array
    {
        return [
            ['12345', 'length'],
            ['1234567', 'length'],
            ['12a456', 'length'],
            ['', 'length'],
            ['000000', 'repeated'],
            ['777777', 'repeated'],
            ['123456', 'sequence'],
            // The run that a hand-written list of "obvious" PINs always misses.
            ['234567', 'sequence'],
            ['456789', 'sequence'],
            ['987654', 'sequence'],
            ['121212', 'pattern'],
            ['123123', 'pattern'],
            // Reaches the structural rule first — it is a two-digit block
            // repeated, so the banned list never sees it. Kept as a case
            // because that ordering is the point: the general rule should be
            // doing the work, not the list.
            ['696969', 'pattern'],
            // Neither a run nor a repeated block, so only the list catches it.
            ['112233', 'common'],
            ['123321', 'common'],
        ];
    }

    #[DataProvider('rejectedPins')]
    public function test_it_rejects_weak_pins(string $pin, string $reason): void
    {
        $this->assertSame($reason, PinPolicy::rejectReason($pin));
    }

    public function test_it_accepts_an_ordinary_pin(): void
    {
        $this->assertNull(PinPolicy::rejectReason('481920'));
        $this->assertTrue(PinPolicy::isAcceptable('481920'));
    }

    public function test_a_pin_taken_from_the_phone_number_is_rejected(): void
    {
        // The phone is the username on this channel, so a PIN drawn from it is
        // guessable by anyone able to attack the account at all.
        $this->assertSame('phone', PinPolicy::rejectReason('380940', '+201023809407'));
    }

    public function test_the_phone_rule_only_applies_to_that_employees_number(): void
    {
        $this->assertNull(PinPolicy::rejectReason('380940', '+201111111111'));
    }

    public function test_the_phone_rule_ignores_formatting(): void
    {
        $this->assertSame('phone', PinPolicy::rejectReason('102380', '+20 102 380 9407'));
    }

    public function test_every_reason_has_a_message(): void
    {
        // An employee told only that their choice "failed" will try another
        // guessable one, so each reason has to be sayable.
        foreach (['length', 'repeated', 'sequence', 'pattern', 'common', 'phone'] as $reason) {
            $this->assertNotSame(
                PinPolicy::message('unknown-reason'),
                PinPolicy::message($reason),
                "reason '{$reason}' falls through to the generic message"
            );
        }
    }
}
