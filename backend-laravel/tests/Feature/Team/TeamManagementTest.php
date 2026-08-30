<?php

declare(strict_types=1);

namespace Tests\Feature\Team;

use App\Domain\Access\Permissions;
use App\Domain\Notifications\PushSender;
use App\Domain\Team\ManagerInvitation;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Who is on a company's team, what may be done to them, and by whom.
 */
final class TeamManagementTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private FakeFirebaseTokenVerifier $firebase;

    private int $gmId;

    private string $gmToken;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        // The dump carries a company's real staff; these cases are about the
        // people this test creates.
        DB::table('admins')->where('tenant_id', $this->tenantId)->update(['tenant_id' => null]);
        DB::table('manager_invitations')->where('tenant_id', $this->tenantId)->delete();

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Team branch',
        ]);

        [$this->gmId, $this->gmToken] = $this->member('general_manager', 'Top Manager');
    }

    /**
     * @return array{0: int, 1: string}
     */
    private function member(string $role, string $name, ?string $email = null): array
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        $id = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => $name,
            'email' => $email ?? strtolower(str_replace(' ', '.', $name)).'@example.test',
            'role' => $role,
            'is_active' => 1,
        ]);

        return [$id, $this->firebase->issue($uid)];
    }

    private function as(string $token): self
    {
        $this->withHeader('X-Firebase-Token', $token);

        return $this;
    }

    /**
     * @param  list<string>  $permissions
     */
    private function customise(int $adminId, array $permissions): void
    {
        DB::table('custom_roles')->insert([
            'tenant_id' => $this->tenantId,
            'admin_id' => $adminId,
            'name' => 'custom',
            'permissions' => json_encode($permissions),
        ]);
    }

    // ── The team page ────────────────────────────────────────────────────

    public function test_the_team_lists_management_roles_only(): void
    {
        $this->member('hr', 'HR Person');
        DB::table('admins')->insert([
            'firebase_uid' => 'uid-employee',
            'tenant_id' => $this->tenantId,
            'name' => 'An employee',
            'role' => 'employee',
            'is_active' => 1,
        ]);

        $items = $this->as($this->gmToken)->getJson('/app/managers/list_admins.php')
            ->assertOk()->json('data.items');

        $this->assertIsArray($items);
        $roles = [];
        foreach ($items as $row) {
            $this->assertIsArray($row);
            $roles[] = Value::string($row['role'] ?? null);
        }

        $this->assertContains('hr', $roles);
        $this->assertNotContains('employee', $roles);
    }

    public function test_each_row_says_whether_the_caller_may_act_on_it(): void
    {
        // So the apps can hide actions rather than offer them and then refuse.
        [$hrId] = $this->member('hr', 'HR Person');
        [$callerId, $hrToken] = $this->member('hr', 'Other HR');
        $this->customise($hrId, ['manage_employees']);
        $this->customise($callerId, ['manage_employees', 'add_managers']);

        $items = $this->as($hrToken)->getJson('/app/managers/list_admins.php')
            ->assertOk()->json('data.items');

        $this->assertIsArray($items);

        foreach ($items as $row) {
            $this->assertIsArray($row);

            if (Value::string($row['role']) === 'general_manager') {
                $this->assertFalse($row['can_manage'], 'HR must not be told they can manage a general manager');
            }

            if (Value::int($row['id']) === $hrId) {
                $this->assertTrue($row['can_manage']);
            }
        }
    }

    // ── Editing somebody ─────────────────────────────────────────────────

    public function test_a_role_and_branch_can_be_changed(): void
    {
        [$hrId] = $this->member('hr', 'HR Person');

        $this->as($this->gmToken)->postJson('/app/managers/update_admin.php', [
            'admin_id' => $hrId,
            'role' => 'branch_manager',
            'branch_id' => $this->branchId,
        ])->assertOk();

        $this->assertDatabaseHas('admins', [
            'id' => $hrId,
            'role' => 'branch_manager',
            'branch_id' => $this->branchId,
        ]);
    }

    public function test_a_role_change_drops_a_tailored_permission_set(): void
    {
        // The set was built against the old role; carrying it across would
        // leave somebody holding permissions their new role never granted.
        [$hrId] = $this->member('hr', 'HR Person');
        $this->customise($hrId, ['manage_employees', 'manage_payroll']);

        $this->as($this->gmToken)->postJson('/app/managers/update_admin.php', [
            'admin_id' => $hrId,
            'role' => 'viewer',
        ])->assertOk();

        $this->assertDatabaseMissing('custom_roles', ['admin_id' => $hrId]);
    }

    public function test_nobody_edits_their_own_role(): void
    {
        $this->as($this->gmToken)->postJson('/app/managers/update_admin.php', [
            'admin_id' => $this->gmId,
            'role' => 'viewer',
        ])->assertForbidden();
    }

    public function test_a_change_with_nothing_in_it_is_refused(): void
    {
        [$hrId] = $this->member('hr', 'HR Person');

        $this->as($this->gmToken)->postJson('/app/managers/update_admin.php', ['admin_id' => $hrId])
            ->assertStatus(422)->assertJsonPath('error_code', 'no_changes');
    }

    public function test_only_full_access_may_touch_a_general_manager(): void
    {
        [$otherGmId] = $this->member('general_manager', 'Second GM');
        [$hrId, $hrToken] = $this->member('hr', 'HR Person');
        $this->customise($hrId, Permissions::CATALOGUE);

        // Even holding every listed permission is not the same as full access.
        $this->as($hrToken)->postJson('/app/managers/update_admin.php', [
            'admin_id' => $otherGmId,
            'role' => 'viewer',
        ])->assertForbidden();
    }

    public function test_nobody_edits_somebody_who_outranks_them(): void
    {
        [$juniorId, $juniorToken] = $this->member('hr', 'Junior');
        [$seniorId] = $this->member('hr', 'Senior');
        $this->customise($juniorId, ['manage_employees', 'add_managers']);
        $this->customise($seniorId, ['manage_employees', 'add_managers', 'manage_payroll']);

        $this->as($juniorToken)->postJson('/app/managers/update_admin.php', [
            'admin_id' => $seniorId,
            'role' => 'viewer',
        ])->assertForbidden();
    }

    public function test_nobody_grants_a_role_above_their_own_access(): void
    {
        [$hrId, $hrToken] = $this->member('hr', 'HR Person');
        [$viewerId] = $this->member('viewer', 'A Viewer');
        $this->customise($hrId, ['manage_employees', 'add_managers']);

        $this->as($hrToken)->postJson('/app/managers/update_admin.php', [
            'admin_id' => $viewerId,
            'role' => 'general_manager',
        ])->assertForbidden();
    }

    public function test_an_unknown_branch_is_refused(): void
    {
        [$hrId] = $this->member('hr', 'HR Person');

        $this->as($this->gmToken)->postJson('/app/managers/update_admin.php', [
            'admin_id' => $hrId,
            'branch_id' => 9999999,
        ])->assertNotFound()->assertJsonPath('error_code', 'branch_not_found');
    }

    // ── Suspending and removing ──────────────────────────────────────────

    public function test_somebody_can_be_suspended_and_restored(): void
    {
        [$hrId] = $this->member('hr', 'HR Person');

        $this->as($this->gmToken)->postJson('/app/managers/set_admin_active.php', [
            'admin_id' => $hrId,
            'is_active' => false,
        ])->assertOk()->assertJsonPath('data.is_active', false);

        $this->assertDatabaseHas('admins', ['id' => $hrId, 'is_active' => 0]);

        $this->as($this->gmToken)->postJson('/app/managers/set_admin_active.php', [
            'admin_id' => $hrId,
            'is_active' => true,
        ])->assertOk();

        $this->assertDatabaseHas('admins', ['id' => $hrId, 'is_active' => 1]);
    }

    public function test_nobody_suspends_themselves(): void
    {
        $this->as($this->gmToken)->postJson('/app/managers/set_admin_active.php', [
            'admin_id' => $this->gmId,
            'is_active' => false,
        ])->assertForbidden();
    }

    public function test_removing_detaches_the_person_without_deleting_them(): void
    {
        // Deleting the row would orphan every audit entry that names them, and
        // they keep the ability to sign in and join somewhere else.
        [$hrId] = $this->member('hr', 'HR Person');
        $this->customise($hrId, ['manage_employees']);

        $this->as($this->gmToken)->postJson('/app/managers/remove_admin.php', ['admin_id' => $hrId])
            ->assertOk();

        $this->assertDatabaseHas('admins', [
            'id' => $hrId,
            'tenant_id' => null,
            'role' => 'pending',
            'is_active' => 1,
        ]);
        $this->assertDatabaseMissing('custom_roles', ['admin_id' => $hrId]);
    }

    public function test_a_company_cannot_be_left_without_an_active_general_manager(): void
    {
        // The count is of *active* general managers, so this fires when the
        // only other one is suspended: removing them would leave the company
        // one resignation away from having nobody who can appoint anybody.
        [$secondId, $secondToken] = $this->member('general_manager', 'Second GM');
        DB::table('admins')->where('id', $this->gmId)->update(['is_active' => 0]);

        $this->as($secondToken)->postJson('/app/managers/remove_admin.php', ['admin_id' => $this->gmId])
            ->assertStatus(409)
            ->assertJsonPath('error_code', 'cannot_remove_last_owner');

        $this->assertDatabaseHas('admins', ['id' => $this->gmId, 'tenant_id' => $this->tenantId]);
        unset($secondId);
    }

    public function test_one_of_two_active_general_managers_can_be_removed(): void
    {
        [, $secondToken] = $this->member('general_manager', 'Second GM');

        $this->as($secondToken)->postJson('/app/managers/remove_admin.php', ['admin_id' => $this->gmId])
            ->assertOk();

        $this->assertDatabaseHas('admins', ['id' => $this->gmId, 'tenant_id' => null]);
    }

    public function test_nobody_below_a_general_manager_can_remove_one(): void
    {
        [$hrId, $hrToken] = $this->member('hr', 'HR Person');
        $this->customise($hrId, Permissions::CATALOGUE);

        // Holding every listed permission is still not full access.
        $this->as($hrToken)->postJson('/app/managers/remove_admin.php', ['admin_id' => $this->gmId])
            ->assertForbidden();
    }

    public function test_nobody_removes_themselves(): void
    {
        $this->as($this->gmToken)->postJson('/app/managers/remove_admin.php', ['admin_id' => $this->gmId])
            ->assertForbidden();
    }

    public function test_somebody_from_another_company_is_not_found(): void
    {
        $otherTenant = Value::int(DB::table('tenants')->where('id', '!=', $this->tenantId)->value('id'));
        $stranger = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => 'uid-stranger',
            'tenant_id' => $otherTenant,
            'name' => 'Stranger',
            'role' => 'hr',
            'is_active' => 1,
        ]);

        $this->as($this->gmToken)->postJson('/app/managers/remove_admin.php', ['admin_id' => $stranger])
            ->assertNotFound();
    }

    // ── Tailored permissions ─────────────────────────────────────────────

    public function test_permissions_are_reported_with_the_roles_defaults_beside_them(): void
    {
        [$hrId] = $this->member('hr', 'HR Person');

        $this->as($this->gmToken)->getJson('/app/managers/get_admin_permissions.php?admin_id='.$hrId)
            ->assertOk()
            ->assertJsonPath('data.role', 'hr')
            ->assertJsonPath('data.is_customized', false)
            ->assertJsonPath('data.all_permissions', Permissions::CATALOGUE);
    }

    public function test_a_general_managers_defaults_are_the_whole_catalogue(): void
    {
        $this->as($this->gmToken)->getJson('/app/managers/get_admin_permissions.php?admin_id='.$this->gmId)
            ->assertOk()
            ->assertJsonPath('data.role_defaults', Permissions::CATALOGUE);
    }

    public function test_a_tailored_set_is_saved_and_reported_back(): void
    {
        [$hrId] = $this->member('hr', 'HR Person');

        $this->as($this->gmToken)->postJson('/app/managers/update_admin_permissions.php', [
            'admin_id' => $hrId,
            'permissions' => ['manage_employees', 'view_reports'],
        ])->assertOk();

        $this->as($this->gmToken)->getJson('/app/managers/get_admin_permissions.php?admin_id='.$hrId)
            ->assertOk()
            ->assertJsonPath('data.is_customized', true)
            ->assertJsonPath('data.effective_permissions', ['manage_employees', 'view_reports']);
    }

    public function test_a_tailored_set_actually_gates_requests(): void
    {
        // The point of the whole screen: what it saves is what the middleware
        // reads on the next request.
        [$hrId, $hrToken] = $this->member('hr', 'HR Person');
        $this->customise($hrId, ['view_reports']);

        $this->as($hrToken)->getJson('/app/managers/list_admins.php')->assertForbidden();
    }

    public function test_nobody_grants_a_permission_they_do_not_hold(): void
    {
        [$hrId, $hrToken] = $this->member('hr', 'HR Person');
        [$viewerId] = $this->member('viewer', 'A Viewer');
        $this->customise($hrId, ['add_managers', 'manage_employees']);

        $this->as($hrToken)->postJson('/app/managers/update_admin_permissions.php', [
            'admin_id' => $viewerId,
            'permissions' => ['manage_payroll'],
        ])->assertForbidden();
    }

    public function test_an_unknown_permission_is_refused(): void
    {
        [$hrId] = $this->member('hr', 'HR Person');

        $this->as($this->gmToken)->postJson('/app/managers/update_admin_permissions.php', [
            'admin_id' => $hrId,
            'permissions' => ['rule_the_world'],
        ])->assertStatus(400)->assertJsonPath('error_code', 'unknown_permission');
    }

    public function test_a_general_managers_permissions_cannot_be_narrowed(): void
    {
        // Their access is the definition of full access; narrowing it would
        // leave a company whose top role means something different.
        [$otherGmId] = $this->member('general_manager', 'Second GM');

        $this->as($this->gmToken)->postJson('/app/managers/update_admin_permissions.php', [
            'admin_id' => $otherGmId,
            'permissions' => ['view_reports'],
        ])->assertForbidden();
    }

    public function test_resetting_restores_the_roles_defaults(): void
    {
        [$hrId] = $this->member('hr', 'HR Person');
        $this->customise($hrId, ['view_reports']);

        $this->as($this->gmToken)->postJson('/app/managers/reset_admin_permissions.php', ['admin_id' => $hrId])
            ->assertOk();

        $this->assertDatabaseMissing('custom_roles', ['admin_id' => $hrId]);
    }

    // ── Invitations ──────────────────────────────────────────────────────

    public function test_an_invitation_is_issued_with_a_code_shown_once(): void
    {
        $response = $this->as($this->gmToken)->postJson('/app/managers/invite.php', [
            'name' => 'New Manager',
            'email' => 'new.manager@example.test',
            'role' => 'hr',
        ])->assertStatus(201)->assertJsonPath('data.expires_in_hours', ManagerInvitation::VALIDITY_HOURS);

        $code = Value::string($response->json('data.invitation_code'));
        $this->assertNotSame('', $code);

        // Stored hashed: a database read must not hand anybody a working
        // invitation into somebody else's company.
        $this->assertDatabaseMissing('manager_invitations', ['token_hash' => $code]);
        $this->assertDatabaseHas('manager_invitations', [
            'email' => 'new.manager@example.test',
            'token_hash' => ManagerInvitation::hash($code),
        ]);
    }

    public function test_the_window_is_measured_by_the_database_clock(): void
    {
        // Computed in PHP it was three hours short, because PHP runs UTC and
        // the expiry is compared against the database's own NOW().
        $this->as($this->gmToken)->postJson('/app/managers/invite.php', [
            'name' => 'New Manager',
            'email' => 'window@example.test',
            'role' => 'viewer',
        ])->assertStatus(201);

        $remaining = Value::int(
            DB::table('manager_invitations')->where('email', 'window@example.test')
                ->selectRaw('TIMESTAMPDIFF(HOUR, NOW(), expires_at) AS remaining')
                ->value('remaining')
        );

        $this->assertSame(ManagerInvitation::VALIDITY_HOURS, $remaining);
    }

    public function test_an_unregistered_email_may_still_be_invited(): void
    {
        // The invitation waits, and the person is linked when they sign up.
        $this->as($this->gmToken)->postJson('/app/managers/invite.php', [
            'name' => 'Nobody Yet',
            'email' => 'stranger@example.test',
            'role' => 'viewer',
        ])->assertStatus(201);
    }

    public function test_somebody_who_already_belongs_to_a_company_cannot_be_invited(): void
    {
        $this->member('hr', 'Taken Person', 'taken@example.test');

        $this->as($this->gmToken)->postJson('/app/managers/invite.php', [
            'name' => 'Taken Person',
            'email' => 'taken@example.test',
            'role' => 'viewer',
        ])->assertStatus(409)->assertJsonPath('error_code', 'user_already_in_company');
    }

    public function test_a_second_pending_invitation_to_the_same_address_is_refused(): void
    {
        $payload = ['name' => 'New Manager', 'email' => 'dup@example.test', 'role' => 'hr'];

        $this->as($this->gmToken)->postJson('/app/managers/invite.php', $payload)->assertStatus(201);

        $this->as($this->gmToken)->postJson('/app/managers/invite.php', $payload)
            ->assertStatus(409)->assertJsonPath('error_code', 'invitation_already_pending');
    }

    public function test_nobody_invites_somebody_into_a_role_above_their_own_access(): void
    {
        [$hrId, $hrToken] = $this->member('hr', 'HR Person');
        $this->customise($hrId, ['add_managers', 'manage_employees']);

        $this->as($hrToken)->postJson('/app/managers/invite.php', [
            'name' => 'Would-be GM',
            'email' => 'wouldbe@example.test',
            'role' => 'general_manager',
        ])->assertForbidden();
    }

    public function test_the_grant_check_measures_what_the_invitee_will_actually_receive(): void
    {
        // The original compared against a stale, smaller catalogue, so an
        // inviter holding only the old defaults could hand out a role that
        // grants more than they hold.
        [$hrId, $hrToken] = $this->member('hr', 'HR Person');
        $this->customise($hrId, ['add_managers', 'manage_employees', 'manage_attendance']);

        $this->as($hrToken)->postJson('/app/managers/invite.php', [
            'name' => 'Would-be HR',
            'email' => 'wouldbehr@example.test',
            'role' => 'hr',
        ])->assertForbidden();
    }

    public function test_an_invitation_is_listed_without_its_hash(): void
    {
        $this->as($this->gmToken)->postJson('/app/managers/invite.php', [
            'name' => 'New Manager',
            'email' => 'listed@example.test',
            'role' => 'hr',
        ])->assertStatus(201);

        $items = $this->as($this->gmToken)->getJson('/app/managers/list_invitations.php?status=pending')
            ->assertOk()->json('data.items');

        $this->assertIsArray($items);
        $this->assertCount(1, $items);
        $this->assertIsArray($items[0]);
        $this->assertArrayNotHasKey('token_hash', $items[0]);
    }

    public function test_an_invitation_can_be_cancelled_once(): void
    {
        $response = $this->as($this->gmToken)->postJson('/app/managers/invite.php', [
            'name' => 'New Manager',
            'email' => 'cancelme@example.test',
            'role' => 'hr',
        ])->assertStatus(201);

        $id = Value::int($response->json('data.invitation_id'));

        $this->as($this->gmToken)->getJson('/app/managers/cancel_invitation.php?id='.$id)->assertOk();

        $this->as($this->gmToken)->getJson('/app/managers/cancel_invitation.php?id='.$id)
            ->assertStatus(409)->assertJsonPath('error_code', 'invitation_already_cancelled');
    }

    public function test_resending_issues_a_new_code_and_revives_a_cancelled_invitation(): void
    {
        $response = $this->as($this->gmToken)->postJson('/app/managers/invite.php', [
            'name' => 'New Manager',
            'email' => 'resend@example.test',
            'role' => 'hr',
        ])->assertStatus(201);

        $id = Value::int($response->json('data.invitation_id'));
        $firstCode = Value::string($response->json('data.invitation_code'));

        $this->as($this->gmToken)->getJson('/app/managers/cancel_invitation.php?id='.$id)->assertOk();

        $resent = $this->as($this->gmToken)
            ->postJson('/app/managers/resend_invitation.php', ['id' => $id])
            ->assertOk();

        $newCode = Value::string($resent->json('data.invitation_code'));

        $this->assertNotSame($firstCode, $newCode);
        $this->assertDatabaseHas('manager_invitations', [
            'id' => $id,
            'token_hash' => ManagerInvitation::hash($newCode),
            'cancelled_at' => null,
        ]);
    }

    public function test_an_accepted_invitation_cannot_be_resent(): void
    {
        $response = $this->as($this->gmToken)->postJson('/app/managers/invite.php', [
            'name' => 'New Manager',
            'email' => 'accepted@example.test',
            'role' => 'hr',
        ])->assertStatus(201);

        $id = Value::int($response->json('data.invitation_id'));
        DB::table('manager_invitations')->where('id', $id)->update(['accepted_at' => DB::raw('NOW()')]);

        $this->as($this->gmToken)->postJson('/app/managers/resend_invitation.php', ['id' => $id])
            ->assertStatus(409)->assertJsonPath('error_code', 'invitation_already_accepted');
    }

    public function test_the_team_page_is_closed_without_the_permission(): void
    {
        [, $viewerToken] = $this->member('viewer', 'A Viewer');

        $this->as($viewerToken)->getJson('/app/managers/list_admins.php')->assertForbidden();
    }
}
