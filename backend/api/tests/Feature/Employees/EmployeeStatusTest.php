<?php

declare(strict_types=1);

namespace Tests\Feature\Employees;

use App\Models\Admin;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\CreatesFixtures;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * Suspension, re-hiring, the crew supervisor, and the browser PIN reset.
 */
final class EmployeeStatusTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    private int $tenantId;

    private Employee $employee;

    private string $token;

    private Admin $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);

        $this->employee = $this->createEmployee($this->createTenant());
        $this->tenantId = $this->employee->tenant_id;

        $uid = 'uid-'.bin2hex(random_bytes(6));
        $id = Admin::query()->insertGetId([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);

        $this->admin = Admin::query()->findOrFail($id);
        $this->token = $firebase->issue($uid);

        DB::table('employee_suspensions')->where('employee_id', $this->employee->id)->delete();
    }

    /**
     * @param  array<string, mixed>  $body
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function send(string $path, array $body): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $this->token)->postJson($path, $body);
    }

    // ── Suspension ───────────────────────────────────────────────────────

    public function test_suspending_records_the_status_the_employee_held_before(): void
    {
        // Somebody suspended while on leave goes back to being on leave, and
        // that cannot be reconstructed afterwards.
        Employee::query()->whereKey($this->employee->id)->update(['status' => 'on_leave']);

        $this->send('/v1/employees/suspend', [
            'employee_id' => $this->employee->id,
            'reason' => 'Under investigation',
        ])->assertOk();

        $this->assertSame('suspended', DB::table('employees')->where('id', $this->employee->id)->value('status'));
        $this->assertSame(
            'on_leave',
            DB::table('employee_suspensions')->where('employee_id', $this->employee->id)->value('previous_status')
        );
    }

    public function test_ending_a_suspension_restores_that_status(): void
    {
        Employee::query()->whereKey($this->employee->id)->update(['status' => 'on_leave']);

        $this->send('/v1/employees/suspend', [
            'employee_id' => $this->employee->id, 'reason' => 'Investigation',
        ])->assertOk();

        $this->send('/v1/employees/end-suspension', ['employee_id' => $this->employee->id])
            ->assertOk()
            ->assertJsonPath('data.restored_status', 'on_leave');

        $this->assertSame('on_leave', DB::table('employees')->where('id', $this->employee->id)->value('status'));
    }

    public function test_a_reason_is_required(): void
    {
        $this->send('/v1/employees/suspend', ['employee_id' => $this->employee->id])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'missing_fields');
    }

    public function test_partial_pay_needs_a_percentage_strictly_between_the_ends(): void
    {
        // Zero is 'unpaid' and a hundred is 'full'; storing either here would be
        // the same thing said two ways.
        foreach ([0, 100, -5, 150] as $percentage) {
            $this->send('/v1/employees/suspend', [
                'employee_id' => $this->employee->id,
                'reason' => 'Investigation',
                'pay_mode' => 'partial',
                'pay_percentage' => $percentage,
            ])->assertStatus(422)->assertJsonPath('error_code', 'pay_percentage_between_0_100');
        }
    }

    public function test_a_terminated_employee_cannot_be_suspended(): void
    {
        Employee::query()->whereKey($this->employee->id)->update(['status' => 'terminated']);

        $this->send('/v1/employees/suspend', [
            'employee_id' => $this->employee->id, 'reason' => 'Investigation',
        ])->assertStatus(422)->assertJsonPath('error_code', 'cannot_suspend_terminated_employee');
    }

    public function test_only_one_suspension_can_be_active(): void
    {
        $body = ['employee_id' => $this->employee->id, 'reason' => 'Investigation'];

        $this->send('/v1/employees/suspend', $body)->assertOk();
        $this->send('/v1/employees/suspend', $body)
            ->assertStatus(409)
            ->assertJsonPath('error_code', 'employee_already_active_suspension');
    }

    public function test_an_end_date_before_the_start_is_refused(): void
    {
        $this->send('/v1/employees/suspend', [
            'employee_id' => $this->employee->id,
            'reason' => 'Investigation',
            'start_date' => '2026-06-01',
            'end_date' => '2026-05-01',
        ])->assertStatus(422)->assertJsonPath('error_code', 'end_date_after_start_date');
    }

    public function test_an_elapsed_suspension_is_reconciled_when_the_screen_is_opened(): void
    {
        // Somebody unable to work for a reason nobody remembers setting is the
        // failure this avoids.
        Employee::query()->whereKey($this->employee->id)->update(['status' => 'suspended']);
        DB::table('employee_suspensions')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'reason' => 'Elapsed',
            'pay_mode' => 'unpaid',
            'start_date' => date('Y-m-d', strtotime('-10 days')),
            'end_date' => date('Y-m-d', strtotime('-2 days')),
            'previous_status' => 'active',
            'status' => 'active',
        ]);

        $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/suspensions?employee_id='.$this->employee->id)
            ->assertOk()
            ->assertJsonPath('data.active', null);

        $this->assertSame('active', DB::table('employees')->where('id', $this->employee->id)->value('status'));
    }

    public function test_reconciling_does_not_drag_back_somebody_since_terminated(): void
    {
        Employee::query()->whereKey($this->employee->id)->update(['status' => 'terminated']);
        DB::table('employee_suspensions')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'reason' => 'Elapsed',
            'pay_mode' => 'unpaid',
            'start_date' => date('Y-m-d', strtotime('-10 days')),
            'end_date' => date('Y-m-d', strtotime('-2 days')),
            'previous_status' => 'active',
            'status' => 'active',
        ]);

        $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/suspensions?employee_id='.$this->employee->id)
            ->assertOk();

        $this->assertSame('terminated', DB::table('employees')->where('id', $this->employee->id)->value('status'));
    }

    // ── Re-hiring ────────────────────────────────────────────────────────

    public function test_re_hiring_returns_them_to_pending_with_a_fresh_code(): void
    {
        // The old token was revoked at termination, so they have to link a
        // device again.
        Employee::query()->whereKey($this->employee->id)
            ->update(['status' => 'terminated', 'terminated_at' => now()]);

        $this->send('/v1/employees/reactivate', ['employee_id' => $this->employee->id])
            ->assertOk()
            ->assertJsonStructure(['data' => ['message', 'activation_code', 'expires_at']]);

        $row = DB::table('employees')->where('id', $this->employee->id)->first();
        $this->assertNotNull($row);
        $this->assertSame('pending_activation', $row->status);
        $this->assertNull($row->terminated_at);
    }

    public function test_re_hiring_clears_the_previous_settlement(): void
    {
        // A future termination starts from a clean draft rather than adding to
        // a figure that was already paid.
        Employee::query()->whereKey($this->employee->id)->update(['status' => 'terminated']);
        DB::table('employee_settlements')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'last_working_day' => date('Y-m-d'),
            'net_amount' => 5000,
            'status' => 'draft',
        ]);

        $this->send('/v1/employees/reactivate', ['employee_id' => $this->employee->id])->assertOk();

        $this->assertDatabaseMissing('employee_settlements', ['employee_id' => $this->employee->id]);
    }

    public function test_somebody_still_employed_cannot_be_re_hired(): void
    {
        $this->send('/v1/employees/reactivate', ['employee_id' => $this->employee->id])
            ->assertStatus(409)
            ->assertJsonPath('error_code', 'not_terminated');
    }

    // ── Crew supervisor ──────────────────────────────────────────────────

    public function test_an_absent_key_is_refused_rather_than_treated_as_clearing(): void
    {
        // "Leave it alone" and "clear it" are different requests.
        $this->send('/v1/employees/crew-supervisor', ['employee_id' => $this->employee->id])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'supervisor_id_required');
    }

    public function test_an_explicit_null_clears_the_supervisor(): void
    {
        Employee::query()->whereKey($this->employee->id)->update(['crew_supervisor_id' => $this->employee->id]);

        $this->send('/v1/employees/crew-supervisor', [
            'employee_id' => $this->employee->id, 'supervisor_id' => null,
        ])->assertOk();

        $this->assertNull(DB::table('employees')->where('id', $this->employee->id)->value('crew_supervisor_id'));
    }

    public function test_somebody_cannot_supervise_themselves(): void
    {
        $this->send('/v1/employees/crew-supervisor', [
            'employee_id' => $this->employee->id, 'supervisor_id' => $this->employee->id,
        ])->assertStatus(422)->assertJsonPath('error_code', 'supervisor_cycle');
    }

    public function test_a_longer_supervision_ring_is_refused(): void
    {
        // The database cannot check this: a CHECK cannot see other rows.
        $b = $this->createEmployee($this->tenantId);

        Employee::query()->whereKey($b->id)->update(['crew_supervisor_id' => $this->employee->id]);

        $this->send('/v1/employees/crew-supervisor', [
            'employee_id' => $this->employee->id, 'supervisor_id' => $b->id,
        ])->assertStatus(422)->assertJsonPath('error_code', 'supervisor_cycle');
    }

    public function test_a_supervisor_from_another_company_is_not_found(): void
    {
        // Otherwise the setting saves and the crew queries silently return
        // nothing, looking like a configuration that does not work.
        $other = $this->createEmployee($this->createTenant());

        $this->send('/v1/employees/crew-supervisor', [
            'employee_id' => $this->employee->id, 'supervisor_id' => $other->id,
        ])->assertNotFound();
    }

    public function test_a_terminated_supervisor_is_refused(): void
    {
        $b = $this->createEmployee($this->tenantId);
        Employee::query()->whereKey($b->id)->update(['status' => 'terminated']);

        $this->send('/v1/employees/crew-supervisor', [
            'employee_id' => $this->employee->id, 'supervisor_id' => $b->id,
        ])->assertStatus(422)->assertJsonPath('error_code', 'supervisor_terminated');
    }

    // ── Browser PIN reset ────────────────────────────────────────────────

    public function test_resetting_the_pin_severs_browser_access_immediately(): void
    {
        // A reset taking effect at the next expiry would leave up to sixteen
        // hours of access after the decision to end it.
        $web = EmployeeAuthToken::issueWeb($this->tenantId, $this->employee->id, 'browser-1', 3600);

        DB::table('employee_web_credentials')->where('employee_id', $this->employee->id)->delete();
        DB::table('employee_web_credentials')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'pin_hash' => password_hash('481920', PASSWORD_BCRYPT, ['cost' => 4]),
            'failed_attempts' => 0,
            'pin_set_at' => now(),
        ]);

        $this->send('/v1/employees/reset-web-pin', ['employee_id' => $this->employee->id])
            ->assertOk()
            ->assertJsonStructure(['data' => ['message', 'activation_code', 'expires_at']]);

        $this->assertNull(EmployeeAuthToken::findActiveByPlain($web['token']));
        $this->assertDatabaseMissing('employee_web_credentials', ['employee_id' => $this->employee->id]);
    }

    public function test_the_reset_leaves_the_phone_session_alone(): void
    {
        $phone = EmployeeAuthToken::issue($this->tenantId, $this->employee->id, 'handset', null, 'android', null);

        $this->send('/v1/employees/reset-web-pin', ['employee_id' => $this->employee->id])->assertOk();

        $this->assertNotNull(EmployeeAuthToken::findActiveByPlain($phone));
    }

    public function test_the_reset_is_audited(): void
    {
        $this->send('/v1/employees/reset-web-pin', ['employee_id' => $this->employee->id])->assertOk();

        $this->assertDatabaseHas('audit_log', [
            'admin_id' => $this->admin->id,
            'action' => 'employee.web_pin_reset',
            'target_id' => (string) $this->employee->id,
        ]);
    }

    public function test_an_employee_from_another_company_is_not_found(): void
    {
        $other = $this->createEmployee($this->createTenant());

        $this->send('/v1/employees/reset-web-pin', ['employee_id' => $other->id])->assertNotFound();
    }
}
