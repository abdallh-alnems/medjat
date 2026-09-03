<?php

declare(strict_types=1);

namespace Tests\Feature\Landing;

use Illuminate\Support\Facades\Config;
use Tests\TestCase;

/**
 * The deep-link landing pages and the association files.
 *
 * None of this touches the database, which is why there is no transaction here.
 */
final class DeepLinkTest extends TestCase
{
    public function test_a_valid_employee_link_points_at_the_app(): void
    {
        $this->get('/join?token='.str_repeat('a1', 12))
            ->assertOk()
            ->assertSee('تطبيق Medjat للموظفين', false)
            ->assertSee('play.google.com', false);
    }

    public function test_a_malformed_employee_token_says_so_rather_than_pretending(): void
    {
        $this->get('/join?token=not-a-token')
            ->assertOk()
            ->assertSee('غير صالح', false);
    }

    public function test_a_missing_token_is_still_a_page_not_an_error(): void
    {
        // Somebody who opened the bare URL should be told what the app is, not
        // shown a 404.
        $this->get('/join')->assertOk()->assertSee('تطبيق Medjat للموظفين', false);
    }

    public function test_an_invitation_link_shows_the_code_and_opens_the_app(): void
    {
        $response = $this->get('/join_team?code=AB12CD34')->assertOk();

        // Both: a custom-scheme link is silently dropped by some in-app
        // browsers, and the code can always be typed.
        $response->assertSee('AB12CD34', false);
        $response->assertSee('medjatcentral://join?code=AB12CD34', false);
    }

    public function test_an_invitation_link_offers_the_web_app_when_one_is_configured(): void
    {
        Config::set('permedjat.web.base_url', 'https://app.medjatapp.com');

        $this->get('/join_team?code=AB12CD34')
            ->assertOk()
            ->assertSee('https://app.medjatapp.com/onboarding?code=AB12CD34', false);
    }

    public function test_a_malformed_invitation_code_is_refused_without_a_scheme_link(): void
    {
        $response = $this->get('/join_team?code=<script>')->assertOk();

        $response->assertSee('غير صالح', false);
        $response->assertDontSee('medjatcentral://', false);
    }

    public function test_the_page_does_not_echo_an_injected_code_as_markup(): void
    {
        $this->get('/join_team?code=AAAA"><b>x</b>')
            ->assertOk()
            ->assertDontSee('<b>x</b>', false);
    }

    public function test_an_unpublished_store_listing_is_left_out(): void
    {
        // A dead link is worse than none.
        Config::set('permedjat.stores.employee_ios', '');

        $this->get('/join?token='.str_repeat('a1', 12))
            ->assertOk()
            ->assertDontSee('App Store', false);
    }

    public function test_the_legacy_filenames_still_answer(): void
    {
        // Published builds and already-sent emails link to these.
        $this->get('/join?token='.str_repeat('a1', 12))->assertOk();
        $this->get('/join_team?code=AB12CD34')->assertOk()->assertSee('AB12CD34', false);
    }

    public function test_the_api_host_serves_the_management_apps_association_files(): void
    {
        $this->get('http://api.medjatapp.com/.well-known/assetlinks.json')
            ->assertOk()
            ->assertHeader('Content-Type', 'application/json')
            ->assertSee('medjat_central', false);
    }

    public function test_the_bare_domain_serves_the_employee_apps_association_files(): void
    {
        // Two apps, two domains: serving the wrong pair does not fail loudly,
        // the link just quietly opens a web page instead of the app.
        $this->get('http://medjatapp.com/.well-known/assetlinks.json')
            ->assertOk()
            ->assertSee('com.khawarizmie.medjat', false)
            ->assertDontSee('medjat_central', false);
    }

    public function test_the_extensionless_apple_file_is_served_as_json(): void
    {
        // The OS refuses anything that is not.
        $this->get('http://api.medjatapp.com/.well-known/apple-app-site-association')
            ->assertOk()
            ->assertHeader('Content-Type', 'application/json')
            ->assertSee('applinks', false);
    }

    public function test_nothing_else_under_well_known_is_served(): void
    {
        $this->get('/.well-known/security.txt')->assertNotFound();
        $this->get('/.well-known/../.env')->assertNotFound();
    }
}
