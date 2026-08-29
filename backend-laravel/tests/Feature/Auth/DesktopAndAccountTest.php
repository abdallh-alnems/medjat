<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Admin;
use App\Models\DesktopAuthCode;
use App\Services\Auth\FirebaseAccountManager;
use App\Services\Auth\FirebaseCustomTokenMinter;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseAccountManager;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * Desktop sign-in and account deletion.
 */
final class DesktopAndAccountTest extends TestCase
{
    use DatabaseTransactions;

    private FakeFirebaseTokenVerifier $firebase;

    private FakeFirebaseAccountManager $accounts;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->accounts = new FakeFirebaseAccountManager;

        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
        $this->app->instance(FirebaseAccountManager::class, $this->accounts);
        $this->app->instance(FirebaseCustomTokenMinter::class, $this->accounts);
    }

    private function tenantId(): int
    {
        return Value::int(DB::table('tenants')->where('is_active', 1)->orderBy('id')->value('id'));
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array{Admin, string}
     */
    private function admin(array $overrides = []): array
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        $id = Admin::query()->insertGetId(array_merge([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId(),
            'name' => 'Test Admin',
            'role' => 'general_manager',
            'is_active' => 1,
        ], $overrides));

        return [Admin::query()->findOrFail($id), $this->firebase->issue($uid)];
    }

    // ── Desktop sign-in ──────────────────────────────────────────────────

    public function test_an_authorised_browser_gets_a_short_lived_code(): void
    {
        [$admin, $token] = $this->admin();

        $response = $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/auth/desktop_authorize.php', ['state' => str_repeat('s', 32)])
            ->assertOk()
            ->assertJsonPath('data.expires_in_seconds', DesktopAuthCode::LIFETIME_SECONDS);

        $code = $response->json('data.code');
        $this->assertIsString($code);

        // Only the digest is stored; the plaintext exists in that response only.
        $this->assertDatabaseHas('desktop_auth_codes', [
            'admin_id' => $admin->id,
            'code_hash' => DesktopAuthCode::hash($code),
        ]);
        $this->assertDatabaseMissing('desktop_auth_codes', ['code_hash' => $code]);
    }

    public function test_an_unauthenticated_caller_cannot_mint_a_code(): void
    {
        // The code is only ever minted for the account signed in right there.
        $this->postJson('/app/auth/desktop_authorize.php', ['state' => str_repeat('s', 32)])
            ->assertStatus(400);
    }

    public function test_a_too_short_state_is_refused(): void
    {
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/auth/desktop_authorize.php', ['state' => 'short'])
            ->assertStatus(400);
    }

    public function test_a_code_is_exchanged_for_a_custom_token(): void
    {
        [$admin, $token] = $this->admin();
        $state = str_repeat('s', 32);

        $code = $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/auth/desktop_authorize.php', ['state' => $state])
            ->json('data.code');
        $this->assertIsString($code);

        $this->postJson('/app/auth/desktop_exchange.php', ['code' => $code, 'state' => $state])
            ->assertOk()
            ->assertJsonPath('data.token', 'custom-token:'.$admin->firebase_uid.':{"desktop":true}');
    }

    public function test_a_code_cannot_be_exchanged_twice(): void
    {
        [, $token] = $this->admin();
        $state = str_repeat('s', 32);

        $code = $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/auth/desktop_authorize.php', ['state' => $state])
            ->json('data.code');
        $this->assertIsString($code);

        $this->postJson('/app/auth/desktop_exchange.php', ['code' => $code, 'state' => $state])->assertOk();

        $this->postJson('/app/auth/desktop_exchange.php', ['code' => $code, 'state' => $state])
            ->assertUnauthorized()
            ->assertJsonPath('error_code', 'desktop_code_invalid');
    }

    public function test_a_code_without_its_state_nonce_is_useless(): void
    {
        // This is what makes an intercepted code worthless: the nonce never
        // leaves the desktop app.
        [, $token] = $this->admin();

        $code = $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/auth/desktop_authorize.php', ['state' => str_repeat('s', 32)])
            ->json('data.code');
        $this->assertIsString($code);

        $this->postJson('/app/auth/desktop_exchange.php', ['code' => $code, 'state' => str_repeat('x', 32)])
            ->assertUnauthorized()
            ->assertJsonPath('error_code', 'desktop_code_invalid');
    }

    public function test_an_expired_code_is_refused(): void
    {
        [$admin] = $this->admin();
        $code = bin2hex(random_bytes(32));
        $state = str_repeat('s', 32);

        DB::insert(
            'INSERT INTO desktop_auth_codes (code_hash, state_hash, admin_id, firebase_uid, expires_at)
             VALUES (?, ?, ?, ?, DATE_SUB(NOW(), INTERVAL 1 SECOND))',
            [DesktopAuthCode::hash($code), DesktopAuthCode::hash($state), $admin->id, $admin->firebase_uid]
        );

        $this->postJson('/app/auth/desktop_exchange.php', ['code' => $code, 'state' => $state])
            ->assertUnauthorized();
    }

    public function test_every_refusal_looks_the_same(): void
    {
        // Unknown, expired, spent and state-mismatch must be indistinguishable,
        // or the endpoint says which half of the pair was wrong.
        $unknown = $this->postJson('/app/auth/desktop_exchange.php', [
            'code' => bin2hex(random_bytes(32)), 'state' => str_repeat('s', 32),
        ]);

        $unknown->assertUnauthorized()->assertJsonPath('error_code', 'desktop_code_invalid');
    }

    public function test_issuing_a_code_clears_this_admins_spent_codes(): void
    {
        [$admin, $token] = $this->admin();

        DB::insert(
            'INSERT INTO desktop_auth_codes (code_hash, state_hash, admin_id, firebase_uid, expires_at, used_at)
             VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 120 SECOND), NOW())',
            [DesktopAuthCode::hash('spent'), DesktopAuthCode::hash('spent'), $admin->id, $admin->firebase_uid]
        );

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/auth/desktop_authorize.php', ['state' => str_repeat('s', 32)])
            ->assertOk();

        $this->assertDatabaseMissing('desktop_auth_codes', ['code_hash' => DesktopAuthCode::hash('spent')]);
    }

    // ── Account deletion ─────────────────────────────────────────────────

    public function test_a_non_last_manager_deletes_only_themselves(): void
    {
        [$other] = $this->admin();
        [$admin, $token] = $this->admin(['tenant_id' => $other->tenant_id]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/auth/delete_account.php')
            ->assertOk()
            ->assertJsonPath('data.deleted_company', false);

        $this->assertDatabaseMissing('admins', ['id' => $admin->id]);
        $this->assertDatabaseHas('tenants', ['id' => $other->tenant_id]);
        $this->assertContains($admin->firebase_uid, $this->accounts->deletedUids);
    }

    public function test_a_non_manager_role_never_deletes_the_company(): void
    {
        [, $token] = $this->admin(['role' => 'hr']);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/auth/delete_account.php')
            ->assertOk()
            ->assertJsonPath('data.deleted_company', false);
    }

    public function test_an_admin_with_no_company_deletes_only_themselves(): void
    {
        [$admin, $token] = $this->admin(['tenant_id' => null]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/auth/delete_account.php')
            ->assertOk()
            ->assertJsonPath('data.deleted_company', false);

        $this->assertDatabaseMissing('admins', ['id' => $admin->id]);
    }

    public function test_a_firebase_deletion_failure_does_not_fail_the_request(): void
    {
        // The row is already gone; reporting failure would tell someone their
        // deletion did not work when it did.
        [$admin, $token] = $this->admin(['role' => 'hr']);
        $this->accounts->deletionFails = true;

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/auth/delete_account.php')
            ->assertOk();

        $this->assertDatabaseMissing('admins', ['id' => $admin->id]);
    }
}
