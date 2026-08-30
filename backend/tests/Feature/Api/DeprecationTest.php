<?php

declare(strict_types=1);

namespace Tests\Feature\Api;

use Tests\TestCase;

/**
 * What a caller on a legacy URL is told.
 */
final class DeprecationTest extends TestCase
{
    public function test_a_legacy_url_announces_that_it_is_deprecated(): void
    {
        $this->get('/join.php?token='.str_repeat('a1', 12))
            ->assertOk()
            ->assertHeader('Deprecation', 'true')
            ->assertHeader('Link', '</v1>; rel="successor-version"');
    }

    public function test_a_current_url_says_nothing(): void
    {
        $this->get('/join?token='.str_repeat('a1', 12))
            ->assertOk()
            ->assertHeaderMissing('Deprecation');
    }

    public function test_the_announcement_carries_no_sunset_date(): void
    {
        // Announcing a date we cannot keep is worse than announcing none: it is
        // a promise to break somebody's phone on a day chosen before we knew
        // who was still calling.
        $this->get('/join.php')->assertOk()->assertHeaderMissing('Sunset');
    }

    public function test_the_announcement_does_not_change_the_response(): void
    {
        $legacy = $this->get('/join_team.php?code=AB12CD34')->assertOk();
        $modern = $this->get('/join_team?code=AB12CD34')->assertOk();

        $this->assertSame($modern->getContent(), $legacy->getContent());
    }
}
