<?php

declare(strict_types=1);

namespace Tests\Feature\Loans;

use App\Models\EmployeeAuthToken;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Loans\Domain\Loans;
use App\Modules\Notifications\Domain\PushSender;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Loans and salary advances: asking, approving, and the schedule that repays
 * them.
 */
final class LoanTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

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

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Borrower',
            'status' => 'active',
            'base_salary' => 3000,
        ]);

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-loan',
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

    private function asAdmin(): self
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken);

        return $this;
    }

    private function asEmployee(): self
    {
        $this->withHeader('X-Employee-Token', $this->employeeToken);

        return $this;
    }

    private function thisMonth(): string
    {
        return substr(TenantClock::date($this->tenantId), 0, 7);
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function created(array $overrides = []): int
    {
        $response = $this->asAdmin()->postJson('/app/loans/create.php', $overrides + [
            'employee_id' => $this->employeeId,
            'type' => 'loan',
            'total_amount' => 1200,
            'installments_count' => 12,
            'start_month' => $this->thisMonth(),
        ])->assertOk();

        return Value::int($response->json('data.id'));
    }

    // ── Creating ─────────────────────────────────────────────────────────

    public function test_a_loan_is_created_pending(): void
    {
        $id = $this->created();

        $this->assertDatabaseHas('employee_loans', [
            'id' => $id,
            'employee_id' => $this->employeeId,
            'status' => 'pending',
            'installment_amount' => '100.00',
        ]);
    }

    public function test_no_installments_exist_until_somebody_approves(): void
    {
        // A request nobody has agreed to must not reach anybody's payroll.
        $id = $this->created();

        $this->assertSame(0, DB::table('loan_installments')->where('loan_id', $id)->count());
    }

    public function test_a_zero_amount_is_refused(): void
    {
        $this->asAdmin()->postJson('/app/loans/create.php', [
            'employee_id' => $this->employeeId,
            'total_amount' => 0,
            'installments_count' => 4,
        ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_total_amount');
    }

    public function test_a_malformed_start_month_is_refused(): void
    {
        $this->asAdmin()->postJson('/app/loans/create.php', [
            'employee_id' => $this->employeeId,
            'total_amount' => 100,
            'installments_count' => 1,
            'start_month' => 'August',
        ])->assertStatus(422)->assertJsonPath('error_code', 'start_month_yyyy_mm_format');
    }

    // ── Approving ────────────────────────────────────────────────────────

    public function test_approving_writes_the_whole_schedule(): void
    {
        $id = $this->created();

        $this->asAdmin()->postJson('/app/loans/approve.php', ['id' => $id])->assertOk();

        $this->assertDatabaseHas('employee_loans', ['id' => $id, 'status' => 'active']);
        $this->assertSame(12, DB::table('loan_installments')->where('loan_id', $id)->count());
        $this->assertSame(
            '1200.00',
            Value::string(DB::table('loan_installments')->where('loan_id', $id)
                ->selectRaw('SUM(amount) AS total')->value('total'))
        );
    }

    public function test_the_last_installment_absorbs_the_rounding(): void
    {
        // Dividing evenly and rounding each one would leave a company
        // collecting a few piastres more or less than it lent.
        $id = $this->created(['total_amount' => 100, 'installments_count' => 3]);

        $this->asAdmin()->postJson('/app/loans/approve.php', ['id' => $id])->assertOk();

        $amounts = DB::table('loan_installments')->where('loan_id', $id)->orderBy('seq')
            ->pluck('amount')->map(static fn (mixed $a): string => Value::string($a))->all();

        $this->assertSame(['33.33', '33.33', '33.34'], $amounts);
    }

    public function test_the_schedule_runs_month_by_month_from_the_start(): void
    {
        $id = $this->created(['total_amount' => 300, 'installments_count' => 3, 'start_month' => '2026-11']);

        $this->asAdmin()->postJson('/app/loans/approve.php', ['id' => $id])->assertOk();

        $months = DB::table('loan_installments')->where('loan_id', $id)->orderBy('seq')
            ->pluck('month')->map(static fn (mixed $m): string => Value::string($m))->all();

        $this->assertSame(['2026-11', '2026-12', '2027-01'], $months);
    }

    public function test_the_employee_is_told_it_was_approved(): void
    {
        $id = $this->created();

        $this->asAdmin()->postJson('/app/loans/approve.php', ['id' => $id])->assertOk();

        $this->assertDatabaseHas('notifications', [
            'employee_id' => $this->employeeId,
            'type' => 'payroll',
            'title_ar' => 'تمت الموافقة على القرض',
        ]);
    }

    public function test_an_advance_is_announced_as_an_advance(): void
    {
        $id = $this->created(['type' => 'advance']);

        $this->asAdmin()->postJson('/app/loans/approve.php', ['id' => $id])->assertOk();

        $this->assertDatabaseHas('notifications', [
            'employee_id' => $this->employeeId,
            'title_ar' => 'تمت الموافقة على السلفة',
        ]);
    }

    public function test_a_loan_cannot_be_approved_twice(): void
    {
        $id = $this->created();
        $this->asAdmin()->postJson('/app/loans/approve.php', ['id' => $id])->assertOk();

        $this->asAdmin()->postJson('/app/loans/approve.php', ['id' => $id])
            ->assertStatus(409)->assertJsonPath('error_code', 'only_pending_loans_can_approved');

        $this->assertSame(12, DB::table('loan_installments')->where('loan_id', $id)->count());
    }

    // ── Refusing and stopping ────────────────────────────────────────────

    public function test_a_pending_request_is_refused_not_cancelled(): void
    {
        // The employee's history should show a decision rather than a
        // withdrawal.
        $id = $this->created();

        $this->asAdmin()->postJson('/app/loans/cancel.php', ['id' => $id])->assertOk();

        $this->assertDatabaseHas('employee_loans', ['id' => $id, 'status' => 'rejected']);
        $this->assertDatabaseHas('notifications', [
            'employee_id' => $this->employeeId,
            'title_ar' => 'تم رفض طلب القرض',
        ]);
    }

    public function test_stopping_a_running_loan_drops_what_is_still_unpaid(): void
    {
        $id = $this->created(['total_amount' => 300, 'installments_count' => 3]);
        $this->asAdmin()->postJson('/app/loans/approve.php', ['id' => $id])->assertOk();

        DB::table('loan_installments')->where('loan_id', $id)->where('seq', 1)
            ->update(['status' => 'paid']);

        $this->asAdmin()->postJson('/app/loans/cancel.php', ['id' => $id])->assertOk();

        $this->assertDatabaseHas('employee_loans', ['id' => $id, 'status' => 'cancelled']);
        // What was actually deducted stays; what was not is gone.
        $this->assertSame(1, DB::table('loan_installments')->where('loan_id', $id)->count());
        $this->assertDatabaseHas('loan_installments', ['loan_id' => $id, 'seq' => 1, 'status' => 'paid']);
    }

    public function test_a_completed_loan_cannot_be_cancelled(): void
    {
        $id = $this->created();
        DB::table('employee_loans')->where('id', $id)->update(['status' => 'completed']);

        $this->asAdmin()->postJson('/app/loans/cancel.php', ['id' => $id])
            ->assertStatus(409)->assertJsonPath('error_code', 'loan_cannot_cancelled_its_current');
    }

    // ── Reading ──────────────────────────────────────────────────────────

    public function test_a_loan_reads_back_with_its_schedule(): void
    {
        $id = $this->created(['total_amount' => 200, 'installments_count' => 2]);
        $this->asAdmin()->postJson('/app/loans/approve.php', ['id' => $id])->assertOk();

        $this->asAdmin()->getJson('/app/loans/get.php?id='.$id)
            ->assertOk()
            ->assertJsonPath('data.loan.employee_name', 'Borrower')
            ->assertJsonCount(2, 'data.loan.installments');
    }

    public function test_the_list_can_be_narrowed_to_one_person(): void
    {
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Someone else',
            'status' => 'active',
            'base_salary' => 1000,
        ]);
        $this->created();
        $this->created(['employee_id' => $stranger]);

        $items = $this->asAdmin()->getJson('/app/loans/list.php?employee_id='.$this->employeeId)
            ->assertOk()->json('data.items');

        $this->assertIsArray($items);
        $this->assertCount(1, $items);
    }

    public function test_a_loan_from_another_company_is_not_found(): void
    {
        $otherTenant = Value::int(DB::table('tenants')->where('id', '!=', $this->tenantId)->value('id'));
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $otherTenant,
            'name' => 'Elsewhere',
            'status' => 'active',
            'base_salary' => 1000,
        ]);
        $id = (int) DB::table('employee_loans')->insertGetId([
            'tenant_id' => $otherTenant,
            'employee_id' => $stranger,
            'type' => 'loan',
            'total_amount' => 100,
            'installment_amount' => 100,
            'installments_count' => 1,
            'start_month' => '2026-01',
            'status' => 'pending',
        ]);

        $this->asAdmin()->getJson('/app/loans/get.php?id='.$id)->assertNotFound();
    }

    public function test_loans_are_closed_without_the_payroll_permission(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/app/loans/list.php')->assertForbidden();
    }

    // ── An employee asking ───────────────────────────────────────────────

    public function test_an_employee_asks_for_an_advance(): void
    {
        $this->asEmployee()->postJson('/app/loans/request.php', [
            'total_amount' => 500,
            'installments_count' => 5,
        ])->assertOk();

        $this->assertDatabaseHas('employee_loans', [
            'employee_id' => $this->employeeId,
            'type' => 'advance',
            'status' => 'pending',
            'installment_amount' => '100.00',
            // Requested by the employee, so there is no administrator to name.
            'created_by' => null,
        ]);
    }

    public function test_it_lands_in_the_same_queue_the_managers_already_watch(): void
    {
        $this->asEmployee()->postJson('/app/loans/request.php', ['total_amount' => 500])->assertOk();

        $items = $this->asAdmin()->getJson('/app/loans/list.php?status=pending')->assertOk()->json('data.items');

        $this->assertIsArray($items);
        $this->assertNotEmpty($items);
        $this->assertNotEmpty($this->push->sentToAdmins);
    }

    public function test_a_deduction_cannot_start_in_a_month_that_has_passed(): void
    {
        $this->asEmployee()->postJson('/app/loans/request.php', [
            'total_amount' => 500,
            'start_month' => '2020-01',
        ])->assertStatus(422)->assertJsonPath('error_code', 'start_month_in_past');
    }

    public function test_a_fourth_undecided_request_is_refused(): void
    {
        for ($i = 0; $i < Loans::PENDING_LIMIT; $i++) {
            $this->asEmployee()->postJson('/app/loans/request.php', ['total_amount' => 100])->assertOk();
        }

        $this->asEmployee()->postJson('/app/loans/request.php', ['total_amount' => 100])
            ->assertStatus(409)->assertJsonPath('error_code', 'advance_pending_limit');
    }

    public function test_an_employee_withdraws_their_own_undecided_request(): void
    {
        $response = $this->asEmployee()->postJson('/app/loans/request.php', ['total_amount' => 500])->assertOk();
        $id = Value::int($response->json('data.id'));

        $this->asEmployee()->postJson('/app/loans/cancel_request.php', ['loan_id' => $id])->assertOk();

        $this->assertDatabaseHas('employee_loans', ['id' => $id, 'status' => 'cancelled']);
    }

    public function test_an_approved_advance_cannot_be_withdrawn(): void
    {
        $response = $this->asEmployee()->postJson('/app/loans/request.php', ['total_amount' => 500])->assertOk();
        $id = Value::int($response->json('data.id'));
        $this->asAdmin()->postJson('/app/loans/approve.php', ['id' => $id])->assertOk();

        $this->asEmployee()->postJson('/app/loans/cancel_request.php', ['loan_id' => $id])
            ->assertStatus(409)->assertJsonPath('error_code', 'not_pending');
    }

    public function test_an_employee_cannot_withdraw_somebody_elses_request(): void
    {
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Someone else',
            'status' => 'active',
            'base_salary' => 1000,
        ]);
        $id = $this->created(['employee_id' => $stranger]);

        $this->asEmployee()->postJson('/app/loans/cancel_request.php', ['loan_id' => $id])->assertNotFound();
    }

    public function test_an_employee_sees_only_their_own(): void
    {
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Someone else',
            'status' => 'active',
            'base_salary' => 1000,
        ]);
        $this->created(['employee_id' => $stranger]);
        $this->asEmployee()->postJson('/app/loans/request.php', ['total_amount' => 500])->assertOk();

        $loans = $this->asEmployee()->getJson('/app/loans/my_list.php')->assertOk()->json('data.loans');

        $this->assertIsArray($loans);
        $this->assertCount(1, $loans);
    }
}
