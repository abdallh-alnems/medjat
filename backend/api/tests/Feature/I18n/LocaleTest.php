<?php

declare(strict_types=1);

namespace Tests\Feature\I18n;

use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

/**
 * Which language the API answers in.
 *
 * The header is the only thing that decides. Before it was read, every client
 * got Arabic regardless of what it asked for, including the English builds of
 * the employee app and the web port.
 */
final class LocaleTest extends TestCase
{
    use DatabaseTransactions;

    /**
     * The kiosk guard refuses an unpaired device with a translated message, so
     * it exercises the header without needing any fixture: the point here is
     * the language of the reply, not the reply.
     */
    private function refusal(?string $acceptLanguage): string
    {
        // A token that is present but unknown: that is the branch of the guard
        // whose message is translated.
        // The test client sends "en-us,en;q=0.5" of its own accord, so asking
        // for nothing has to be spelled out rather than left off.
        $test = $this
            ->withHeader('X-Kiosk-Token', 'not-a-real-token')
            ->withHeader('Accept-Language', $acceptLanguage ?? '');

        $response = $test->postJson('/v1/kiosk/heartbeat');

        return Value::string($response->json('message'));
    }

    public function test_the_configured_language_is_used_when_none_is_asked_for(): void
    {
        $this->assertSame(__('messages.kiosk_token_invalid', [], 'ar'), $this->refusal(null));
    }

    public function test_a_client_asking_for_english_is_answered_in_english(): void
    {
        $this->assertSame(__('messages.kiosk_token_invalid', [], 'en'), $this->refusal('en'));
    }

    public function test_a_regional_tag_resolves_to_its_language(): void
    {
        // "ar-EG" and "ar" are the same file to us; so are en-GB and en.
        $this->assertSame(__('messages.kiosk_token_invalid', [], 'en'), $this->refusal('en-GB'));
    }

    public function test_quality_values_decide_the_winner_not_position(): void
    {
        // A browser that lists Arabic first but weights English higher means
        // English. Taking the leftmost entry would get this backwards.
        $this->assertSame(__('messages.kiosk_token_invalid', [], 'en'), $this->refusal('ar;q=0.5, en;q=0.9'));
    }

    public function test_a_language_we_do_not_have_falls_back_rather_than_breaking(): void
    {
        // French would otherwise resolve to a missing file and echo raw keys.
        $this->assertSame(__('messages.kiosk_token_invalid', [], 'ar'), $this->refusal('fr-FR,fr;q=0.9'));
    }

    public function test_a_refusal_that_used_to_be_hardcoded_english_now_follows_the_header(): void
    {
        // "Forbidden" was written inline, so an Arabic user was shown English.
        // The cron guard refuses a wrong secret with it and needs nothing else.
        $arabic = $this->withHeader('Accept-Language', 'ar')
            ->getJson('/v1/cron/run-alerts?key=wrong');

        $english = $this->withHeader('Accept-Language', 'en')
            ->getJson('/v1/cron/run-alerts?key=wrong');

        $this->assertSame(__('messages.forbidden', [], 'ar'), $arabic->json('message'));
        $this->assertSame(__('messages.forbidden', [], 'en'), $english->json('message'));
        $this->assertNotSame($arabic->json('message'), $english->json('message'));
    }

    public function test_the_two_files_describe_the_same_set_of_messages(): void
    {
        // A key present in one language and missing from the other surfaces to
        // whoever asked for the other as the raw key.
        /** @var array<string, string> $ar */
        $ar = require lang_path('ar/messages.php');
        /** @var array<string, string> $en */
        $en = require lang_path('en/messages.php');

        $this->assertSame([], array_diff_key($ar, $en), 'keys in Arabic with no English');
        $this->assertSame([], array_diff_key($en, $ar), 'keys in English with no Arabic');
    }
}
