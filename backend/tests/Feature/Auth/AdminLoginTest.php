<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Admin;
use App\Models\CustomRole;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * Administrator sign-in: the response the management app builds its entire
 * session from.
 *
 * The permissions block gets the most attention here because a mistake in it is
 * not a visible failure — it shows a tab the person cannot open, and the backend
 * answers the tap with a 403 that surfaces as "an error occurred".
 */
final class AdminLoginTest extends TestCase
{
    use DatabaseTransactions;

    private const ENDPOINT = '/app/auth/login.php';

    private FakeFirebaseTokenVerifier $firebase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
    }

    private function tenantId(): int
    {
        return Value::int(DB::table('tenants')->orderBy('id')->value('id'));
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function admin(array $overrides = []): Admin
    {
        $id = Admin::query()->insertGetId(array_merge([
            'firebase_uid' => 'uid-'.bin2hex(random_bytes(6)),
            'tenant_id' => $this->tenantId(),
            'name' => 'Test Admin',
            'email' => 'admin-'.bin2hex(random_bytes(4)).'@example.com',
            'role' => 'general_manager',
            'is_active' => 1,
        ], $overrides));

        return Admin::query()->findOrFail($id);
    }

    public function test_an_unknown_google_account_is_created_as_pending_with_no_company(): void
    {
        $token = $this->firebase->issue('uid-brand-new', 'newcomer@example.com', 'New Comer');

        $response = $this->postJson(self::ENDPOINT, ['token' => $token])
            ->assertOk()
            ->assertJsonPath('data.has_tenant', false)
            ->assertJsonPath('data.user.role', 'pending')
            ->assertJsonPath('data.user.name', 'New Comer')
            ->assertJsonPath('data.tenant', null);

        $this->assertDatabaseHas('admins', [
            'firebase_uid' => 'uid-brand-new',
            'role' => 'pending',
            'email' => 'newcomer@example.com',
        ]);

        // A stranger gets an account and nothing else until a company adds them.
        $this->assertSame([], $response->json('data.user.permissions'));
    }

    public function test_a_missing_display_name_falls_back_to_the_email_local_part(): void
    {
        $token = $this->firebase->issue('uid-nameless', 'someone@example.com');

        $this->postJson(self::ENDPOINT, ['token' => $token])
            ->assertOk()
            ->assertJsonPath('data.user.name', 'someone');
    }

    public function test_an_existing_admin_signs_in_and_gets_their_company(): void
    {
        $admin = $this->admin();
        $token = $this->firebase->issue((string) $admin->firebase_uid);

        $this->postJson(self::ENDPOINT, ['token' => $token])
            ->assertOk()
            ->assertJsonPath('data.has_tenant', true)
            ->assertJsonPath('data.user.id', $admin->id)
            ->assertJsonPath('data.tenant.id', $admin->tenant_id)
            ->assertJsonStructure(['data' => ['tenant' => ['id', 'name', 'currency', 'timezone']]]);
    }

    public function test_an_account_invited_by_email_is_bound_to_its_uid_on_first_sign_in(): void
    {
        // Invitation creates the row before the person has ever authenticated,
        // so it carries an email and no firebase_uid.
        $admin = $this->admin(['firebase_uid' => '', 'role' => 'hr']);
        $token = $this->firebase->issue('uid-first-time', Value::string($admin->getAttribute('email')));

        $this->postJson(self::ENDPOINT, ['token' => $token])
            ->assertOk()
            ->assertJsonPath('data.user.id', $admin->id);

        $this->assertSame(
            'uid-first-time',
            DB::table('admins')->where('id', $admin->id)->value('firebase_uid'),
            'the uid must be bound so later requests match on it directly'
        );
    }

    public function test_a_suspended_admin_is_refused(): void
    {
        $admin = $this->admin(['is_active' => 0]);
        $token = $this->firebase->issue((string) $admin->firebase_uid);

        $this->postJson(self::ENDPOINT, ['token' => $token])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'account_deactivated');
    }

    public function test_an_admin_detached_from_their_company_gets_the_removal_message(): void
    {
        // Different from suspension: being removed detaches the account instead
        // of barring the person, and the app has to tell them apart.
        $admin = $this->admin(['is_active' => 0, 'tenant_id' => null]);
        $token = $this->firebase->issue((string) $admin->firebase_uid);

        $this->postJson(self::ENDPOINT, ['token' => $token])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'account_removed');
    }

    public function test_a_missing_token_is_refused_with_400(): void
    {
        $this->postJson(self::ENDPOINT, [])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'token_required');
    }

    public function test_a_forged_token_is_refused(): void
    {
        $this->postJson(self::ENDPOINT, ['token' => 'made-up'])->assertUnauthorized();
    }

    public function test_signing_in_claims_the_device(): void
    {
        $admin = $this->admin();
        $token = $this->firebase->issue((string) $admin->firebase_uid);

        $this->withHeader('X-Device-Id', 'phone-1')
            ->postJson(self::ENDPOINT, ['token' => $token])
            ->assertOk();

        $this->assertSame('phone-1', DB::table('admins')->where('id', $admin->id)->value('active_device_id'));
    }

    public function test_a_second_sign_in_takes_the_device_over(): void
    {
        $admin = $this->admin(['active_device_id' => 'phone-1']);
        $token = $this->firebase->issue((string) $admin->firebase_uid);

        $this->withHeader('X-Device-Id', 'phone-2')
            ->postJson(self::ENDPOINT, ['token' => $token])
            ->assertOk();

        $this->assertSame('phone-2', DB::table('admins')->where('id', $admin->id)->value('active_device_id'));
    }

    public function test_a_general_manager_gets_an_empty_permission_list(): void
    {
        // '*' is not sent as a list: the client recognises the role itself, and
        // an empty list here means "not permission-gated", not "no access".
        $admin = $this->admin(['role' => 'general_manager']);
        $token = $this->firebase->issue((string) $admin->firebase_uid);

        $this->postJson(self::ENDPOINT, ['token' => $token])
            ->assertOk()
            ->assertJsonPath('data.user.permissions', []);
    }

    public function test_a_role_gets_its_default_permissions(): void
    {
        $admin = $this->admin(['role' => 'viewer']);
        $token = $this->firebase->issue((string) $admin->firebase_uid);

        $permissions = $this->postJson(self::ENDPOINT, ['token' => $token])
            ->assertOk()
            ->json('data.user.permissions');

        $this->assertEqualsCanonicalizing(['view_reports', 'view_analytics'], $permissions);
    }

    public function test_a_custom_role_overrides_the_role_defaults(): void
    {
        $admin = $this->admin(['role' => 'viewer']);
        CustomRole::query()->create([
            'tenant_id' => $admin->tenant_id,
            'admin_id' => $admin->id,
            'name' => 'Payroll only',
            'permissions' => ['manage_payroll'],
        ]);
        $token = $this->firebase->issue((string) $admin->firebase_uid);

        $this->postJson(self::ENDPOINT, ['token' => $token])
            ->assertOk()
            ->assertJsonPath('data.user.permissions', ['manage_payroll']);
    }

    public function test_a_pending_invitation_is_surfaced_to_an_admin_with_no_company(): void
    {
        $email = 'invited-'.bin2hex(random_bytes(4)).'@example.com';
        $admin = $this->admin(['tenant_id' => null, 'role' => 'pending', 'email' => $email]);

        DB::table('manager_invitations')->insert([
            'tenant_id' => $this->tenantId(),
            'email' => $email,
            'name' => 'Invited Person',
            'role' => 'hr',
            // Only the digest is stored: the invitation link carries the
            // plaintext and it is never persisted.
            'token_hash' => hash('sha256', bin2hex(random_bytes(16))),
            'expires_at' => now()->addDay(),
        ]);

        $token = $this->firebase->issue((string) $admin->firebase_uid, $email);

        $this->postJson(self::ENDPOINT, ['token' => $token])
            ->assertOk()
            ->assertJsonPath('data.pending_invitation.role', 'hr')
            ->assertJsonStructure(['data' => ['pending_invitation' => [
                'invitation_id', 'company_name', 'role', 'role_key', 'branch_name', 'expires_at',
            ]]]);
    }

    public function test_an_expired_invitation_is_not_surfaced(): void
    {
        $email = 'stale-'.bin2hex(random_bytes(4)).'@example.com';
        $admin = $this->admin(['tenant_id' => null, 'role' => 'pending', 'email' => $email]);

        DB::table('manager_invitations')->insert([
            'tenant_id' => $this->tenantId(),
            'email' => $email,
            'name' => 'Invited Person',
            'role' => 'hr',
            // Only the digest is stored: the invitation link carries the
            // plaintext and it is never persisted.
            'token_hash' => hash('sha256', bin2hex(random_bytes(16))),
            'expires_at' => now()->subDay(),
        ]);

        $token = $this->firebase->issue((string) $admin->firebase_uid, $email);

        $this->postJson(self::ENDPOINT, ['token' => $token])
            ->assertOk()
            ->assertJsonPath('data.pending_invitation', null);
    }

    public function test_the_sign_in_is_recorded(): void
    {
        $admin = $this->admin();
        $token = $this->firebase->issue((string) $admin->firebase_uid);

        $this->postJson(self::ENDPOINT, ['token' => $token])->assertOk();

        $this->assertDatabaseHas('login_attempts', [
            'admin_id' => $admin->id,
            'identifier_type' => 'email',
            'success' => 1,
        ]);
    }
}
