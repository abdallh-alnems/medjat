<?php

declare(strict_types=1);

namespace Tests\Feature\Tenant;

use App\Domain\Notifications\PushSender;
use App\Domain\Team\ManagerInvitation;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The three ways a signed-in person acquires a company.
 */
final class OnboardingTest extends TestCase
{
    use DatabaseTransactions;

    private FakeFirebaseTokenVerifier $firebase;

    private int $hostTenantId;

    private int $newcomerId;

    private string $newcomerToken;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->hostTenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        [$this->newcomerId, $this->newcomerToken] = $this->person('newcomer@example.com');
    }

    /**
     * @return array{0: int, 1: string}
     */
    private function person(?string $email, ?int $tenantId = null): array
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        $id = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => $uid,
            'tenant_id' => $tenantId,
            'email' => $email,
            'name' => 'Person '.bin2hex(random_bytes(3)),
            'role' => $tenantId === null ? 'viewer' : 'general_manager',
            'is_active' => 1,
        ]);

        return [$id, $this->firebase->issue($uid, $email)];
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function send(string $path, array $payload): TestResponse
    {
        return $this->postJson($path, $payload);
    }

    /**
     * @param  list<string>|null  $permissions
     */
    private function invite(
        string $email = 'newcomer@example.com',
        string $role = 'hr',
        ?array $permissions = null,
    ): string {
        $invitation = ManagerInvitation::create($this->hostTenantId, null, [
            'email' => $email,
            'name' => 'Invited name',
            'role' => $role,
            'branch_id' => null,
            'permissions' => $permissions,
        ]);

        return $invitation['code'];
    }

    public function test_founding_a_company_makes_the_founder_a_general_manager(): void
    {
        $response = $this->send('/app/tenant/create.php', [
            'token' => $this->newcomerToken,
            'company_name' => 'Brand new company',
        ])->assertOk()->assertJsonPath('data.user.role', 'general_manager');

        $tenantId = Value::int($response->json('data.tenant.id'));

        $this->assertDatabaseHas('tenants', ['id' => $tenantId, 'name' => 'Brand new company']);
        $this->assertDatabaseHas('admins', [
            'id' => $this->newcomerId, 'tenant_id' => $tenantId, 'role' => 'general_manager',
        ]);
    }

    public function test_omitted_locale_settings_keep_their_defaults(): void
    {
        // Builds already in the stores send nothing but the name, and those
        // companies must keep working.
        $response = $this->send('/app/tenant/create.php', [
            'token' => $this->newcomerToken,
            'company_name' => 'Minimal company',
        ])->assertOk();

        /** @var array<string, mixed> $tenant */
        $tenant = (array) DB::table('tenants')
            ->where('id', Value::int($response->json('data.tenant.id')))->first();

        $this->assertNotNull($tenant['timezone']);
        $this->assertNotNull($tenant['currency']);
        $this->assertSame(0, Value::int($tenant['timezone_is_explicit']));
    }

    public function test_choosing_a_timezone_marks_it_as_deliberate(): void
    {
        $response = $this->send('/app/tenant/create.php', [
            'token' => $this->newcomerToken,
            'company_name' => 'Gulf company',
            'timezone' => 'Asia/Dubai',
            'currency' => 'aed',
            'cycle_start_day' => 26,
            'week_start_day' => 7,
        ])->assertOk()
            ->assertJsonPath('data.tenant.timezone', 'Asia/Dubai')
            // Lowercase in, ISO out.
            ->assertJsonPath('data.tenant.currency', 'AED')
            ->assertJsonPath('data.tenant.cycle_start_day', 26);

        // What stops the client re-suggesting the device's zone over a choice
        // somebody made.
        $this->assertDatabaseHas('tenants', [
            'id' => Value::int($response->json('data.tenant.id')), 'timezone_is_explicit' => 1,
        ]);
    }

    public function test_a_nonsense_timezone_or_currency_is_refused(): void
    {
        $this->send('/app/tenant/create.php', [
            'token' => $this->newcomerToken,
            'company_name' => 'Bad company',
            'timezone' => 'Mars/Olympus',
        ])->assertStatus(422);

        $this->send('/app/tenant/create.php', [
            'token' => $this->newcomerToken,
            'company_name' => 'Bad company',
            'currency' => 'Egyptian Pounds',
        ])->assertStatus(422);

        $this->send('/app/tenant/create.php', [
            'token' => $this->newcomerToken,
            'company_name' => 'Bad company',
            'cycle_start_day' => 31,
        ])->assertStatus(422);
    }

    public function test_a_nameless_company_is_refused(): void
    {
        $this->send('/app/tenant/create.php', [
            'token' => $this->newcomerToken,
            'company_name' => '   ',
        ])->assertStatus(422);
    }

    public function test_somebody_who_already_belongs_cannot_found_another(): void
    {
        [, $token] = $this->person('member@example.com', $this->hostTenantId);

        // One person belongs to exactly one company; a second would leave every
        // tenant-scoped query with two answers.
        $this->send('/app/tenant/create.php', [
            'token' => $token, 'company_name' => 'Second company',
        ])->assertStatus(409);
    }

    public function test_a_request_with_no_token_is_refused(): void
    {
        $this->send('/app/tenant/create.php', ['company_name' => 'Anonymous'])->assertStatus(400);
    }

    public function test_a_token_for_somebody_who_never_signed_in_is_refused(): void
    {
        $this->send('/app/tenant/create.php', [
            'token' => $this->firebase->issue('uid-never-seen'),
            'company_name' => 'Ghost company',
        ])->assertStatus(401);
    }

    public function test_a_valid_code_joins_the_company_it_belongs_to(): void
    {
        $code = $this->invite();

        $this->send('/app/tenant/join.php', [
            'token' => $this->newcomerToken, 'invite_code' => $code,
        ])->assertOk()
            ->assertJsonPath('data.user.role', 'hr')
            ->assertJsonPath('data.user.tenant_id', $this->hostTenantId);

        $this->assertDatabaseHas('admins', [
            'id' => $this->newcomerId, 'tenant_id' => $this->hostTenantId, 'role' => 'hr',
        ]);
    }

    public function test_a_code_can_only_be_used_once(): void
    {
        $code = $this->invite();

        $this->send('/app/tenant/join.php', [
            'token' => $this->newcomerToken, 'invite_code' => $code,
        ])->assertOk();

        [, $second] = $this->person('newcomer@example.com');

        $this->send('/app/tenant/join.php', [
            'token' => $second, 'invite_code' => $code,
        ])->assertStatus(410);
    }

    public function test_a_cancelled_invitation_is_refused(): void
    {
        $code = $this->invite();
        $id = Value::int(DB::table('manager_invitations')
            ->where('token_hash', ManagerInvitation::hash($code))->value('id'));
        ManagerInvitation::cancel($id, $this->hostTenantId);

        $this->send('/app/tenant/join.php', [
            'token' => $this->newcomerToken, 'invite_code' => $code,
        ])->assertStatus(410);
    }

    public function test_an_expired_invitation_is_refused(): void
    {
        $code = $this->invite();

        // Expired by the database's own clock, which is the one that stamped
        // it. PHP runs UTC here and would judge it hours out.
        DB::update(
            'UPDATE manager_invitations SET expires_at = DATE_SUB(NOW(), INTERVAL 1 HOUR) WHERE token_hash = ?',
            [ManagerInvitation::hash($code)],
        );

        $this->send('/app/tenant/join.php', [
            'token' => $this->newcomerToken, 'invite_code' => $code,
        ])->assertStatus(410);
    }

    public function test_an_unknown_code_is_refused(): void
    {
        $this->send('/app/tenant/join.php', [
            'token' => $this->newcomerToken, 'invite_code' => 'NOTACODE',
        ])->assertStatus(404);
    }

    public function test_a_code_addressed_to_somebody_else_is_refused(): void
    {
        $code = $this->invite(email: 'someone.else@example.com');

        $this->send('/app/tenant/join.php', [
            'token' => $this->newcomerToken, 'invite_code' => $code,
        ])->assertStatus(403);

        $this->assertDatabaseHas('admins', ['id' => $this->newcomerId, 'tenant_id' => null]);
    }

    public function test_the_invitations_custom_permissions_are_applied(): void
    {
        $code = $this->invite(permissions: ['manage_attendance', 'view_reports']);

        $this->send('/app/tenant/join.php', [
            'token' => $this->newcomerToken, 'invite_code' => $code,
        ])->assertOk();

        $this->assertDatabaseHas('custom_roles', [
            'tenant_id' => $this->hostTenantId, 'admin_id' => $this->newcomerId,
        ]);
    }

    public function test_an_invitation_addressed_to_the_signed_in_email_needs_no_code(): void
    {
        // The email match plus an authenticated session is the same proof the
        // code would have been.
        $this->invite();

        $this->send('/app/tenant/accept_invitation.php', ['token' => $this->newcomerToken])
            ->assertOk()
            ->assertJsonPath('data.user.role', 'hr');
    }

    public function test_a_specific_invitation_can_be_pinned(): void
    {
        $this->invite(role: 'attendance');
        ManagerInvitation::create($this->hostTenantId, null, [
            'email' => 'newcomer@example.com',
            'name' => 'Second offer',
            'role' => 'branch_manager',
            'branch_id' => null,
            'permissions' => null,
        ]);

        $first = Value::int(DB::table('manager_invitations')
            ->where('email', 'newcomer@example.com')->where('role', 'attendance')->value('id'));

        $this->send('/app/tenant/accept_invitation.php', [
            'token' => $this->newcomerToken, 'invitation_id' => $first,
        ])->assertOk()->assertJsonPath('data.user.role', 'attendance');
    }

    public function test_accepting_with_no_invitation_waiting_is_a_404(): void
    {
        $this->send('/app/tenant/accept_invitation.php', ['token' => $this->newcomerToken])
            ->assertStatus(404);
    }

    public function test_somebody_with_no_email_has_no_invitation_to_accept(): void
    {
        [, $token] = $this->person(null);

        $this->send('/app/tenant/accept_invitation.php', ['token' => $token])->assertStatus(404);
    }

    public function test_the_token_may_arrive_in_the_header_instead(): void
    {
        // The body carries it for the mobile apps, the header for the web
        // client.
        $this->invite();

        $this->withHeader('X-Firebase-Token', $this->newcomerToken)
            ->postJson('/app/tenant/accept_invitation.php', [])
            ->assertOk();
    }
}
