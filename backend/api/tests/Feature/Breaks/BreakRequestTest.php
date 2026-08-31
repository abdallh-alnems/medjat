<?php

declare(strict_types=1);

namespace Tests\Feature\Breaks;

use App\Models\EmployeeAuthToken;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Breaks\Domain\BreakRequests;
use App\Modules\Notifications\Domain\PushSender;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Short permissions to be away during a shift: asking, deciding, and the
 * window that closes on both.
 */
final class BreakRequestTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private int $employeeId;

    private string $employeeToken;

    private string $adminToken;

    private string $viewerToken;

    private FakePushSender $push;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->push = new FakePushSender;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, $this->push);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Break branch',
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Break asker',
            'status' => 'active',
            'base_salary' => 3000,
            'branch_id' => $this->branchId,
        ]);

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-break',
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

    /** A date safely in the future, in the company's own calendar. */
    private function future(int $days = 3): string
    {
        return date('Y-m-d', (int) strtotime(TenantClock::date($this->tenantId).' +'.$days.' days'));
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function ask(array $overrides = []): TestResponse
    {
        return $this->asEmployee()->postJson('/v1/breaks/request', $overrides + [
            'date' => $this->future(),
            'start_time' => '10:00',
            'end_time' => '12:00',
            'type' => 'إذن شخصي',
        ]);
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function existing(string $status = 'pending', array $overrides = []): int
    {
        return (int) DB::table('break_requests')->insertGetId($overrides + [
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'date' => $this->future(),
            'start_time' => '10:00:00',
            'end_time' => '12:00:00',
            'duration_minutes' => 120,
            'type' => 'إذن شخصي',
            'status' => $status,
        ]);
    }

    // ── Asking ───────────────────────────────────────────────────────────

    public function test_an_employee_asks_for_a_permission(): void
    {
        $this->ask()->assertOk()->assertJsonStructure(['data' => ['break_id']]);

        $this->assertDatabaseHas('break_requests', [
            'employee_id' => $this->employeeId,
            'status' => 'pending',
            'duration_minutes' => 120,
        ]);
    }

    public function test_the_managers_are_told(): void
    {
        $this->ask()->assertOk();

        $this->assertDatabaseHas('notifications', [
            'tenant_id' => $this->tenantId,
            // 'leave', not 'break': the enum has no such value, which is why
            // the original's break notifications silently never arrived.
            'type' => 'leave',
            'title_ar' => 'طلب إذن/استراحة جديد',
        ]);
        $this->assertNotEmpty($this->push->sentToAdmins);
    }

    public function test_an_end_before_the_start_is_refused(): void
    {
        $this->ask(['start_time' => '12:00', 'end_time' => '10:00'])
            ->assertStatus(422)->assertJsonPath('error_code', 'invalid_time_range');
    }

    public function test_a_permission_longer_than_a_working_day_is_refused(): void
    {
        // Past that it is not a permission, it is a day off.
        $this->ask(['start_time' => '00:00', 'end_time' => '23:00'])
            ->assertStatus(422)->assertJsonPath('error_code', 'duration_too_long');
    }

    public function test_a_window_that_has_already_closed_cannot_be_asked_for(): void
    {
        $this->ask(['date' => '2020-01-01'])
            ->assertStatus(422)->assertJsonPath('error_code', 'break_window_passed');
    }

    public function test_the_window_is_judged_by_the_companys_clock(): void
    {
        // Frozen at midday: the claim here is about which zone the window is
        // judged in, not about the hour, and a window built by subtracting
        // minutes from "now" wraps past midnight when the suite runs at 01:00.
        $this->travelTo(TenantClock::now($this->tenantId)->setTime(12, 0));

        // The original compared a company-zone window against a UTC clock, so a
        // closed window looked open for another three hours.
        $today = TenantClock::date($this->tenantId);
        $justGone = date('H:i', (int) strtotime(TenantClock::timestamp($this->tenantId).' -30 minutes'));
        $earlier = date('H:i', (int) strtotime(TenantClock::timestamp($this->tenantId).' -90 minutes'));

        $this->ask(['date' => $today, 'start_time' => $earlier, 'end_time' => $justGone])
            ->assertStatus(422)->assertJsonPath('error_code', 'break_window_passed');
    }

    public function test_an_overlapping_request_is_refused(): void
    {
        $this->existing();

        $this->ask(['start_time' => '11:00', 'end_time' => '13:00'])
            ->assertStatus(409)->assertJsonPath('error_code', 'break_overlap');
    }

    public function test_a_touching_but_not_overlapping_window_is_allowed(): void
    {
        // Ending at 12:00 and starting at 12:00 is not an overlap.
        $this->existing();

        $this->ask(['start_time' => '12:00', 'end_time' => '13:00'])->assertOk();
    }

    public function test_a_cancelled_request_does_not_block_a_new_one(): void
    {
        $this->existing('cancelled');

        $this->ask()->assertOk();
    }

    // ── Reading back ─────────────────────────────────────────────────────

    public function test_an_employee_sees_only_their_own_requests(): void
    {
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Someone else',
            'status' => 'active',
            'base_salary' => 1000,
            'branch_id' => $this->branchId,
        ]);
        DB::table('break_requests')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $stranger,
            'date' => $this->future(),
            'start_time' => '10:00:00',
            'end_time' => '11:00:00',
            'duration_minutes' => 60,
            'type' => 'إذن',
            'status' => 'pending',
        ]);
        $mine = $this->existing();

        $breaks = $this->asEmployee()->getJson('/v1/breaks/mine')->assertOk()->json('data.breaks');

        $this->assertIsArray($breaks);
        $this->assertCount(1, $breaks);
        $this->assertIsArray($breaks[0]);
        $this->assertSame($mine, Value::int($breaks[0]['id']));
    }

    public function test_a_request_whose_window_closed_is_swept_before_it_is_listed(): void
    {
        // A request cannot stay pending once its time is gone.
        $stale = $this->existing('pending', ['date' => '2020-01-01']);

        $this->asEmployee()->getJson('/v1/breaks/mine')->assertOk();

        $this->assertDatabaseHas('break_requests', ['id' => $stale, 'status' => 'cancelled']);
    }

    // ── Withdrawing ──────────────────────────────────────────────────────

    public function test_an_employee_withdraws_an_undecided_request(): void
    {
        $id = $this->existing();

        $this->asEmployee()->postJson('/v1/breaks/cancel', ['break_id' => $id])->assertOk();

        $this->assertDatabaseHas('break_requests', ['id' => $id, 'status' => 'cancelled']);
    }

    public function test_a_decided_request_cannot_be_withdrawn(): void
    {
        $id = $this->existing('approved');

        $this->asEmployee()->postJson('/v1/breaks/cancel', ['break_id' => $id])
            ->assertStatus(409)->assertJsonPath('error_code', 'not_pending');
    }

    public function test_somebody_elses_request_is_simply_not_found(): void
    {
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Someone else',
            'status' => 'active',
            'base_salary' => 1000,
        ]);
        $id = (int) DB::table('break_requests')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $stranger,
            'date' => $this->future(),
            'start_time' => '10:00:00',
            'end_time' => '11:00:00',
            'duration_minutes' => 60,
            'type' => 'إذن',
            'status' => 'pending',
        ]);

        $this->asEmployee()->postJson('/v1/breaks/cancel', ['break_id' => $id])->assertNotFound();
    }

    // ── Deciding ─────────────────────────────────────────────────────────

    public function test_a_manager_approves_and_the_employee_is_told(): void
    {
        $id = $this->existing();

        $this->asAdmin()->postJson('/v1/breaks/approve', ['break_id' => $id])->assertOk();

        $this->assertDatabaseHas('break_requests', ['id' => $id, 'status' => 'approved']);
        $this->assertDatabaseHas('notifications', [
            'employee_id' => $this->employeeId,
            'type' => 'leave',
            'title_ar' => 'تم قبول الإذن',
        ]);
    }

    public function test_the_deduction_choice_at_approval_wins(): void
    {
        // The manager sees the request in context; the asker only saw a form.
        $id = $this->existing('pending', ['deduct_from_salary' => 0]);

        $this->asAdmin()->postJson('/v1/breaks/approve', [
            'break_id' => $id,
            'deduct_from_salary' => true,
        ])->assertOk();

        $this->assertDatabaseHas('break_requests', ['id' => $id, 'deduct_from_salary' => 1]);
    }

    public function test_the_choice_made_when_asking_stands_if_the_manager_says_nothing(): void
    {
        $id = $this->existing('pending', ['deduct_from_salary' => 1]);

        $this->asAdmin()->postJson('/v1/breaks/approve', ['break_id' => $id])->assertOk();

        $this->assertDatabaseHas('break_requests', ['id' => $id, 'deduct_from_salary' => 1]);
    }

    public function test_a_window_that_closed_cannot_be_approved_after_the_fact(): void
    {
        // Approving it would record an unauthorised absence as authorised.
        $id = $this->existing('pending', ['date' => '2020-01-01']);

        $this->asAdmin()->postJson('/v1/breaks/approve', ['break_id' => $id])
            ->assertStatus(409)->assertJsonPath('error_code', 'break_window_passed');

        $this->assertDatabaseHas('break_requests', ['id' => $id, 'status' => 'cancelled']);
    }

    public function test_a_rejection_carries_its_reason(): void
    {
        $id = $this->existing();

        $this->asAdmin()->postJson('/v1/breaks/reject', [
            'break_id' => $id,
            'rejection_reason' => 'Short-staffed that morning',
        ])->assertOk();

        $this->assertDatabaseHas('break_requests', [
            'id' => $id,
            'status' => 'rejected',
            'decision_note' => 'Short-staffed that morning',
        ]);
        $this->assertDatabaseHas('notifications', [
            'employee_id' => $this->employeeId,
            'body_ar' => 'تم رفض طلب الإذن الخاص بك: Short-staffed that morning',
        ]);
    }

    public function test_a_request_already_decided_cannot_be_decided_again(): void
    {
        $id = $this->existing('approved');

        $this->asAdmin()->postJson('/v1/breaks/reject', ['break_id' => $id])
            ->assertStatus(409)->assertJsonPath('error_code', 'not_pending');
    }

    public function test_a_manager_records_a_permission_for_somebody(): void
    {
        $this->asAdmin()->postJson('/v1/breaks', [
            'employee_id' => $this->employeeId,
            'date' => $this->future(),
            'start_time' => '09:00',
            'end_time' => '10:00',
            'type' => 'مهمة عمل',
        ])->assertOk();

        $this->assertDatabaseHas('break_requests', [
            'employee_id' => $this->employeeId,
            'type' => 'مهمة عمل',
            'duration_minutes' => 60,
        ]);
    }

    public function test_recording_for_an_unknown_employee_is_refused(): void
    {
        $this->asAdmin()->postJson('/v1/breaks', [
            'employee_id' => 9999999,
            'date' => $this->future(),
            'start_time' => '09:00',
            'end_time' => '10:00',
        ])->assertNotFound()->assertJsonPath('error_code', 'employee_not_found');
    }

    public function test_the_management_list_carries_the_names_behind_the_ids(): void
    {
        $this->existing();

        $this->asAdmin()->getJson('/v1/breaks?branch_id='.$this->branchId)
            ->assertOk()
            ->assertJsonPath('data.breaks.0.employee_name', 'Break asker');
    }

    public function test_deciding_needs_the_leave_permission(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/v1/breaks')
            ->assertForbidden();
    }

    // ── Offering another time ────────────────────────────────────────────

    public function test_a_manager_offers_a_different_time(): void
    {
        $id = $this->existing();

        $this->asAdmin()->postJson('/v1/breaks/postpone', [
            'break_id' => $id,
            'suggested_date' => $this->future(5),
            'suggested_start_time' => '14:00',
            'suggested_end_time' => '15:00',
            'note' => 'Busy that morning',
        ])->assertOk();

        $this->assertDatabaseHas('break_requests', [
            'id' => $id,
            'status' => 'postponed',
            'suggested_start_time' => '14:00:00',
        ]);
    }

    public function test_accepting_the_offer_adopts_it_and_approves_in_one_step(): void
    {
        // The manager already agreed to that slot by offering it; asking them
        // again would be a round trip nobody needs.
        $id = $this->existing('postponed', [
            'suggested_date' => $this->future(5),
            'suggested_start_time' => '14:00:00',
            'suggested_end_time' => '15:00:00',
        ]);

        $this->asEmployee()->postJson('/v1/breaks/respond-postpone', [
            'break_id' => $id,
            'action' => 'accept',
        ])->assertOk()->assertJsonPath('data.status', 'approved');

        $this->assertDatabaseHas('break_requests', [
            'id' => $id,
            'status' => 'approved',
            'date' => $this->future(5),
            'start_time' => '14:00:00',
            'duration_minutes' => 60,
            // Once adopted the suggestion is the request, not a proposal.
            'suggested_date' => null,
        ]);
    }

    public function test_declining_the_offer_ends_the_request(): void
    {
        $id = $this->existing('postponed', [
            'suggested_date' => $this->future(5),
            'suggested_start_time' => '14:00:00',
            'suggested_end_time' => '15:00:00',
        ]);

        $this->asEmployee()->postJson('/v1/breaks/respond-postpone', [
            'break_id' => $id,
            'action' => 'reject',
        ])->assertOk()->assertJsonPath('data.status', 'cancelled');

        $this->assertDatabaseHas('break_requests', ['id' => $id, 'status' => 'cancelled']);
    }

    public function test_an_offer_whose_window_has_since_closed_cannot_be_accepted(): void
    {
        $id = $this->existing('postponed', [
            'suggested_date' => '2020-01-01',
            'suggested_start_time' => '14:00:00',
            'suggested_end_time' => '15:00:00',
        ]);

        $this->asEmployee()->postJson('/v1/breaks/respond-postpone', [
            'break_id' => $id,
            'action' => 'accept',
        ])->assertStatus(422)->assertJsonPath('error_code', 'break_window_passed');
    }

    public function test_there_is_nothing_to_respond_to_on_a_request_that_was_not_postponed(): void
    {
        $id = $this->existing();

        $this->asEmployee()->postJson('/v1/breaks/respond-postpone', [
            'break_id' => $id,
            'action' => 'accept',
        ])->assertStatus(409)->assertJsonPath('error_code', 'not_postponed');
    }

    public function test_an_incomplete_offer_cannot_be_accepted(): void
    {
        $id = $this->existing('postponed', ['suggested_date' => $this->future(5)]);

        $this->asEmployee()->postJson('/v1/breaks/respond-postpone', [
            'break_id' => $id,
            'action' => 'accept',
        ])->assertStatus(422)->assertJsonPath('error_code', 'no_suggestion');
    }

    public function test_the_maximum_duration_is_what_the_domain_says(): void
    {
        $this->assertSame(480, BreakRequests::MAX_DURATION_MINUTES);
    }
}
