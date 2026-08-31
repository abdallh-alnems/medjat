<?php

declare(strict_types=1);

namespace Tests\Feature\Adjustments;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\CreatesFixtures;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * A bonus or deduction applied across a group, tracked as a batch.
 */
final class BulkAdjustmentTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    private const MONTH = '2026-04';

    private int $tenantId;

    private int $branchId;

    private int $otherBranchId;

    /** @var list<int> */
    private array $branchStaff = [];

    private int $elsewhere;

    private string $adminToken;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = $this->createTenant();

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Bulk branch', 'is_active' => 1,
        ]);
        $this->otherBranchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Untouched branch', 'is_active' => 1,
        ]);

        foreach ([4000.0, 6000.0] as $salary) {
            $this->branchStaff[] = $this->employee($this->branchId, $salary);
        }
        $this->elsewhere = $this->employee($this->otherBranchId, 5000.0);

        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Payroll manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);
        $this->adminToken = $firebase->issue($uid);
    }

    private function employee(int $branchId, float $salary, string $status = 'active'): int
    {
        return (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $branchId,
            'name' => 'Staff '.bin2hex(random_bytes(3)),
            'status' => $status,
            'base_salary' => $salary,
            'hire_date' => '2021-01-01',
        ]);
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function send(string $path, array $payload = []): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $this->adminToken)->postJson($path, $payload);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function apply(array $overrides = []): TestResponse
    {
        return $this->send('/v1/bulk-adjustments', $overrides + [
            'kind' => 'bonus',
            'scope_type' => 'branch',
            'scope_id' => $this->branchId,
            'amount' => 500,
            'amount_type' => 'fixed',
            'reason' => 'Ramadan bonus',
            'month' => self::MONTH,
        ]);
    }

    /** Only the batches this test wrote: the dump ships with its own. */
    private function batchCount(): int
    {
        return DB::table('bulk_adjustments')
            ->where('tenant_id', $this->tenantId)->where('month', self::MONTH)->count();
    }

    private function lockPayroll(int $employeeId, string $status = 'approved'): void
    {
        DB::table('payroll')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $employeeId,
            'month' => self::MONTH,
            'base_salary' => 4000,
            'total_deductions' => 0,
            'total_bonuses' => 0,
            'net_salary' => 4000,
            'status' => $status,
        ]);
    }

    public function test_a_batch_fans_out_into_ordinary_per_employee_rows(): void
    {
        $response = $this->apply()->assertOk()->assertJsonPath('data.count', 2);
        $batchId = Value::int($response->json('data.id'));

        // Everything downstream — the calculator, the payslips, the audit trail
        // — sees what it would see from lines typed one at a time.
        $rows = DB::table('manual_bonuses')->where('batch_id', $batchId)->get();
        $this->assertCount(2, $rows);
        $this->assertEqualsCanonicalizing(
            $this->branchStaff,
            $rows->pluck('employee_id')->map(static fn (mixed $id): int => Value::int($id))->all(),
        );
        $this->assertSame('500.00', Value::string($rows->first()?->amount));
    }

    public function test_the_scope_is_respected(): void
    {
        $this->apply()->assertOk();

        $this->assertSame(0, DB::table('manual_bonuses')->where('employee_id', $this->elsewhere)->count());
    }

    public function test_the_scopes_name_is_snapshotted_so_it_still_reads_after_a_rename(): void
    {
        $batchId = Value::int($this->apply()->json('data.id'));

        DB::table('branches')->where('id', $this->branchId)->update(['name' => 'Renamed since']);

        $this->assertDatabaseHas('bulk_adjustments', ['id' => $batchId, 'scope_name' => 'Bulk branch']);
    }

    public function test_a_percentage_is_resolved_against_each_persons_own_salary(): void
    {
        $this->apply(['amount' => 10, 'amount_type' => 'percent'])->assertOk();

        $this->assertDatabaseHas('manual_bonuses', [
            'employee_id' => $this->branchStaff[0], 'amount' => 400.00,
        ]);
        $this->assertDatabaseHas('manual_bonuses', [
            'employee_id' => $this->branchStaff[1], 'amount' => 600.00,
        ]);
    }

    public function test_a_percentage_line_records_the_basis_it_was_worked_out_from(): void
    {
        $this->apply(['amount' => 12.5, 'amount_type' => 'percent'])->assertOk();

        $reason = Value::string(DB::table('manual_bonuses')
            ->where('employee_id', $this->branchStaff[0])->value('reason'));

        // The trail has to explain itself: "500" alone does not say why.
        $this->assertSame('Ramadan bonus (12.5% من الأساسي)', $reason);
    }

    public function test_somebody_whose_month_is_already_frozen_is_skipped(): void
    {
        $this->lockPayroll($this->branchStaff[0]);

        // A manual line cannot change an approved slip, so writing one would be
        // a row that silently does nothing.
        $this->apply()
            ->assertOk()
            ->assertJsonPath('data.count', 1)
            ->assertJsonPath('data.locked', 1);

        $this->assertSame(0, DB::table('manual_bonuses')
            ->where('employee_id', $this->branchStaff[0])->count());
    }

    public function test_a_percentage_of_no_salary_is_skipped_rather_than_written_as_zero(): void
    {
        $unpaid = $this->employee($this->branchId, 0.0);

        $this->apply(['amount' => 10, 'amount_type' => 'percent'])
            ->assertOk()
            ->assertJsonPath('data.count', 2)
            ->assertJsonPath('data.skipped', 1);

        $this->assertSame(0, DB::table('manual_bonuses')->where('employee_id', $unpaid)->count());
    }

    public function test_a_dry_run_reports_what_would_happen_and_writes_nothing(): void
    {
        $this->lockPayroll($this->branchStaff[0]);

        $this->apply(['dry_run' => true])
            ->assertOk()
            ->assertJsonPath('data.dry_run', true)
            ->assertJsonPath('data.affected_count', 2)
            ->assertJsonPath('data.eligible_count', 1)
            ->assertJsonPath('data.locked_count', 1)
            ->assertJsonPath('data.month', self::MONTH);

        // A bulk mistake is expensive and invisible until somebody reads their
        // payslip.
        $this->assertSame(0, $this->batchCount());
        $this->assertSame(0, DB::table('manual_bonuses')
            ->whereIn('employee_id', $this->branchStaff)->count());
    }

    public function test_a_repeat_of_the_same_batch_is_flagged_but_not_refused(): void
    {
        $this->apply()->assertOk();

        // Applying the same bonus twice is occasionally deliberate, and the
        // only person who knows is the one pressing the button.
        $this->apply(['dry_run' => true])->assertOk()->assertJsonPath('data.duplicate', true);
        $this->apply()->assertOk();

        $this->assertSame(2, $this->batchCount());
    }

    public function test_a_batch_where_everybody_is_frozen_is_refused_rather_than_recorded_empty(): void
    {
        foreach ($this->branchStaff as $employeeId) {
            $this->lockPayroll($employeeId, 'paid');
        }

        $this->apply()->assertStatus(409);

        $this->assertSame(0, $this->batchCount());
    }

    public function test_a_scope_matching_nobody_is_refused(): void
    {
        $emptyBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Nobody here', 'is_active' => 1,
        ]);

        $this->apply(['scope_id' => $emptyBranch])->assertStatus(404);
    }

    public function test_a_scope_belonging_to_another_company_is_refused(): void
    {
        $otherTenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Other company', 'timezone' => 'Africa/Cairo', 'is_active' => 1,
        ]);
        $foreignBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $otherTenant, 'name' => 'Theirs', 'is_active' => 1,
        ]);

        $this->apply(['scope_id' => $foreignBranch])->assertStatus(404);
    }

    public function test_a_scope_other_than_all_needs_a_target(): void
    {
        $this->apply(['scope_id' => 0])->assertStatus(422);
    }

    public function test_a_percentage_over_a_hundred_is_refused(): void
    {
        $this->apply(['amount' => 150, 'amount_type' => 'percent'])->assertStatus(422);
    }

    public function test_a_malformed_month_is_refused(): void
    {
        $this->apply(['month' => 'April'])->assertStatus(422);
    }

    public function test_the_batch_and_its_members_can_be_read_back(): void
    {
        $batchId = Value::int($this->apply()->json('data.id'));

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/bulk-adjustments/get?id='.$batchId)
            ->assertOk()
            ->assertJsonPath('data.batch.kind', 'bonus')
            ->assertJsonPath('data.batch.scope_name', 'Bulk branch')
            ->assertJsonCount(2, 'data.members');
    }

    public function test_the_list_totals_each_batch(): void
    {
        $this->apply()->assertOk();

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/bulk-adjustments')
            ->assertOk()
            ->assertJsonPath('data.items.0.member_count', 2)
            ->assertJsonPath('data.items.0.total_amount', '1000.00');
    }

    public function test_editing_a_batch_re_resolves_every_line_it_owns(): void
    {
        $batchId = Value::int($this->apply()->json('data.id'));

        $this->send('/v1/bulk-adjustments/update', [
            'id' => $batchId,
            'amount' => 750,
            'amount_type' => 'fixed',
            'reason' => 'Increased',
        ])->assertOk()->assertJsonPath('data.updated', 2);

        $this->assertSame(2, DB::table('manual_bonuses')
            ->where('batch_id', $batchId)->where('amount', 750.00)->count());
        $this->assertDatabaseHas('bulk_adjustments', ['id' => $batchId, 'amount' => 750.00]);
    }

    public function test_a_percentage_edit_uses_the_salary_as_it_stands_now(): void
    {
        $batchId = Value::int($this->apply(['amount' => 10, 'amount_type' => 'percent'])->json('data.id'));

        // A raise between the two edits should be reflected, not frozen at what
        // the original run happened to compute.
        DB::table('employees')->where('id', $this->branchStaff[0])->update(['base_salary' => 8000]);

        $this->send('/v1/bulk-adjustments/update', [
            'id' => $batchId,
            'amount' => 10,
            'amount_type' => 'percent',
            'reason' => 'Ramadan bonus',
        ])->assertOk();

        $this->assertDatabaseHas('manual_bonuses', [
            'batch_id' => $batchId, 'employee_id' => $this->branchStaff[0], 'amount' => 800.00,
        ]);
    }

    public function test_deleting_a_batch_takes_its_lines_with_it(): void
    {
        $batchId = Value::int($this->apply()->json('data.id'));

        $this->send('/v1/bulk-adjustments/delete', ['id' => $batchId])
            ->assertOk()
            ->assertJsonPath('data.removed', 2);

        $this->assertDatabaseMissing('bulk_adjustments', ['id' => $batchId]);
        $this->assertSame(0, DB::table('manual_bonuses')->where('batch_id', $batchId)->count());
    }

    public function test_the_people_affected_are_told_when_a_batch_is_withdrawn(): void
    {
        $batchId = Value::int($this->apply()->json('data.id'));
        DB::table('notifications')->where('tenant_id', $this->tenantId)->delete();

        $this->send('/v1/bulk-adjustments/delete', ['id' => $batchId])->assertOk();

        $this->assertSame(2, DB::table('notifications')
            ->where('tenant_id', $this->tenantId)
            ->whereIn('employee_id', $this->branchStaff)
            ->count());
    }

    public function test_one_person_can_be_taken_out_leaving_the_rest_intact(): void
    {
        $batchId = Value::int($this->apply()->json('data.id'));
        $rowId = Value::int(DB::table('manual_bonuses')
            ->where('batch_id', $batchId)->where('employee_id', $this->branchStaff[0])->value('id'));

        $this->send('/v1/bulk-adjustments/remove-member', ['id' => $batchId, 'row_id' => $rowId])
            ->assertOk();

        $this->assertDatabaseMissing('manual_bonuses', ['id' => $rowId]);
        $this->assertSame(1, DB::table('manual_bonuses')->where('batch_id', $batchId)->count());
        $this->assertDatabaseHas('bulk_adjustments', ['id' => $batchId]);
    }

    public function test_a_row_from_a_different_batch_cannot_be_removed_through_this_one(): void
    {
        $first = Value::int($this->apply()->json('data.id'));
        $second = Value::int($this->apply(['reason' => 'Second batch'])->json('data.id'));

        $foreignRow = Value::int(DB::table('manual_bonuses')->where('batch_id', $second)->value('id'));

        $this->send('/v1/bulk-adjustments/remove-member', ['id' => $first, 'row_id' => $foreignRow])
            ->assertStatus(404);

        $this->assertDatabaseHas('manual_bonuses', ['id' => $foreignRow]);
    }

    public function test_another_companys_batch_is_out_of_reach(): void
    {
        $otherTenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Other company', 'timezone' => 'Africa/Cairo', 'is_active' => 1,
        ]);
        $foreign = (int) DB::table('bulk_adjustments')->insertGetId([
            'tenant_id' => $otherTenant,
            'kind' => 'deduction',
            'scope_type' => 'all',
            'amount' => 100,
            'amount_type' => 'fixed',
            'reason' => 'Theirs',
            'month' => self::MONTH,
        ]);

        $this->send('/v1/bulk-adjustments/delete', ['id' => $foreign])->assertStatus(404);
        $this->assertDatabaseHas('bulk_adjustments', ['id' => $foreign]);
    }

    public function test_terminated_staff_are_left_out_of_a_company_wide_batch(): void
    {
        // Neither is being paid this month, so the row would sit unpaid forever.
        $this->employee($this->branchId, 3000.0, 'terminated');
        $before = DB::table('employees')->where('tenant_id', $this->tenantId)
            ->whereNotIn('status', ['terminated', 'suspended'])->count();

        $batchId = Value::int($this->apply(['scope_type' => 'all', 'scope_id' => 0])->json('data.id'));

        $this->assertSame($before, DB::table('manual_bonuses')->where('batch_id', $batchId)->count());
    }
}
