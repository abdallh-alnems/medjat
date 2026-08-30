<?php

declare(strict_types=1);

namespace Tests\Feature\Shifts;

use App\Domain\Notifications\PushSender;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Named working hours, and what happens to the people on them.
 */
final class ShiftTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private int $employeeId;

    private string $adminToken;

    private string $viewerToken;

    private string $attendanceToken;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Shift branch',
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Shift worker',
            'status' => 'active',
            'base_salary' => 3000,
            'branch_id' => $this->branchId,
            'work_start_time' => '09:00:00',
            'work_end_time' => '17:00:00',
        ]);

        $this->adminToken = $this->admin($firebase, 'general_manager');
        $this->attendanceToken = $this->admin($firebase, 'attendance');
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

    private function asAdmin(): self
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken);

        return $this;
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function created(array $overrides = []): int
    {
        $response = $this->asAdmin()->postJson('/app/shifts/create.php', $overrides + [
            'name' => 'Morning',
            'start_time' => '08:00:00',
            'end_time' => '16:00:00',
        ])->assertStatus(201);

        return Value::int($response->json('data.id'));
    }

    public function test_a_shift_is_created_and_listed_with_its_headcount(): void
    {
        $id = $this->created();
        DB::table('employees')->where('id', $this->employeeId)->update(['shift_id' => $id]);

        $items = $this->asAdmin()->getJson('/app/shifts/list.php')->assertOk()->json('data.items');
        $this->assertIsArray($items);

        foreach ($items as $shift) {
            if (is_array($shift) && Value::int($shift['id']) === $id) {
                $this->assertSame('Morning', $shift['name']);
                $this->assertSame(1, Value::int($shift['employee_count']));
            }
        }
    }

    public function test_a_shift_without_hours_is_refused(): void
    {
        $this->asAdmin()->postJson('/app/shifts/create.php', ['name' => 'Nameless'])
            ->assertStatus(422)->assertJsonPath('error_code', 'name_start_time_end_time');
    }

    public function test_a_branch_filter_still_returns_the_company_wide_shifts(): void
    {
        // A shift with no branch applies everywhere; hiding it would make the
        // branch look as if it had none.
        $companyWide = $this->created(['name' => 'Everywhere']);
        $branchOnly = $this->created(['name' => 'Here only', 'branch_id' => $this->branchId]);

        $items = $this->asAdmin()->getJson('/app/shifts/list.php?branch_id='.$this->branchId)
            ->assertOk()->json('data.items');

        $this->assertIsArray($items);
        $ids = array_map(static fn (mixed $s): int => is_array($s) ? Value::int($s['id']) : 0, $items);

        $this->assertContains($companyWide, $ids);
        $this->assertContains($branchOnly, $ids);
    }

    public function test_the_list_is_readable_by_the_roles_that_filter_by_it(): void
    {
        // Gating it on the permission that manages shifts left HR, branch
        // managers and viewers with a silently empty list.
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/app/shifts/list.php')->assertOk();

        $this->withHeader('X-Firebase-Token', $this->attendanceToken)
            ->getJson('/app/shifts/list.php')->assertOk();
    }

    public function test_managing_shifts_stays_restricted(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->postJson('/app/shifts/create.php', [
                'name' => 'Nope', 'start_time' => '08:00', 'end_time' => '16:00',
            ])->assertForbidden();
    }

    public function test_people_are_put_on_a_shift_and_taken_off_it(): void
    {
        $id = $this->created();

        $this->asAdmin()->postJson('/app/shifts/assign.php', [
            'shift_id' => $id,
            'employee_ids' => [$this->employeeId],
        ])->assertOk()->assertJsonPath('data.assigned', 1);

        $this->assertDatabaseHas('employees', ['id' => $this->employeeId, 'shift_id' => $id]);

        $this->asAdmin()->postJson('/app/shifts/unassign.php', [
            'shift_id' => $id,
            'employee_ids' => [$this->employeeId],
        ])->assertOk()->assertJsonPath('data.unassigned', 1);

        $this->assertDatabaseHas('employees', ['id' => $this->employeeId, 'shift_id' => null]);
    }

    public function test_assigning_needs_somebody_to_assign(): void
    {
        $id = $this->created();

        $this->asAdmin()->postJson('/app/shifts/assign.php', ['shift_id' => $id, 'employee_ids' => []])
            ->assertStatus(422)->assertJsonPath('error_code', 'shift_id_employee_ids_array');
    }

    // ── Deleting, without changing anybody's hours ───────────────────────

    public function test_deleting_without_a_target_writes_the_hours_onto_the_people(): void
    {
        // Their day is unchanged after the shift is gone.
        $id = $this->created(['start_time' => '07:00:00', 'end_time' => '15:00:00']);
        DB::table('employees')->where('id', $this->employeeId)->update(['shift_id' => $id]);

        $this->asAdmin()->postJson('/app/shifts/delete.php', ['id' => $id])
            ->assertOk()
            ->assertJsonPath('data.action', 'kept_times')
            ->assertJsonPath('data.affected', 1);

        $this->assertDatabaseHas('employees', [
            'id' => $this->employeeId,
            'work_start_time' => '07:00:00',
            'work_end_time' => '15:00:00',
        ]);
        $this->assertDatabaseMissing('shifts', ['id' => $id]);
    }

    public function test_deleting_with_a_target_moves_everybody_onto_it(): void
    {
        $from = $this->created(['name' => 'Going']);
        $to = $this->created(['name' => 'Staying']);
        DB::table('employees')->where('id', $this->employeeId)->update(['shift_id' => $from]);

        $this->asAdmin()->postJson('/app/shifts/delete.php', [
            'id' => $from,
            'transfer_to_shift_id' => $to,
        ])->assertOk()->assertJsonPath('data.action', 'transferred');

        $this->assertDatabaseHas('employees', ['id' => $this->employeeId, 'shift_id' => $to]);
    }

    public function test_a_roster_follows_the_transfer(): void
    {
        // Scheduled days must keep pointing at a shift that still exists.
        $from = $this->created(['name' => 'Going']);
        $to = $this->created(['name' => 'Staying']);

        DB::table('employee_shift_schedule')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'shift_id' => $from,
            'work_date' => '2026-12-01',
            'status' => 'published',
        ]);

        $this->asAdmin()->postJson('/app/shifts/delete.php', [
            'id' => $from,
            'transfer_to_shift_id' => $to,
        ])->assertOk()->assertJsonPath('data.schedule_moved', 1);

        $this->assertDatabaseHas('employee_shift_schedule', [
            'employee_id' => $this->employeeId,
            'work_date' => '2026-12-01',
            'shift_id' => $to,
        ]);
    }

    public function test_a_shift_cannot_be_transferred_to_itself(): void
    {
        $id = $this->created();

        $this->asAdmin()->postJson('/app/shifts/delete.php', [
            'id' => $id,
            'transfer_to_shift_id' => $id,
        ])->assertStatus(422)->assertJsonPath('error_code', 'cannot_transfer_employees_shift_being');
    }

    public function test_an_unknown_target_shift_is_refused(): void
    {
        $id = $this->created();

        $this->asAdmin()->postJson('/app/shifts/delete.php', [
            'id' => $id,
            'transfer_to_shift_id' => 9999999,
        ])->assertStatus(422)->assertJsonPath('error_code', 'target_shift_not_found');
    }

    public function test_a_shift_from_another_company_is_not_found(): void
    {
        $otherTenant = Value::int(DB::table('tenants')->where('id', '!=', $this->tenantId)->value('id'));
        $stranger = (int) DB::table('shifts')->insertGetId([
            'tenant_id' => $otherTenant,
            'name' => 'Elsewhere',
            'start_time' => '08:00:00',
            'end_time' => '16:00:00',
        ]);

        $this->asAdmin()->postJson('/app/shifts/update.php', ['id' => $stranger, 'name' => 'Mine now'])
            ->assertNotFound();
    }
}
