<?php

declare(strict_types=1);

namespace Tests\Feature\AdminPanel;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\SuperAdmin\Domain\SuperAdminSession;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * Signing in to the support desk.
 */
final class SuperAdminAuthTest extends TestCase
{
    use DatabaseTransactions;

    private const PASSWORD = 'operator-secret';

    private FakeFirebaseTokenVerifier $firebase;

    private int $operatorId;

    private string $username;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);

        $this->username = 'op-'.bin2hex(random_bytes(5));

        $this->operatorId = (int) DB::table('super_admins')->insertGetId([
            'username' => $this->username,
            'email' => $this->username.'@permedjat.test',
            'password_hash' => password_hash(self::PASSWORD, PASSWORD_BCRYPT, ['cost' => 4]),
            'display_name' => 'Desk operator',
            'role' => 'admin',
            'is_active' => 1,
        ]);
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function login(array $payload): TestResponse
    {
        return $this->postJson('/v1/admin/auth/login', $payload);
    }

    private function openSession(): string
    {
        return SuperAdminSession::open($this->operatorId, '127.0.0.1', 'phpunit')['token'];
    }

    public function test_a_username_and_password_open_a_session(): void
    {
        $response = $this->login(['username' => $this->username, 'password' => self::PASSWORD])
            ->assertOk()
            ->assertJsonPath('data.admin.role', 'admin');

        $token = Value::string($response->json('data.token'));
        $this->assertNotSame('', $token);

        // Stored hashed: a database read must not hand anybody a working token.
        $this->assertDatabaseHas('super_admin_sessions', [
            'admin_id' => $this->operatorId,
            'token_hash' => SuperAdminSession::hash($token),
        ]);
    }

    public function test_a_wrong_password_and_an_unknown_username_are_indistinguishable(): void
    {
        // Otherwise the panel becomes a way to enumerate operator accounts.
        $wrongPassword = $this->login(['username' => $this->username, 'password' => 'nope'])
            ->assertStatus(401);
        $unknownUser = $this->login(['username' => 'nobody-here', 'password' => self::PASSWORD])
            ->assertStatus(401);

        $this->assertSame($wrongPassword->json('message'), $unknownUser->json('message'));
    }

    public function test_a_suspended_operator_cannot_sign_in(): void
    {
        DB::table('super_admins')->where('id', $this->operatorId)->update(['is_active' => 0]);

        $this->login(['username' => $this->username, 'password' => self::PASSWORD])->assertStatus(401);
    }

    public function test_missing_credentials_are_refused(): void
    {
        $this->login([])->assertStatus(422);
        $this->login(['username' => $this->username])->assertStatus(422);
    }

    public function test_a_firebase_token_signs_in_a_matching_account(): void
    {
        $uid = 'google-'.bin2hex(random_bytes(5));

        $this->login(['token' => $this->firebase->issue($uid, $this->username.'@permedjat.test')])
            ->assertOk()
            ->assertJsonPath('data.user.role_key', 'admin');

        // Matched by email the first time, then bound, so later sign-ins match
        // on the uid directly.
        $this->assertDatabaseHas('super_admins', ['id' => $this->operatorId, 'firebase_uid' => $uid]);
    }

    public function test_a_firebase_token_for_no_account_is_refused(): void
    {
        $this->login(['token' => $this->firebase->issue('unknown-uid', 'stranger@example.com')])
            ->assertStatus(404);
    }

    public function test_a_firebase_token_for_a_suspended_account_is_refused(): void
    {
        DB::table('super_admins')->where('id', $this->operatorId)->update(['is_active' => 0]);

        $this->login(['token' => $this->firebase->issue('uid-x', $this->username.'@permedjat.test')])
            ->assertStatus(403);
    }

    public function test_the_account_screen_reports_the_session_itself(): void
    {
        $token = $this->openSession();
        $this->openSession();

        $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/v1/admin/auth/me')
            ->assertOk()
            ->assertJsonPath('data.username', $this->username)
            ->assertJsonPath('data.role', 'admin')
            // The only way to notice a device you did not sign in from.
            ->assertJsonPath('data.active_sessions', 2);
    }

    public function test_signing_out_drops_only_that_session(): void
    {
        $keep = $this->openSession();
        $drop = $this->openSession();

        $this->withHeader('Authorization', 'Bearer '.$drop)
            ->postJson('/v1/admin/auth/logout')
            ->assertOk();

        $this->assertDatabaseMissing('super_admin_sessions', [
            'token_hash' => SuperAdminSession::hash($drop),
        ]);
        $this->assertDatabaseHas('super_admin_sessions', [
            'token_hash' => SuperAdminSession::hash($keep),
        ]);
    }

    public function test_changing_the_password_signs_every_other_device_out(): void
    {
        $keep = $this->openSession();
        $other = $this->openSession();

        $this->withHeader('Authorization', 'Bearer '.$keep)
            ->postJson('/v1/admin/auth/password', [
                'current_password' => self::PASSWORD,
                'new_password' => 'a-much-longer-secret',
            ])->assertOk();

        // One that leaves the old sessions alive protects nothing: whoever
        // prompted the change still holds a working token.
        $this->assertDatabaseMissing('super_admin_sessions', [
            'token_hash' => SuperAdminSession::hash($other),
        ]);
        // But not the screen the operator is standing on.
        $this->assertDatabaseHas('super_admin_sessions', [
            'token_hash' => SuperAdminSession::hash($keep),
        ]);

        $this->login(['username' => $this->username, 'password' => 'a-much-longer-secret'])->assertOk();
    }

    public function test_a_wrong_current_password_is_refused_and_recorded(): void
    {
        $this->withHeader('Authorization', 'Bearer '.$this->openSession())
            ->postJson('/v1/admin/auth/password', [
                'current_password' => 'not-it',
                'new_password' => 'a-much-longer-secret',
            ])->assertStatus(401);

        // A run of these is somebody guessing.
        $this->assertDatabaseHas('super_admin_audit_log', [
            'admin_id' => $this->operatorId,
            'action' => 'auth.change_password_failed',
        ]);
    }

    public function test_guessing_the_operator_password_is_locked_out_per_username(): void
    {
        // The most privileged credential in the product: not scoped to any
        // company, and able to act on behalf of every one of them. It used to
        // have nothing in front of it but the shared 600-a-minute per-IP
        // throttle, while an employee's six-digit PIN had a per-phone limit and
        // an account lockout. Ten wrong passwords is not somebody mistyping.
        for ($attempt = 0; $attempt < 10; $attempt++) {
            $this->login(['username' => $this->username, 'password' => 'wrong-'.$attempt])
                ->assertStatus(401);
        }

        $this->login(['username' => $this->username, 'password' => 'wrong-again'])
            ->assertStatus(429)
            ->assertJsonPath('error_code', 'rate_limited');

        // And the right password does not get through either, or the lockout
        // would only be an inconvenience to whoever guessed correctly.
        $this->login(['username' => $this->username, 'password' => self::PASSWORD])
            ->assertStatus(429);
    }

    public function test_the_lockout_counts_a_username_not_an_account(): void
    {
        // Keyed on the username as typed. A name with no account behind it must
        // be metered too — otherwise an attacker gets an unmetered channel
        // simply by misspelling, and the per-IP ceiling is all that is left.
        for ($attempt = 0; $attempt < 10; $attempt++) {
            $this->login(['username' => 'no-such-operator', 'password' => 'wrong-'.$attempt])
                ->assertStatus(401);
        }

        $this->login(['username' => 'no-such-operator', 'password' => 'x'])
            ->assertStatus(429);

        // A different operator is unaffected: one locked name must not lock the
        // panel for everybody.
        $this->login(['username' => $this->username, 'password' => self::PASSWORD])
            ->assertOk();
    }

    public function test_a_successful_sign_in_clears_the_count(): void
    {
        for ($attempt = 0; $attempt < 9; $attempt++) {
            $this->login(['username' => $this->username, 'password' => 'wrong'])->assertStatus(401);
        }

        $this->login(['username' => $this->username, 'password' => self::PASSWORD])->assertOk();

        // Back to a full allowance, so somebody who mistypes on a bad morning
        // is not one slip away from a lockout for the rest of the window.
        $this->login(['username' => $this->username, 'password' => 'wrong'])->assertStatus(401);
    }

    public function test_a_short_or_unchanged_new_password_is_refused(): void
    {
        $token = $this->openSession();

        $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/v1/admin/auth/password', [
                'current_password' => self::PASSWORD, 'new_password' => 'short',
            ])->assertStatus(422);

        $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/v1/admin/auth/password', [
                'current_password' => self::PASSWORD, 'new_password' => self::PASSWORD,
            ])->assertStatus(422);
    }
}
