<?php

declare(strict_types=1);

namespace Tests\Feature\AdminPanel;

use App\Modules\Auth\Services\FirebaseAccountManager;
use App\Modules\Auth\Services\FirebaseCustomTokenMinter;
use App\Modules\Notifications\Domain\PushSender;
use App\Modules\SuperAdmin\Domain\SuperAdminSession;
use App\Modules\Team\Domain\ManagerInvitation;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseAccountManager;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The panel itself: companies, their administrators, and the platform-wide
 * levers.
 */
final class SuperAdminPanelTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $companyAdminId;

    private int $operatorId;

    private string $token;

    private FakeFirebaseAccountManager $firebase;

    private FakePushSender $push;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseAccountManager;
        $this->push = new FakePushSender;
        $this->app->instance(FirebaseAccountManager::class, $this->firebase);
        $this->app->instance(FirebaseCustomTokenMinter::class, $this->firebase);
        $this->app->instance(PushSender::class, $this->push);

        $this->tenantId = (int) DB::table('tenants')->insertGetId([
            'name' => 'Panel fixture company',
            'timezone' => 'Africa/Cairo',
            'is_active' => 1,
        ]);

        $this->companyAdminId = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => 'company-uid-'.bin2hex(random_bytes(4)),
            'tenant_id' => $this->tenantId,
            'email' => 'manager@fixture.test',
            'name' => 'Company manager',
            'role' => 'general_manager',
            'auth_provider' => 'email',
            'is_active' => 1,
        ]);

        [$this->operatorId, $this->token] = $this->operator('superadmin');
    }

    /**
     * @return array{0: int, 1: string}
     */
    private function operator(string $role): array
    {
        $id = (int) DB::table('super_admins')->insertGetId([
            'username' => 'op-'.bin2hex(random_bytes(5)),
            'password_hash' => password_hash('irrelevant', PASSWORD_BCRYPT, ['cost' => 4]),
            'display_name' => 'Operator '.$role,
            'role' => $role,
            'is_active' => 1,
        ]);

        return [$id, SuperAdminSession::open($id, '127.0.0.1', 'phpunit')['token']];
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function send(string $path, array $payload = [], ?string $token = null): TestResponse
    {
        return $this->withHeader('Authorization', 'Bearer '.($token ?? $this->token))->postJson($path, $payload);
    }

    /**
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function read(string $path, ?string $token = null): TestResponse
    {
        return $this->withHeader('Authorization', 'Bearer '.($token ?? $this->token))->getJson($path);
    }

    public function test_the_client_list_carries_the_numbers_that_decide_whether_to_open_a_company(): void
    {
        $this->read('/v1/admin/tenants?q=Panel+fixture')
            ->assertOk()
            ->assertJsonPath('data.total', 1)
            ->assertJsonPath('data.items.0.name', 'Panel fixture company')
            ->assertJsonPath('data.items.0.admin_count', 1)
            ->assertJsonStructure(['data' => ['items' => [['employee_count', 'last_admin_login_at']]]]);
    }

    public function test_the_client_list_pages_past_the_first_screen(): void
    {
        // The original had no page control at all, so past twenty companies the
        // rest were unreachable from the panel.
        $this->read('/v1/admin/tenants?limit=5&page=2')
            ->assertOk()
            ->assertJsonPath('data.page', 2)
            ->assertJsonPath('data.limit', 5);
    }

    public function test_the_client_list_filters_by_status(): void
    {
        DB::table('tenants')->where('id', $this->tenantId)->update(['is_active' => 0]);

        $this->read('/v1/admin/tenants?q=Panel+fixture&status=active')
            ->assertOk()->assertJsonPath('data.total', 0);
        $this->read('/v1/admin/tenants?q=Panel+fixture&status=inactive')
            ->assertOk()->assertJsonPath('data.total', 1);
    }

    public function test_one_company_answers_the_questions_that_used_to_need_ssh(): void
    {
        $this->read('/v1/admin/tenants/detail?id='.$this->tenantId)
            ->assertOk()
            ->assertJsonPath('data.tenant.name', 'Panel fixture company')
            ->assertJsonPath('data.stats.admins', 1)
            ->assertJsonPath('data.managers.0.name', 'Company manager')
            ->assertJsonStructure(['data' => ['settings' => ['attendance_methods'], 'activity' => ['today']]]);
    }

    public function test_creating_a_company_also_invites_somebody_who_can_log_into_it(): void
    {
        // A super admin has no row in `admins`, so creating only the tenant
        // leaves a company nobody can reach.
        $response = $this->send('/v1/admin/tenants', [
            'name' => 'Brand new client',
            'owner_email' => 'owner@newclient.test',
            'owner_name' => 'The owner',
            'timezone' => 'Asia/Dubai',
            'contact_phone' => '+201000000000',
        ])->assertOk();

        $tenantId = Value::int($response->json('data.tenant_id'));

        $this->assertDatabaseHas('tenants', [
            'id' => $tenantId, 'timezone' => 'Asia/Dubai', 'timezone_is_explicit' => 1,
            'contact_phone' => '+201000000000',
        ]);
        $this->assertDatabaseHas('manager_invitations', [
            'tenant_id' => $tenantId, 'email' => 'owner@newclient.test', 'role' => 'general_manager',
        ]);
        $this->assertNotSame('', Value::string($response->json('data.invitation.join_url')));
    }

    public function test_a_company_can_be_created_without_an_owner(): void
    {
        $this->send('/v1/admin/tenants', ['name' => 'Invite them later'])
            ->assertOk()
            ->assertJsonPath('data.invitation', null);
    }

    public function test_an_owner_who_already_belongs_elsewhere_is_refused(): void
    {
        $this->send('/v1/admin/tenants', [
            'name' => 'Second company', 'owner_email' => 'manager@fixture.test',
        ])->assertStatus(409);

        $this->assertDatabaseMissing('tenants', ['name' => 'Second company']);
    }

    public function test_editing_a_company_touches_only_what_was_sent(): void
    {
        // An agent correcting a phone number must not silently reset a timezone
        // they never saw.
        $this->send('/v1/admin/tenants/update', [
            'id' => $this->tenantId, 'contact_phone' => '+201111111111',
        ])->assertOk()->assertJsonPath('data.updated', ['contact_phone']);

        $this->assertDatabaseHas('tenants', [
            'id' => $this->tenantId, 'timezone' => 'Africa/Cairo', 'contact_phone' => '+201111111111',
        ]);
    }

    public function test_a_contact_field_can_be_cleared_but_a_setting_cannot(): void
    {
        $this->send('/v1/admin/tenants/update', [
            'id' => $this->tenantId, 'contact_phone' => '+201111111111',
        ])->assertOk();

        // Erasing a stale phone number is a normal support action.
        $this->send('/v1/admin/tenants/update', ['id' => $this->tenantId, 'contact_phone' => ''])->assertOk();
        $this->assertDatabaseHas('tenants', ['id' => $this->tenantId, 'contact_phone' => null]);

        // An empty timezone is not a request to have no timezone.
        $this->send('/v1/admin/tenants/update', ['id' => $this->tenantId, 'timezone' => ''])->assertStatus(422);
    }

    public function test_a_company_can_be_suspended_and_restored(): void
    {
        $this->send('/v1/admin/tenants/deactivate', ['id' => $this->tenantId])->assertOk();
        $this->assertDatabaseHas('tenants', ['id' => $this->tenantId, 'is_active' => 0]);

        $this->send('/v1/admin/tenants/activate', ['id' => $this->tenantId])->assertOk();
        $this->assertDatabaseHas('tenants', ['id' => $this->tenantId, 'is_active' => 1]);
    }

    public function test_inviting_a_manager_rescues_a_locked_out_company(): void
    {
        // Nobody left holding add_managers means the account is otherwise
        // permanently locked.
        $response = $this->send('/v1/admin/company-admins/invite', [
            'tenant_id' => $this->tenantId,
            'email' => 'rescue@fixture.test',
            'role' => 'general_manager',
        ])->assertOk();

        $this->assertNotSame('', Value::string($response->json('data.code')));
        $this->assertDatabaseHas('manager_invitations', [
            'tenant_id' => $this->tenantId, 'email' => 'rescue@fixture.test',
        ]);
        // Visible to the company too.
        $this->assertDatabaseHas('audit_log', [
            'tenant_id' => $this->tenantId, 'action' => 'support.manager.invite',
        ]);
    }

    public function test_inviting_the_same_person_twice_hands_back_a_fresh_code(): void
    {
        $first = Value::string($this->send('/v1/admin/company-admins/invite', [
            'tenant_id' => $this->tenantId, 'email' => 'rescue@fixture.test',
        ])->json('data.code'));

        // A support call is nearly always "the code never arrived".
        $second = Value::string($this->send('/v1/admin/company-admins/invite', [
            'tenant_id' => $this->tenantId, 'email' => 'rescue@fixture.test',
        ])->assertOk()->json('data.code'));

        $this->assertNotSame($first, $second);
        $this->assertSame(1, DB::table('manager_invitations')
            ->where('tenant_id', $this->tenantId)->where('email', 'rescue@fixture.test')->count());
        // And the old one no longer works.
        $this->assertNull(ManagerInvitation::redeemable($first));
    }

    public function test_inviting_somebody_already_in_the_company_is_refused(): void
    {
        $this->send('/v1/admin/company-admins/invite', [
            'tenant_id' => $this->tenantId, 'email' => 'manager@fixture.test',
        ])->assertStatus(409);
    }

    public function test_a_password_reset_link_is_produced_for_a_password_account(): void
    {
        $this->firebase->register('manager@fixture.test');

        $this->send('/v1/admin/company-admins/reset-password', ['admin_id' => $this->companyAdminId])
            ->assertOk()
            ->assertJsonPath('data.sent', true);

        $this->assertDatabaseHas('audit_log', [
            'tenant_id' => $this->tenantId, 'action' => 'support.admin.password_reset',
        ]);
    }

    public function test_a_google_account_has_no_password_of_ours_to_reset(): void
    {
        DB::table('admins')->where('id', $this->companyAdminId)->update(['auth_provider' => 'google']);

        $this->send('/v1/admin/company-admins/reset-password', ['admin_id' => $this->companyAdminId])
            ->assertStatus(422);
    }

    public function test_an_administrator_can_be_suspended_and_restored(): void
    {
        $this->send('/v1/admin/company-admins/set-active', [
            'admin_id' => $this->companyAdminId, 'is_active' => false,
        ])->assertOk()->assertJsonPath('data.is_active', 0);

        // A suspension, not a removal: the account keeps its company and role.
        $this->assertDatabaseHas('admins', [
            'id' => $this->companyAdminId, 'is_active' => 0,
            'tenant_id' => $this->tenantId, 'role' => 'general_manager',
        ]);
        $this->assertDatabaseHas('audit_log', [
            'tenant_id' => $this->tenantId, 'action' => 'support.admin.deactivate',
        ]);

        $this->send('/v1/admin/company-admins/set-active', [
            'admin_id' => $this->companyAdminId, 'is_active' => true,
        ])->assertOk();
        $this->assertDatabaseHas('admins', ['id' => $this->companyAdminId, 'is_active' => 1]);
    }

    public function test_impersonation_requires_a_reason_and_records_it_for_the_company(): void
    {
        $this->send('/v1/admin/company-admins/impersonate', ['admin_id' => $this->companyAdminId])
            ->assertStatus(422);

        $response = $this->send('/v1/admin/company-admins/impersonate', [
            'admin_id' => $this->companyAdminId,
            'reason' => 'Client reports an empty payroll tab',
        ])->assertOk()->assertJsonPath('data.expires_in_minutes', 60);

        $this->assertStringContainsString('custom-token:', Value::string($response->json('data.token')));

        // In both logs, so the client can always see that we entered their
        // account and why.
        $this->assertDatabaseHas('super_admin_audit_log', [
            'admin_id' => $this->operatorId,
            'action' => 'admin.impersonate',
            'target_id' => (string) $this->companyAdminId,
        ]);
        $this->assertDatabaseHas('audit_log', [
            'tenant_id' => $this->tenantId, 'action' => 'support.impersonate',
        ]);
    }

    public function test_impersonation_falls_back_to_the_companys_general_manager(): void
    {
        $this->send('/v1/admin/company-admins/impersonate', [
            'tenant_id' => $this->tenantId, 'reason' => 'Diagnosing a report',
        ])->assertOk()->assertJsonPath('data.admin.id', $this->companyAdminId);
    }

    public function test_an_account_that_never_signed_in_cannot_be_impersonated(): void
    {
        DB::table('admins')->where('id', $this->companyAdminId)->update(['firebase_uid' => null]);

        $this->send('/v1/admin/company-admins/impersonate', [
            'admin_id' => $this->companyAdminId, 'reason' => 'Trying anyway',
        ])->assertStatus(422);
    }

    public function test_a_suspended_account_cannot_be_impersonated(): void
    {
        DB::table('admins')->where('id', $this->companyAdminId)->update(['is_active' => 0]);

        $this->send('/v1/admin/company-admins/impersonate', [
            'admin_id' => $this->companyAdminId, 'reason' => 'Trying anyway',
        ])->assertStatus(422);
    }

    public function test_the_contact_book_lists_company_administrators_not_employees(): void
    {
        DB::table('admins')->insert([
            'firebase_uid' => 'staff-'.bin2hex(random_bytes(4)),
            'tenant_id' => $this->tenantId,
            'name' => 'An employee account',
            'role' => 'employee',
            'is_active' => 1,
        ]);

        $this->read('/v1/admin/company-admins?tenant_id='.$this->tenantId)
            ->assertOk()
            ->assertJsonPath('data.total', 1)
            ->assertJsonPath('data.items.0.name', 'Company manager')
            ->assertJsonPath('data.items.0.tenant_name', 'Panel fixture company');
    }

    public function test_an_operator_of_the_panel_is_created_in_the_right_table(): void
    {
        // The original listed one table and created rows in the other, so a
        // super admin you created never appeared anywhere.
        $response = $this->send('/v1/admin/operators', [
            'username' => 'newop',
            'password' => 'longenough',
            'role' => 'readonly',
        ])->assertOk();

        $this->assertDatabaseHas('super_admins', [
            'id' => Value::int($response->json('data.id')), 'username' => 'newop', 'role' => 'readonly',
        ]);
    }

    public function test_a_duplicate_operator_username_is_refused(): void
    {
        $this->send('/v1/admin/operators', ['username' => 'newop', 'password' => 'longenough'])->assertOk();
        $this->send('/v1/admin/operators', ['username' => 'newop', 'password' => 'longenough'])
            ->assertStatus(422);
    }

    public function test_a_short_operator_username_or_password_is_refused(): void
    {
        $this->send('/v1/admin/operators', ['username' => 'ab', 'password' => 'longenough'])
            ->assertStatus(422);
        $this->send('/v1/admin/operators', ['username' => 'valid', 'password' => 'short'])
            ->assertStatus(422);
    }

    public function test_the_panels_own_audit_trail_names_who_did_what(): void
    {
        $this->send('/v1/admin/tenants/activate', ['id' => $this->tenantId])->assertOk();

        $this->read('/v1/admin/audit?action=tenant')
            ->assertOk()
            ->assertJsonPath('data.items.0.action', 'tenant.activate')
            // The original never resolved the admin id to a name, and selected
            // the payload only to ignore it.
            ->assertJsonPath('data.items.0.admin_name', 'Operator superadmin');
    }

    public function test_the_audit_trail_filters_by_date_and_target(): void
    {
        $this->send('/v1/admin/tenants/activate', ['id' => $this->tenantId])->assertOk();

        $this->read('/v1/admin/audit?target_type=tenant&from=2000-01-01')
            ->assertOk()
            ->assertJsonPath('data.page', 1);

        $this->read('/v1/admin/audit?from=2099-01-01')
            ->assertOk()
            ->assertJsonPath('data.total', 0);
    }

    public function test_the_headline_numbers_are_reported(): void
    {
        $this->read('/v1/admin/dashboard')
            ->assertOk()
            ->assertJsonStructure(['data' => ['total_tenants', 'active_tenants', 'total_users', 'total_employees']]);
    }

    public function test_the_update_floor_is_recorded_per_platform(): void
    {
        $this->send('/v1/admin/force-update', ['platform' => 'android', 'min_version' => '2.1.0'])
            ->assertOk();

        $this->assertDatabaseHas('force_updates', [
            'platform' => 'android', 'min_version' => '2.1.0', 'is_active' => 1,
        ]);

        // Raising it again edits the same row rather than adding another.
        $this->send('/v1/admin/force-update', ['platform' => 'android', 'min_version' => '2.2.0'])
            ->assertOk();

        $this->assertSame(1, DB::table('force_updates')->where('platform', 'android')->count());
        $this->assertDatabaseHas('force_updates', ['platform' => 'android', 'min_version' => '2.2.0']);
    }

    public function test_a_malformed_update_floor_is_refused(): void
    {
        $this->send('/v1/admin/force-update', ['min_version' => 'v2'])->assertStatus(422);
        $this->send('/v1/admin/force-update', [])->assertStatus(422);
    }

    public function test_an_announcement_reaches_the_audience_it_names(): void
    {
        $employee = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'An employee',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
        ]);

        // "Send to everyone" used to reach only the managers' table, silently
        // excluding every employee on the platform.
        $this->send('/v1/admin/announcements/tenant', [
            'tenant_id' => $this->tenantId,
            'title' => 'Scheduled maintenance',
            'body' => 'Tonight at 11pm',
            'audience' => 'all',
        ])->assertOk()
            ->assertJsonPath('data.sent_admins', 1)
            ->assertJsonPath('data.sent_employees', 1);

        $this->assertSame($employee, $this->push->sent[0]['employee_id']);
    }

    public function test_an_announcement_to_admins_only_leaves_employees_alone(): void
    {
        DB::table('employees')->insert([
            'tenant_id' => $this->tenantId,
            'name' => 'An employee',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
        ]);

        $this->send('/v1/admin/announcements/tenant', [
            'tenant_id' => $this->tenantId,
            'title' => 'For managers',
            'body' => 'Payroll closes Friday',
            'audience' => 'admins',
        ])->assertOk()->assertJsonPath('data.sent_employees', 0);

        $this->assertSame([], $this->push->sent);
    }

    public function test_an_unknown_audience_or_empty_announcement_is_refused(): void
    {
        $this->send('/v1/admin/announcements/all', [
            'title' => 'Hello', 'body' => 'There', 'audience' => 'shareholders',
        ])->assertStatus(422);

        $this->send('/v1/admin/announcements/all', ['title' => '', 'body' => ''])->assertStatus(422);
    }

    public function test_diagnostics_answer_the_check_in_keeps_failing_call(): void
    {
        $this->read('/v1/admin/tenants/diagnostics?id='.$this->tenantId)
            ->assertOk()
            ->assertJsonPath('data.window_days', 30)
            ->assertJsonStructure(['data' => [
                'face' => ['attempts', 'rejection_rate', 'recent_rejections'],
                'security' => ['by_reason', 'recent'],
                'wifi', 'devices', 'kiosks', 'channels',
                'cron' => ['today'],
            ]]);
    }

    public function test_the_diagnostic_window_is_clamped(): void
    {
        $this->read('/v1/admin/tenants/diagnostics?id='.$this->tenantId.'&days=500')
            ->assertOk()->assertJsonPath('data.window_days', 90);
        $this->read('/v1/admin/tenants/diagnostics?id='.$this->tenantId.'&days=0')
            ->assertOk()->assertJsonPath('data.window_days', 1);
    }

    public function test_readonly_sees_everything_and_changes_nothing(): void
    {
        [, $token] = $this->operator('readonly');

        $this->read('/v1/admin/tenants', $token)->assertOk();
        $this->read('/v1/admin/tenants/diagnostics?id='.$this->tenantId, $token)->assertOk();
        $this->read('/v1/admin/audit', $token)->assertOk();

        $this->send('/v1/admin/tenants/activate', ['id' => $this->tenantId], $token)->assertStatus(403);
        $this->send('/v1/admin/company-admins/set-active', [
            'admin_id' => $this->companyAdminId, 'is_active' => false,
        ], $token)->assertStatus(403);
    }

    public function test_the_irreversible_actions_need_superadmin(): void
    {
        [, $token] = $this->operator('admin');

        // An admin acts on companies and their people.
        $this->send('/v1/admin/tenants/activate', ['id' => $this->tenantId], $token)->assertOk();

        // But not the things that cannot be undone from a phone call.
        $this->send('/v1/admin/tenants', ['name' => 'Nope'], $token)->assertStatus(403);
        $this->send('/v1/admin/operators', [
            'username' => 'nope', 'password' => 'longenough',
        ], $token)->assertStatus(403);
        $this->send('/v1/admin/force-update', ['min_version' => '1.0.0'], $token)->assertStatus(403);
        $this->send('/v1/admin/company-admins/impersonate', [
            'admin_id' => $this->companyAdminId, 'reason' => 'Nope',
        ], $token)->assertStatus(403);
    }
}
