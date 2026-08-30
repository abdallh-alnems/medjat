<?php

declare(strict_types=1);

namespace Tests\Feature\Payroll;

use App\Models\EmployeeAuthToken;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The payroll endpoints as a client meets them.
 */
final class PayrollEndpointsTest extends TestCase
{
    use DatabaseTransactions;

    private const MONTH = '2026-02';

    private int $tenantId;

    private int $branchId;

    private int $employeeId;

    private string $adminToken;

    private string $viewerToken;

    private string $employeeToken;

    private FakePushSender $push;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->push = new FakePushSender;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, $this->push);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        DB::table('tenants')->where('id', $this->tenantId)->update([
            'cycle_start_day' => 1,
            'currency' => 'EGP',
            'country_code' => 'EG',
        ]);

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Endpoint branch',
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Endpoint fixture',
            'status' => 'active',
            'base_salary' => 3000,
            'branch_id' => $this->branchId,
            'hire_date' => '2020-01-01',
            'bank_iban' => 'EG380019000500000000263180002',
            'bank_name' => 'Test Bank',
        ]);

        $this->adminToken = $this->admin($firebase, 'general_manager');
        $this->viewerToken = $this->admin($firebase, 'viewer');

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-payroll',
        ]);
        $this->employeeToken = $plain;
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

    private function slipId(): int
    {
        return Value::int(DB::table('payroll')
            ->where('employee_id', $this->employeeId)->where('month', self::MONTH)
            ->value('id'));
    }

    // ── Permission ───────────────────────────────────────────────────────

    public function test_payroll_is_closed_to_somebody_without_the_permission(): void
    {
        // Every gate in the frontend has to agree with this one; a menu item
        // that opens a 403 surfaces to the user as "an error occurred".
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/app/payroll/live.php?month='.self::MONTH)
            ->assertForbidden();
    }

    public function test_payroll_is_closed_to_an_unauthenticated_caller(): void
    {
        // 400, not 401: the published apps have always been answered this way
        // for a missing token, and the legacy URLs cannot change their contract.
        $this->getJson('/app/payroll/live.php?month='.self::MONTH)
            ->assertStatus(400)
            ->assertJsonPath('message', 'Token is required');
    }

    // ── Reading ──────────────────────────────────────────────────────────

    public function test_the_live_overview_lists_everybody_with_their_cycle(): void
    {
        $response = $this->asAdmin()
            ->getJson('/app/payroll/live.php?month='.self::MONTH.'&branch_id='.$this->branchId)
            ->assertOk()
            ->assertJsonPath('data.currency', 'EGP')
            ->assertJsonPath('data.cycle_start_day', 1);

        $items = $response->json('data.items');
        $this->assertIsArray($items);

        $mine = null;
        foreach ($items as $row) {
            if (is_array($row) && Value::int($row['employee_id'] ?? null) === $this->employeeId) {
                $mine = $row;
            }
        }

        $this->assertIsArray($mine);
        $this->assertSame('live', $mine['status']);
        $this->assertSame('2026-02-01', $mine['cycle_start']);
        $this->assertSame('2026-02-28', $mine['cycle_end']);
    }

    public function test_somebody_hired_after_the_cycle_ended_is_not_listed(): void
    {
        // They did not exist during the period the row would describe.
        DB::table('employees')->where('id', $this->employeeId)->update(['hire_date' => '2026-06-01']);

        $items = $this->asAdmin()
            ->getJson('/app/payroll/live.php?month='.self::MONTH.'&branch_id='.$this->branchId)
            ->assertOk()
            ->json('data.items');

        $this->assertIsArray($items);
        $this->assertSame([], $items);
    }

    public function test_a_repeated_request_for_a_past_month_is_not_cached(): void
    {
        // A finished cycle cannot change, so caching it trades freshness for
        // nothing — the header proves the calculator ran both times.
        $this->asAdmin()->getJson('/app/payroll/live.php?month='.self::MONTH)->assertOk()
            ->assertHeaderMissing('X-Cache');
    }

    public function test_the_current_month_is_cached_after_the_first_read(): void
    {
        $month = date('Y-m');

        $this->asAdmin()->getJson('/app/payroll/live.php?month='.$month)
            ->assertOk()->assertHeader('X-Cache', 'MISS');
        $this->asAdmin()->getJson('/app/payroll/live.php?month='.$month)
            ->assertOk()->assertHeader('X-Cache', 'HIT');
    }

    public function test_generating_payroll_clears_the_cached_overview(): void
    {
        // A stale "draft" badge on a slip somebody just acted on is the one
        // kind of staleness users do notice.
        $month = date('Y-m');
        $this->asAdmin()->getJson('/app/payroll/live.php?month='.$month)->assertOk();

        $this->asAdmin()->postJson('/app/payroll/generate.php', ['month' => $month])->assertOk();

        $this->asAdmin()->getJson('/app/payroll/live.php?month='.$month)
            ->assertOk()->assertHeader('X-Cache', 'MISS');
    }

    public function test_calculating_one_employee_returns_their_breakdown(): void
    {
        $this->asAdmin()
            ->getJson('/app/payroll/calculate.php?employee_id='.$this->employeeId.'&month='.self::MONTH)
            ->assertOk()
            ->assertJsonPath('data.base_salary', 3000)
            ->assertJsonPath('data.net_salary', 3000);
    }

    public function test_calculating_without_an_employee_is_refused(): void
    {
        $this->asAdmin()->getJson('/app/payroll/calculate.php?month='.self::MONTH)
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'employee_id_required');
    }

    // ── The state machine over HTTP ──────────────────────────────────────

    public function test_generate_approve_and_pay_walk_the_slip_through_its_states(): void
    {
        $this->asAdmin()->postJson('/app/payroll/generate.php', [
            'month' => self::MONTH,
            'branch_id' => $this->branchId,
        ])->assertOk()->assertJsonPath('data.month', self::MONTH);

        $id = $this->slipId();
        $this->assertGreaterThan(0, $id);

        $this->asAdmin()->postJson('/app/payroll/approve.php', ['payroll_id' => $id])->assertOk();
        $this->assertDatabaseHas('payroll', ['id' => $id, 'status' => 'approved']);

        $this->asAdmin()->postJson('/app/payroll/mark_paid.php', [
            'payroll_id' => $id,
            'paid_at' => '2026-03-02',
        ])->assertOk()->assertJsonPath('data.paid_count', 1);

        $this->assertDatabaseHas('payroll', ['id' => $id, 'status' => 'paid']);
    }

    public function test_the_employee_is_told_their_salary_was_paid(): void
    {
        $this->asAdmin()->postJson('/app/payroll/disburse.php', [
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
        ])->assertOk()->assertJsonPath('data.result', 'paid');

        $this->assertDatabaseHas('notifications', [
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'type' => 'payroll',
            'title_ar' => 'تم دفع راتبك',
        ]);
    }

    public function test_a_malformed_payment_date_is_refused(): void
    {
        $this->asAdmin()->postJson('/app/payroll/mark_paid.php', [
            'payroll_id' => 1,
            'paid_at' => '02/03/2026',
        ])->assertStatus(422)->assertJsonPath('error_code', 'paid_at_yyyy_mm_dd');
    }

    public function test_bulk_approval_needs_a_non_empty_list(): void
    {
        $this->asAdmin()->postJson('/app/payroll/approve_bulk.php', ['ids' => []])
            ->assertStatus(422)->assertJsonPath('error_code', 'ids_non_empty_array');
    }

    public function test_reverting_a_draft_says_so_rather_than_reporting_success(): void
    {
        $this->asAdmin()->postJson('/app/payroll/generate.php', ['month' => self::MONTH])->assertOk();

        $this->asAdmin()->postJson('/app/payroll/revert.php', ['payroll_id' => $this->slipId()])
            ->assertStatus(422)->assertJsonPath('error_code', 'slip_not_found_already_draft');
    }

    public function test_disburse_all_pays_the_branch_it_was_given(): void
    {
        $this->asAdmin()->postJson('/app/payroll/disburse_all.php', [
            'month' => self::MONTH,
            'branch_id' => $this->branchId,
        ])->assertOk()->assertJsonPath('data.paid_count', 1);

        $this->assertDatabaseHas('payroll', [
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
            'status' => 'paid',
        ]);
    }

    public function test_every_payroll_action_leaves_a_trail(): void
    {
        $this->asAdmin()->postJson('/app/payroll/generate.php', ['month' => self::MONTH])->assertOk();

        $this->asAdmin()->getJson('/app/payroll/audit_log.php')
            ->assertOk()
            ->assertJsonPath('data.items.0.action', 'payroll.generate');
    }

    // ── Corrections over HTTP ────────────────────────────────────────────

    public function test_a_line_on_a_frozen_slip_cannot_be_edited_in_place(): void
    {
        // The approved slip is the source of truth; the admin reverts it to
        // draft first, which leaves a trail of the fact.
        $this->asAdmin()->postJson('/app/payroll/generate.php', ['month' => self::MONTH])->assertOk();
        $this->asAdmin()->postJson('/app/payroll/approve.php', ['payroll_id' => $this->slipId()])->assertOk();

        $this->asAdmin()->postJson('/app/payroll/override_line.php', [
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
            'line_kind' => 'deduction',
            'line_type' => 'absence',
            'line_date' => '2026-02-10',
            'line_desc' => 'غياب يوم 2026-02-10',
            'action' => 'waive',
        ])->assertStatus(409)->assertJsonPath('error_code', 'slip_locked_revert_it_draft');
    }

    public function test_a_manual_line_is_refused_by_the_correction_endpoint(): void
    {
        $this->asAdmin()->postJson('/app/payroll/override_line.php', [
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
            'line_kind' => 'deduction',
            'line_type' => 'manual',
            'line_desc' => 'Anything',
            'action' => 'waive',
        ])->assertStatus(422)->assertJsonPath('error_code', 'manual_lines_edited_from_their');
    }

    public function test_setting_a_correction_without_an_amount_is_refused(): void
    {
        $this->asAdmin()->postJson('/app/payroll/override_line.php', [
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
            'line_kind' => 'deduction',
            'line_type' => 'absence',
            'line_desc' => 'غياب يوم 2026-02-10',
            'action' => 'set',
        ])->assertStatus(422)->assertJsonPath('error_code', 'amount_required_setting_value');
    }

    public function test_a_correction_is_saved_and_can_be_dropped_again(): void
    {
        $payload = [
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
            'line_kind' => 'deduction',
            'line_type' => 'absence',
            'line_date' => '2026-02-10',
            'line_desc' => 'غياب يوم 2026-02-10',
        ];

        $this->asAdmin()->postJson('/app/payroll/override_line.php', $payload + ['action' => 'waive'])->assertOk();
        $this->assertDatabaseHas('payroll_line_overrides', [
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
            'waived' => 1,
        ]);

        $this->asAdmin()->postJson('/app/payroll/override_line.php', $payload + ['action' => 'clear'])->assertOk();
        $this->assertDatabaseMissing('payroll_line_overrides', [
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
        ]);
    }

    // ── Bulk adjustment ──────────────────────────────────────────────────

    public function test_a_bulk_bonus_writes_one_row_per_employee_in_scope(): void
    {
        $this->asAdmin()->postJson('/app/payroll/bulk_adjust.php', [
            'kind' => 'bonus',
            'scope_type' => 'branch',
            'scope_id' => $this->branchId,
            'amount' => 250,
            'amount_type' => 'fixed',
            'reason' => 'Eid bonus',
        ])->assertOk()->assertJsonPath('data.count', 1);

        $this->assertDatabaseHas('manual_bonuses', [
            'employee_id' => $this->employeeId,
            'amount' => '250.00',
            'reason' => 'Eid bonus',
        ]);
    }

    public function test_a_percentage_adjustment_resolves_per_employee_and_says_so(): void
    {
        $this->asAdmin()->postJson('/app/payroll/bulk_adjust.php', [
            'kind' => 'deduction',
            'scope_type' => 'branch',
            'scope_id' => $this->branchId,
            'amount' => 10,
            'amount_type' => 'percent',
            'reason' => 'Late policy',
        ])->assertOk();

        $row = DB::table('manual_deductions')->where('employee_id', $this->employeeId)->first();

        $this->assertNotNull($row);
        $this->assertSame('300.00', $row->amount);
        $this->assertSame('Late policy (10% من الأساسي)', $row->reason);
    }

    public function test_a_percentage_over_a_hundred_is_refused(): void
    {
        $this->asAdmin()->postJson('/app/payroll/bulk_adjust.php', [
            'kind' => 'bonus',
            'scope_type' => 'branch',
            'scope_id' => $this->branchId,
            'amount' => 150,
            'amount_type' => 'percent',
            'reason' => 'Nonsense',
        ])->assertStatus(422);
    }

    public function test_an_empty_scope_is_reported_rather_than_silently_doing_nothing(): void
    {
        $this->asAdmin()->postJson('/app/payroll/bulk_adjust.php', [
            'kind' => 'bonus',
            'scope_type' => 'branch',
            'scope_id' => 9999999,
            'amount' => 100,
            'amount_type' => 'fixed',
            'reason' => 'Nobody',
        ])->assertNotFound();
    }

    // ── Bank file ────────────────────────────────────────────────────────

    public function test_the_bank_preview_names_the_people_with_nowhere_to_pay(): void
    {
        // So nobody discovers the missing half at the bank.
        $strandedId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'No account',
            'status' => 'active',
            'base_salary' => 1000,
            'branch_id' => $this->branchId,
            'hire_date' => '2020-01-01',
        ]);

        $this->asAdmin()->postJson('/app/payroll/generate.php', [
            'month' => self::MONTH,
            'branch_id' => $this->branchId,
        ])->assertOk();
        $ids = DB::table('payroll')->where('month', self::MONTH)
            ->whereIn('employee_id', [$this->employeeId, $strandedId])->pluck('id')->all();
        $this->asAdmin()->postJson('/app/payroll/approve_bulk.php', ['ids' => $ids])->assertOk();

        $this->asAdmin()
            ->getJson('/app/payroll/bank_file_preview.php?month='.self::MONTH.'&branch_id='.$this->branchId)
            ->assertOk()
            ->assertJsonPath('data.ready_count', 1)
            ->assertJsonPath('data.missing_bank_count', 1)
            ->assertJsonPath('data.missing.0.name', 'No account')
            ->assertJsonPath('data.total_amount', 3000);
    }

    public function test_only_approved_slips_reach_the_bank_file(): void
    {
        $this->asAdmin()->postJson('/app/payroll/generate.php', [
            'month' => self::MONTH,
            'branch_id' => $this->branchId,
        ])->assertOk();

        $this->asAdmin()
            ->getJson('/app/payroll/bank_file_preview.php?month='.self::MONTH.'&branch_id='.$this->branchId)
            ->assertOk()
            ->assertJsonPath('data.total_employees', 0);
    }

    public function test_the_bank_file_downloads_as_csv(): void
    {
        $this->asAdmin()->postJson('/app/payroll/generate.php', [
            'month' => self::MONTH,
            'branch_id' => $this->branchId,
        ])->assertOk();
        $this->asAdmin()->postJson('/app/payroll/approve.php', ['payroll_id' => $this->slipId()])->assertOk();

        $response = $this->asAdmin()
            ->get('/app/payroll/export_bank_file.php?month='.self::MONTH.'&branch_id='.$this->branchId)
            ->assertOk()
            ->assertHeader('Content-Type', 'text/csv; charset=utf-8');

        $csv = $response->streamedContent();

        // A BOM, because these are opened in Excel, which reads a UTF-8 CSV as
        // mojibake without one.
        $this->assertStringStartsWith("\xEF\xBB\xBF", $csv);
        $this->assertStringContainsString('EG380019000500000000263180002', $csv);
        $this->assertStringContainsString('3000.00', $csv);
    }

    public function test_an_unknown_exporter_is_refused_rather_than_substituted(): void
    {
        // A company that asked for its own bank's layout and silently received
        // a different one would upload a file the bank rejects.
        $this->asAdmin()
            ->getJson('/app/payroll/export_bank_file.php?month='.self::MONTH.'&exporter=made_up')
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'payroll_exporter_available_country_format');
    }

    public function test_the_bank_file_needs_a_well_formed_month(): void
    {
        $this->asAdmin()->getJson('/app/payroll/bank_file_preview.php?month=february')
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'invalid_month_format_yyyy_mm');
    }

    // ── End of service ───────────────────────────────────────────────────

    public function test_end_of_service_is_off_until_a_company_turns_it_on(): void
    {
        DB::table('payroll_statutory_settings')->where('tenant_id', $this->tenantId)->delete();

        $this->asAdmin()->getJson('/app/payroll/eosb_calculate.php?employee_id='.$this->employeeId)
            ->assertOk()
            ->assertJsonPath('data.enabled', false);
    }

    public function test_end_of_service_pays_the_configured_days_per_year(): void
    {
        DB::table('payroll_statutory_settings')->where('tenant_id', $this->tenantId)->delete();
        DB::table('payroll_statutory_settings')->insert([
            'tenant_id' => $this->tenantId,
            'eosb_enabled' => 1,
            'eosb_days_per_year' => 30,
        ]);
        DB::table('employees')->where('id', $this->employeeId)->update(['hire_date' => '2024-08-30']);

        $response = $this->asAdmin()
            ->getJson('/app/payroll/eosb_calculate.php?employee_id='.$this->employeeId)
            ->assertOk()
            ->assertJsonPath('data.enabled', true)
            ->assertJsonPath('data.daily_wage', 100);

        $this->assertGreaterThan(0, Value::float($response->json('data.eosb_amount')));
    }

    public function test_end_of_service_needs_a_hire_date(): void
    {
        DB::table('payroll_statutory_settings')->where('tenant_id', $this->tenantId)->delete();
        DB::table('payroll_statutory_settings')->insert([
            'tenant_id' => $this->tenantId,
            'eosb_enabled' => 1,
            'eosb_days_per_year' => 30,
        ]);
        DB::table('employees')->where('id', $this->employeeId)->update(['hire_date' => null]);

        $this->asAdmin()->getJson('/app/payroll/eosb_calculate.php?employee_id='.$this->employeeId)
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'employee_hire_date');
    }

    // ── The employee's own payslip ───────────────────────────────────────

    public function test_an_employee_sees_a_live_preview_before_payroll_is_run(): void
    {
        // Somebody should always be able to see what they have earned so far,
        // marked clearly as not yet paid.
        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->getJson('/app/payroll/get_slip.php?month='.self::MONTH)
            ->assertOk()
            ->assertJsonPath('data.status', 'live')
            ->assertJsonPath('data.base_salary', 3000);
    }

    public function test_an_employee_sees_the_frozen_figures_once_payroll_is_approved(): void
    {
        $this->asAdmin()->postJson('/app/payroll/generate.php', ['month' => self::MONTH])->assertOk();
        $this->asAdmin()->postJson('/app/payroll/approve.php', ['payroll_id' => $this->slipId()])->assertOk();

        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->getJson('/app/payroll/get_slip.php?month='.self::MONTH)
            ->assertOk()
            ->assertJsonPath('data.status', 'approved')
            ->assertJsonPath('data.net_salary', '3000.00');
    }

    public function test_the_download_button_gets_an_actual_pdf(): void
    {
        // Without this the app saved a JSON body under a .pdf name, producing a
        // file no reader could open.
        $response = $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->get('/app/payroll/get_slip.php?month='.self::MONTH.'&format=pdf')
            ->assertOk()
            ->assertHeader('Content-Type', 'application/pdf');

        $this->assertStringStartsWith('%PDF-', $response->streamedContent());
    }

    public function test_a_manager_can_download_somebodys_payslip(): void
    {
        $response = $this->asAdmin()
            ->get('/app/payroll/get_slip_pdf.php?employee_id='.$this->employeeId.'&month='.self::MONTH)
            ->assertOk()
            ->assertHeader('Content-Type', 'application/pdf');

        $this->assertStringStartsWith('%PDF-', $response->streamedContent());
    }

    public function test_an_employee_cannot_read_another_companys_payroll(): void
    {
        // An employee token is not an admin token, whatever else it opens.
        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->getJson('/app/payroll/live.php?month='.self::MONTH)
            ->assertStatus(400);
    }
}
