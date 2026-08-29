<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Admin;
use App\Services\Auth\FirebaseTokenVerifier;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * The administrator session: Firebase identity, company membership, and the
 * one-device rule.
 *
 * None of this was testable before — Auth::authenticateUser() called Firebase
 * directly, so covering any of it meant real credentials and a network.
 */
final class AdminAuthenticationTest extends TestCase
{
    use DatabaseTransactions;

    private const ENDPOINT = '/app/auth/logout.php';

    private FakeFirebaseTokenVerifier $firebase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array{Admin, string} the admin and a token that authenticates it
     */
    private function signedInAdmin(array $overrides = []): array
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));

        $id = Admin::query()->insertGetId(array_merge([
            'firebase_uid' => $uid,
            'tenant_id' => DB::table('tenants')->orderBy('id')->value('id'),
            'name' => 'Test Admin',
            'role' => 'general_manager',
            'is_active' => 1,
        ], $overrides));

        $admin = Admin::query()->findOrFail($id);

        return [$admin, $this->firebase->issue($uid)];
    }

    public function test_a_valid_token_authenticates_and_logout_clears_the_active_device(): void
    {
        [$admin, $token] = $this->signedInAdmin(['active_device_id' => 'device-a']);

        $this->withHeaders(['X-Firebase-Token' => $token, 'X-Device-Id' => 'device-a'])
            ->postJson(self::ENDPOINT)
            ->assertOk()
            ->assertJsonPath('data.success', true);

        $this->assertNull(
            DB::table('admins')->where('id', $admin->id)->value('active_device_id'),
            'signing out must leave no device marked as signed in'
        );
    }

    public function test_a_missing_token_is_refused(): void
    {
        $this->postJson(self::ENDPOINT)->assertStatus(400);
    }

    public function test_a_forged_token_is_refused(): void
    {
        $this->withHeader('X-Firebase-Token', 'not-a-real-token')
            ->postJson(self::ENDPOINT)
            ->assertUnauthorized();
    }

    public function test_a_token_for_an_unknown_admin_is_refused(): void
    {
        $token = $this->firebase->issue('uid-nobody-has-this');

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson(self::ENDPOINT)
            ->assertNotFound();
    }

    public function test_a_deactivated_admin_is_refused(): void
    {
        [, $token] = $this->signedInAdmin(['is_active' => 0]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson(self::ENDPOINT)
            ->assertForbidden()
            ->assertJsonPath('error_code', 'account_deactivated');
    }

    public function test_an_admin_removed_from_their_company_is_refused_when_it_still_claims_one(): void
    {
        // A detached account whose app still carries a stale company context.
        [, $token] = $this->signedInAdmin(['tenant_id' => null]);

        $this->withHeaders(['X-Firebase-Token' => $token, 'X-Tenant-Id' => '1'])
            ->postJson(self::ENDPOINT)
            ->assertForbidden()
            ->assertJsonPath('error_code', 'account_removed');
    }

    public function test_a_detached_admin_claiming_no_company_still_passes(): void
    {
        // Onboarding: the app has dropped the stale context and is asking to
        // join or create a company. Refusing here would strand it.
        [, $token] = $this->signedInAdmin(['tenant_id' => null]);

        $this->withHeader('X-Firebase-Token', $token)->postJson(self::ENDPOINT)->assertOk();
    }

    public function test_a_session_from_a_superseded_device_is_refused(): void
    {
        [, $token] = $this->signedInAdmin(['active_device_id' => 'device-new']);

        $this->withHeaders(['X-Firebase-Token' => $token, 'X-Device-Id' => 'device-old'])
            ->postJson(self::ENDPOINT)
            ->assertUnauthorized()
            ->assertJsonPath('error_code', 'session_superseded');
    }

    public function test_a_client_that_sends_no_device_id_is_not_locked_out(): void
    {
        // Builds predating the header must keep working until their next
        // sign-in rather than being signed out by someone else's upgrade.
        [, $token] = $this->signedInAdmin(['active_device_id' => 'device-new']);

        $this->withHeader('X-Firebase-Token', $token)->postJson(self::ENDPOINT)->assertOk();
    }
}
