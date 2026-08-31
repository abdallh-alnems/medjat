<?php

declare(strict_types=1);

namespace Tests\Feature\Leave;

use App\Models\EmployeeAuthToken;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Shared\Time\TenantClock;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\CreatesFixtures;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Asking for time off, and what happens to the request afterwards.
 */
final class LeaveRequestTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private int $employeeId;

    private string $employeeToken;

    private string $adminToken;

    private string $viewerToken;

    private FakePushSender $push;

    private string $future;

    private string $farFuture;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->push = new FakePushSender;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, $this->push);

        $this->tenantId = $this->createTenant();
        DB::table('tenants')->where('id', $this->tenantId)->update([
            'default_annual_leave_days' => 21,
            'apply_legal_seniority_entitlement' => 0,
        ]);
        DB::table('approval_chains')->where('tenant_id', $this->tenantId)->delete();

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Leave branch',
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Leave applicant',
            'status' => 'active',
            'base_salary' => 3000,
            'branch_id' => $this->branchId,
            'hire_date' => '2020-01-01',
        ]);

        // Relative to the company's today, because a request in the past is
        // refused and the suite has to pass on any date.
        $today = TenantClock::date($this->tenantId);
        $this->future = date('Y-m-d', (int) strtotime($today.' +10 days'));
        $this->farFuture = date('Y-m-d', (int) strtotime($today.' +14 days'));

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-leave',
        ]);
        $this->employeeToken = $plain;

        $this->adminToken = $this->admin($firebase, 'general_manager');
        $this->viewerToken = $this->admin($firebase, 'viewer');
    }

    private function admin(FakeFirebaseTokenVerifier $firebase, string $role): string
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Admin '.$role,
            'role' => $role,
            'is_active' => 1,
        ]);

        return $firebase->issue($uid);
    }

    private function asEmployee(): self
    {
        $this->withHeader('X-Employee-Token', $this->employeeToken);

        return $this;
    }

    private function asAdmin(): self
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken);

        return $this;
    }

    private function existingLeave(string $start, string $end, string $status = 'pending', string $type = 'annual'): int
    {
        return (int) DB::table('leaves')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'date' => $start,
            'start_date' => $start,
            'end_date' => $end,
            'type' => $type,
            'status' => $status,
        ]);
    }

    private function shift(int $days): string
    {
        return date('Y-m-d', (int) strtotime(TenantClock::date($this->tenantId).' +'.$days.' days'));
    }

    // ── Applying ─────────────────────────────────────────────────────────

    public function test_an_employee_can_ask_for_leave(): void
    {
        $this->asEmployee()->postJson('/v1/leaves/apply', [
            'date' => $this->future,
            'start_date' => $this->future,
            'end_date' => $this->farFuture,
            'type' => 'annual',
            'reason' => 'Family',
        ])->assertOk()->assertJsonStructure(['data' => ['leave_id']]);

        $this->assertDatabaseHas('leaves', [
            'employee_id' => $this->employeeId,
            'type' => 'annual',
            'status' => 'pending',
            'start_date' => $this->future,
            'end_date' => $this->farFuture,
        ]);
    }

    public function test_the_managers_are_told_a_request_is_waiting(): void
    {
        $this->asEmployee()->postJson('/v1/leaves/apply', [
            'date' => $this->future,
            'type' => 'annual',
        ])->assertOk();

        $this->assertDatabaseHas('notifications', [
            'tenant_id' => $this->tenantId,
            'type' => 'leave',
            'title_ar' => 'طلب إجازة جديد',
        ]);
        $this->assertNotEmpty($this->push->sentToAdmins);
    }

    public function test_leave_cannot_start_in_the_past(): void
    {
        $this->asEmployee()->postJson('/v1/leaves/apply', [
            'date' => '2020-01-01',
            'type' => 'annual',
        ])->assertStatus(422)->assertJsonPath('error_code', 'leave_past_date');
    }

    public function test_a_period_that_clashes_with_existing_leave_is_refused(): void
    {
        $this->existingLeave($this->future, $this->farFuture, 'approved');

        $this->asEmployee()->postJson('/v1/leaves/apply', [
            'date' => $this->shift(12),
            'start_date' => $this->shift(12),
            'end_date' => $this->shift(16),
            'type' => 'sick',
        ])->assertStatus(409)->assertJsonPath('error_code', 'leave_overlap');
    }

    public function test_a_clash_with_a_request_nobody_has_decided_yet_also_counts(): void
    {
        // Two overlapping requests sitting in a manager's inbox is a mess
        // somebody has to untangle by hand.
        $this->existingLeave($this->future, $this->farFuture, 'pending');

        $this->asEmployee()->postJson('/v1/leaves/apply', [
            'date' => $this->future,
            'type' => 'annual',
        ])->assertStatus(409)->assertJsonPath('error_code', 'leave_overlap');
    }

    public function test_annual_leave_beyond_the_remaining_balance_is_refused(): void
    {
        DB::table('employees')->where('id', $this->employeeId)->update(['annual_leave_days' => 3]);

        $this->asEmployee()->postJson('/v1/leaves/apply', [
            'date' => $this->future,
            'start_date' => $this->future,
            'end_date' => $this->shift(20),
            'type' => 'annual',
        ])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'leave_balance_insufficient')
            // The figures travel with the refusal so the app can say what is
            // actually left rather than just "no".
            ->assertJsonPath('meta.remaining', 3);
    }

    public function test_unpaid_leave_is_not_checked_against_the_annual_balance(): void
    {
        DB::table('employees')->where('id', $this->employeeId)->update(['annual_leave_days' => 0]);

        $this->asEmployee()->postJson('/v1/leaves/apply', [
            'date' => $this->future,
            'start_date' => $this->future,
            'end_date' => $this->shift(20),
            'type' => 'unpaid',
        ])->assertOk();
    }

    public function test_a_third_undecided_request_is_refused(): void
    {
        $this->existingLeave($this->shift(30), $this->shift(31));
        $this->existingLeave($this->shift(40), $this->shift(41));

        $this->asEmployee()->postJson('/v1/leaves/apply', [
            'date' => $this->future,
            'type' => 'annual',
        ])->assertStatus(422)->assertJsonPath('error_code', 'leave_pending_limit');
    }

    public function test_an_unknown_leave_type_is_refused(): void
    {
        $this->asEmployee()->postJson('/v1/leaves/apply', [
            'date' => $this->future,
            'type' => 'sabbatical',
        ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_type');
    }

    // ── Reading back ─────────────────────────────────────────────────────

    public function test_an_employee_sees_their_own_requests_with_the_day_count(): void
    {
        $this->existingLeave($this->future, $this->farFuture);

        $this->asEmployee()->getJson('/v1/leaves/mine')
            ->assertOk()
            ->assertJsonPath('data.items.0.days', 5)
            ->assertJsonPath('data.items.0.status', 'pending');
    }

    public function test_an_employee_sees_only_their_own_requests(): void
    {
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Somebody else',
            'status' => 'active',
            'base_salary' => 1000,
        ]);
        DB::table('leaves')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $stranger,
            'date' => $this->future,
            'start_date' => $this->future,
            'end_date' => $this->future,
            'type' => 'annual',
            'status' => 'pending',
        ]);

        $items = $this->asEmployee()->getJson('/v1/leaves/mine')->assertOk()->json('data.items');

        $this->assertIsArray($items);
        $this->assertSame([], $items);
    }

    public function test_an_employee_reads_their_own_balance(): void
    {
        $this->asEmployee()->getJson('/v1/leaves/my-balance?year=2026')
            ->assertOk()
            ->assertJsonPath('data.entitlement_days', 21)
            ->assertJsonPath('data.year', 2026);
    }

    // ── Changing and withdrawing ─────────────────────────────────────────

    public function test_an_employee_can_withdraw_a_request_nobody_has_decided(): void
    {
        $id = $this->existingLeave($this->future, $this->farFuture);

        $this->asEmployee()->postJson('/v1/leaves/cancel', ['leave_id' => $id])->assertOk();

        $this->assertDatabaseMissing('leaves', ['id' => $id]);
    }

    public function test_an_approved_request_cannot_be_withdrawn(): void
    {
        $id = $this->existingLeave($this->future, $this->farFuture, 'approved');

        $this->asEmployee()->postJson('/v1/leaves/cancel', ['leave_id' => $id])
            ->assertStatus(409)->assertJsonPath('error_code', 'leave_not_cancellable');

        $this->assertDatabaseHas('leaves', ['id' => $id]);
    }

    public function test_an_employee_cannot_withdraw_somebody_elses_request(): void
    {
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Somebody else',
            'status' => 'active',
            'base_salary' => 1000,
        ]);
        $id = (int) DB::table('leaves')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $stranger,
            'date' => $this->future,
            'start_date' => $this->future,
            'end_date' => $this->future,
            'type' => 'annual',
            'status' => 'pending',
        ]);

        $this->asEmployee()->postJson('/v1/leaves/cancel', ['leave_id' => $id])->assertStatus(409);
        $this->assertDatabaseHas('leaves', ['id' => $id]);
    }

    public function test_an_employee_can_amend_a_request_nobody_has_decided(): void
    {
        $id = $this->existingLeave($this->future, $this->farFuture);

        $this->asEmployee()->postJson('/v1/leaves/update', [
            'leave_id' => $id,
            'type' => 'sick',
            'start_date' => $this->shift(11),
            'end_date' => $this->shift(12),
            'reason' => 'Changed my mind',
        ])->assertOk();

        $this->assertDatabaseHas('leaves', [
            'id' => $id,
            'type' => 'sick',
            'start_date' => $this->shift(11),
            'end_date' => $this->shift(12),
        ]);
    }

    public function test_amending_a_request_is_not_blocked_by_the_request_itself(): void
    {
        // A request always overlaps itself; excluding it is the whole reason
        // the overlap check takes an id to ignore.
        $id = $this->existingLeave($this->future, $this->farFuture);

        $this->asEmployee()->postJson('/v1/leaves/update', [
            'leave_id' => $id,
            'type' => 'annual',
            'start_date' => $this->future,
            'end_date' => $this->farFuture,
        ])->assertOk();
    }

    public function test_an_end_date_before_the_start_is_refused(): void
    {
        $id = $this->existingLeave($this->future, $this->farFuture);

        $this->asEmployee()->postJson('/v1/leaves/update', [
            'leave_id' => $id,
            'type' => 'annual',
            'start_date' => $this->shift(14),
            'end_date' => $this->shift(10),
        ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_date_range');
    }

    public function test_an_approved_request_cannot_be_amended(): void
    {
        $id = $this->existingLeave($this->future, $this->farFuture, 'approved');

        $this->asEmployee()->postJson('/v1/leaves/update', [
            'leave_id' => $id,
            'type' => 'sick',
            'start_date' => $this->future,
            'end_date' => $this->farFuture,
        ])->assertStatus(409)->assertJsonPath('error_code', 'leave_not_editable');
    }

    // ── The management side ──────────────────────────────────────────────

    public function test_leave_management_is_closed_without_the_permission(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/v1/leaves')
            ->assertForbidden();
    }

    public function test_the_management_list_carries_the_names_behind_the_ids(): void
    {
        $this->existingLeave($this->future, $this->farFuture);

        $this->asAdmin()->getJson('/v1/leaves?branch_id='.$this->branchId)
            ->assertOk()
            ->assertJsonPath('data.items.0.employee_name', 'Leave applicant')
            ->assertJsonPath('data.items.0.branch_name', 'Leave branch');
    }

    public function test_approving_tells_the_employee(): void
    {
        $id = $this->existingLeave($this->future, $this->farFuture);

        $this->asAdmin()->postJson('/v1/leaves/approve', ['leave_id' => $id])->assertOk();

        $this->assertDatabaseHas('leaves', ['id' => $id, 'status' => 'approved']);
        $this->assertDatabaseHas('notifications', [
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'type' => 'leave',
            'title_ar' => 'تم قبول الإجازة',
        ]);
    }

    public function test_a_rejection_carries_its_reason_to_the_employee(): void
    {
        // "Rejected" on its own sends the employee to ask a manager what they
        // should have done differently.
        $id = $this->existingLeave($this->future, $this->farFuture);

        $this->asAdmin()->postJson('/v1/leaves/reject', [
            'leave_id' => $id,
            'rejection_reason' => 'Peak season',
        ])->assertOk();

        $this->assertDatabaseHas('leaves', [
            'id' => $id,
            'status' => 'rejected',
            'rejection_reason' => 'Peak season',
        ]);
        $this->assertDatabaseHas('notifications', [
            'employee_id' => $this->employeeId,
            'body_ar' => 'تم رفض طلب الإجازة الخاص بك. السبب: Peak season',
        ]);
    }

    public function test_a_manager_records_leave_on_somebodys_behalf_and_can_approve_it_outright(): void
    {
        $this->asAdmin()->postJson('/v1/leaves', [
            'employee_id' => $this->employeeId,
            'type' => 'annual',
            'start_date' => $this->future,
            'end_date' => $this->farFuture,
            'auto_approve' => true,
        ])->assertOk()->assertJsonPath('data.status', 'approved');

        $this->assertDatabaseHas('leaves', [
            'employee_id' => $this->employeeId,
            'start_date' => $this->future,
            'status' => 'approved',
        ]);
    }

    public function test_a_period_past_the_balance_is_split_into_paid_and_unpaid(): void
    {
        // What actually happens when somebody takes three weeks with two left;
        // recording it as one over-long annual leave would overdraw the balance.
        DB::table('employees')->where('id', $this->employeeId)->update(['annual_leave_days' => 3]);

        $this->asAdmin()->postJson('/v1/leaves', [
            'employee_id' => $this->employeeId,
            'type' => 'annual',
            'start_date' => $this->future,
            'end_date' => $this->shift(14),
            'auto_approve' => true,
        ])
            ->assertOk()
            ->assertJsonPath('data.warning', 'balance_exceeded')
            ->assertJsonPath('data.paid_days', 3)
            ->assertJsonPath('data.unpaid_days', 2);

        $this->assertDatabaseHas('leaves', [
            'employee_id' => $this->employeeId,
            'type' => 'annual',
            'start_date' => $this->future,
            'end_date' => $this->shift(12),
        ]);
        $this->assertDatabaseHas('leaves', [
            'employee_id' => $this->employeeId,
            'type' => 'unpaid',
            'start_date' => $this->shift(13),
            'end_date' => $this->shift(14),
        ]);
    }

    public function test_a_company_can_choose_to_be_stopped_instead_of_split(): void
    {
        DB::table('employees')->where('id', $this->employeeId)->update(['annual_leave_days' => 3]);

        $this->asAdmin()->postJson('/v1/leaves', [
            'employee_id' => $this->employeeId,
            'type' => 'annual',
            'start_date' => $this->future,
            'end_date' => $this->shift(14),
            'on_exceed' => 'block',
        ])->assertStatus(422)->assertJsonPath('error_code', 'balance_exceeded');

        $this->assertDatabaseMissing('leaves', ['employee_id' => $this->employeeId]);
    }

    public function test_a_manager_reads_somebody_elses_balance(): void
    {
        $this->asAdmin()->getJson('/v1/leaves/balance?employee_id='.$this->employeeId.'&year=2026')
            ->assertOk()
            ->assertJsonPath('data.entitlement_days', 21);
    }

    public function test_reading_somebody_elses_balance_needs_the_permission(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/v1/leaves/balance?employee_id='.$this->employeeId)
            ->assertForbidden();
    }

    public function test_a_recurring_weekly_day_off_can_be_set_for_a_branch(): void
    {
        $this->asAdmin()->postJson('/v1/leaves/recurring', [
            'day_of_week' => 'friday',
            'branch_id' => $this->branchId,
        ])->assertOk();

        $this->assertDatabaseHas('recurring_leaves', [
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'day_of_week' => 'friday',
            'is_active' => 1,
        ]);
    }

    public function test_an_invalid_day_of_week_is_refused(): void
    {
        $this->asAdmin()->postJson('/v1/leaves/recurring', ['day_of_week' => 'caturday'])
            ->assertStatus(422)->assertJsonPath('error_code', 'invalid_day_of_week');
    }
}
