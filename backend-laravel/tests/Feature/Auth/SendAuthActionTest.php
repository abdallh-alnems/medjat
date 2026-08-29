<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Mail\AuthActionMail;
use App\Services\Auth\FirebaseAccountManager;
use Illuminate\Support\Facades\Mail;
use Tests\Support\FakeFirebaseAccountManager;
use Tests\TestCase;

/**
 * Password-reset and verification emails.
 *
 * The property under test is mostly what these endpoints refuse to reveal.
 */
final class SendAuthActionTest extends TestCase
{
    private FakeFirebaseAccountManager $accounts;

    protected function setUp(): void
    {
        parent::setUp();

        Mail::fake();
        $this->accounts = new FakeFirebaseAccountManager;
        $this->app->instance(FirebaseAccountManager::class, $this->accounts);
    }

    public function test_a_registered_address_receives_a_reset_email(): void
    {
        $this->accounts->register('someone@example.com');

        $this->postJson('/app/auth/send_password_reset.php', ['email' => 'someone@example.com'])
            ->assertOk()
            ->assertJsonPath('data.success', true);

        Mail::assertSent(AuthActionMail::class, 1);
    }

    public function test_an_unregistered_address_gets_the_same_response_and_no_email(): void
    {
        // The whole point: a caller cannot learn which addresses have accounts.
        $registered = $this->postJson('/app/auth/send_password_reset.php', ['email' => 'nobody@example.com']);

        $registered->assertOk()->assertJsonPath('data.success', true);
        Mail::assertNothingSent();
    }

    public function test_the_two_responses_are_byte_identical(): void
    {
        $this->accounts->register('known@example.com');

        $known = $this->postJson('/app/auth/send_password_reset.php', ['email' => 'known@example.com']);
        $unknown = $this->postJson('/app/auth/send_password_reset.php', ['email' => 'unknown@example.com']);

        $this->assertSame($known->getContent(), $unknown->getContent());
        $this->assertSame($known->getStatusCode(), $unknown->getStatusCode());
    }

    public function test_a_verification_email_is_sent_for_a_registered_address(): void
    {
        $this->accounts->register('newuser@example.com');

        $this->postJson('/app/auth/send_verification.php', ['email' => 'newuser@example.com'])->assertOk();

        Mail::assertSent(AuthActionMail::class, 1);
    }

    public function test_a_malformed_address_is_refused(): void
    {
        // A client bug rather than an account that may or may not exist, so
        // saying so leaks nothing.
        $this->postJson('/app/auth/send_password_reset.php', ['email' => 'not-an-address'])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'invalid_email');
    }

    public function test_a_missing_address_is_refused(): void
    {
        $this->postJson('/app/auth/send_password_reset.php', [])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'invalid_email');
    }

    public function test_the_address_is_matched_case_insensitively(): void
    {
        $this->accounts->register('mixed@example.com');

        $this->postJson('/app/auth/send_password_reset.php', ['email' => '  Mixed@Example.COM '])
            ->assertOk();

        Mail::assertSent(AuthActionMail::class, 1);
    }

    public function test_the_link_is_routed_through_our_branded_page(): void
    {
        // Firebase's query string has to survive intact — it carries the oobCode
        // that makes the link work at all.
        $this->accounts->register('branded@example.com', 'https://firebase.test/x?mode=resetPassword&oobCode=XYZ&apiKey=K');

        $this->postJson('/app/auth/send_password_reset.php', ['email' => 'branded@example.com'])->assertOk();

        Mail::assertSent(AuthActionMail::class, function (AuthActionMail $mail): bool {
            $rendered = $mail->render();

            return str_contains($rendered, 'auth-action.html')
                && str_contains($rendered, 'oobCode=XYZ');
        });
    }

    public function test_an_unknown_language_falls_back_to_arabic(): void
    {
        $this->accounts->register('lang@example.com');

        $this->postJson('/app/auth/send_password_reset.php', ['email' => 'lang@example.com', 'lang' => 'fr'])
            ->assertOk();

        Mail::assertSent(AuthActionMail::class, function (AuthActionMail $mail): bool {
            return str_contains($mail->render(), 'إعادة تعيين كلمة المرور');
        });
    }

    public function test_english_is_honoured_when_asked_for(): void
    {
        $this->accounts->register('en@example.com');

        $this->postJson('/app/auth/send_password_reset.php', ['email' => 'en@example.com', 'lang' => 'en'])
            ->assertOk();

        Mail::assertSent(AuthActionMail::class, function (AuthActionMail $mail): bool {
            return str_contains($mail->render(), 'Reset my password');
        });
    }
}
