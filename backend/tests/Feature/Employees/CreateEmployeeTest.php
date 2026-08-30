<?php

declare(strict_types=1);

namespace Tests\Feature\Employees;

use App\Models\ActivationCode;
use App\Models\Admin;
use App\Models\Employee;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * Adding somebody to a company, and editing them afterwards.
 */
final class CreateEmployeeTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private string $token;

    private Admin $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);

        $existing = Employee::query()->whereNotNull('branch_id')->firstOrFail();
        $this->tenantId = $existing->tenant_id;
        $this->branchId = (int) $existing->branch_id;

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
    }

    /**
     * @param  array<string, mixed>  $body
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function create(array $body = []): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/create.php', array_merge([
                'name' => 'New Hire',
                'branch_id' => $this->branchId,
                'base_salary' => 8000,
            ], $body));
    }

    public function test_a_new_employee_comes_back_with_a_code_and_a_link(): void
    {
        // Created without one is created for somebody to remember to go back to.
        $response = $this->create()
            ->assertStatus(201)
            ->assertJsonStructure(['data' => [
                'employee_id', 'activation_code', 'activation_token', 'join_link',
                'phone', 'activation_expires_in_hours',
            ]]);

        $code = $response->json('data.activation_code');
        $this->assertIsString($code);
        $this->assertSame(6, strlen($code));
        $this->assertNotNull(ActivationCode::findUsableByCode($code));
    }

    public function test_the_code_avoids_characters_that_are_read_wrong(): void
    {
        // It is read down a phone line and typed by somebody who has never seen
        // it written.
        for ($i = 0; $i < 5; $i++) {
            $code = $this->create()->json('data.activation_code');
            $this->assertIsString($code);
            $this->assertDoesNotMatchRegularExpression('/[01OI]/', $code);
        }
    }

    public function test_a_new_employee_starts_pending_rather_than_active(): void
    {
        // The record exists, but nobody has proved they hold the phone.
        $id = Value::int($this->create()->json('data.employee_id'));

        $this->assertDatabaseHas('employees', ['id' => $id, 'status' => 'pending_activation']);
    }

    public function test_the_join_link_points_at_the_configured_domain(): void
    {
        $link = $this->create()->json('data.join_link');

        $this->assertIsString($link);
        $this->assertStringStartsWith('https://', $link);
        $this->assertStringContainsString('/join?token=', $link);
    }

    public function test_a_name_and_a_branch_are_required(): void
    {
        $this->create(['name' => ''])->assertStatus(422)->assertJsonPath('error_code', 'missing_fields');
        $this->create(['branch_id' => 0])->assertStatus(422)->assertJsonPath('error_code', 'missing_fields');
    }

    public function test_a_phone_without_a_country_code_is_refused(): void
    {
        $this->create(['phone' => '01023809407'])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'invalid_phone_number');
    }

    public function test_a_fixed_term_contract_cannot_end_in_the_past(): void
    {
        // Otherwise the employee is created already finished.
        $this->create(['auto_terminate_at' => date('Y-m-d', strtotime('-1 day'))])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'auto_terminate_at_future_date');
    }

    public function test_a_contract_that_ends_before_it_starts_is_refused(): void
    {
        $this->create(['contract_start' => '2026-06-01', 'contract_end' => '2026-05-01'])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'contract_end_after_start_date');
    }

    public function test_unknown_weekly_off_days_are_dropped_rather_than_erroring(): void
    {
        // The column is a SET, so anything not in it fails at the database with
        // a message nobody can act on.
        $id = Value::int($this->create(['weekly_off_days' => ['friday', 'caturday']])->json('data.employee_id'));

        $this->assertSame('friday', DB::table('employees')->where('id', $id)->value('weekly_off_days'));
    }

    public function test_allowances_agreed_at_hiring_are_created(): void
    {
        $id = Value::int($this->create([
            'hire_date' => '2026-03-15',
            'allowances' => [
                ['type' => 'housing', 'amount' => 1500],
                ['type' => '', 'amount' => 0],
            ],
        ])->json('data.employee_id'));

        $this->assertDatabaseHas('employee_allowances', [
            'employee_id' => $id,
            'type' => 'housing',
            'start_month' => '2026-03',
        ]);

        // A blank row is skipped rather than refused, so the form can submit a
        // fixed set of optional fields.
        $this->assertSame(1, DB::table('employee_allowances')->where('employee_id', $id)->count());
    }

    public function test_an_allowance_ending_before_it_starts_is_refused(): void
    {
        $this->create(['allowances' => [
            ['type' => 'housing', 'amount' => 100, 'start_month' => '2026-06', 'end_month' => '2026-01'],
        ]])->assertStatus(422)->assertJsonPath('error_code', 'allowance_end_month_cannot_before');
    }

    public function test_a_requested_document_is_asked_of_this_person_only(): void
    {
        // Asking one new hire for a certificate must not put it on everybody's
        // checklist.
        $id = Value::int($this->create([
            'requested_documents' => [['name' => 'Food handling certificate']],
        ])->json('data.employee_id'));

        $required = DB::table('required_documents')
            ->where('tenant_id', $this->tenantId)
            ->where('name', 'Food handling certificate')
            ->first();

        $this->assertNotNull($required);
        $this->assertSame('employees', $required->scope_type);
        $this->assertDatabaseHas('required_document_employees', [
            'required_document_id' => $required->id,
            'employee_id' => $id,
        ]);
    }

    public function test_creation_is_audited(): void
    {
        $this->create()->assertStatus(201);

        $this->assertDatabaseHas('audit_log', [
            'admin_id' => $this->admin->id,
            'action' => 'employee.create',
            'target_type' => 'employee',
        ]);
    }

    // ── Editing ──────────────────────────────────────────────────────────

    public function test_only_the_fields_sent_are_touched(): void
    {
        // A screen that edits three fields must not blank the twenty it never
        // showed.
        $id = Value::int($this->create(['job_title' => 'Cashier'])->json('data.employee_id'));

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/update.php', ['employee_id' => $id, 'name' => 'Renamed'])
            ->assertOk();

        $row = DB::table('employees')->where('id', $id)->first();
        $this->assertNotNull($row);
        $this->assertSame('Renamed', $row->name);
        $this->assertSame('Cashier', $row->job_title);
    }

    public function test_an_empty_date_clears_it(): void
    {
        $id = Value::int($this->create(['contract_end' => '2027-01-01'])->json('data.employee_id'));

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/update.php', ['employee_id' => $id, 'contract_end' => ''])
            ->assertOk();

        $this->assertNull(DB::table('employees')->where('id', $id)->value('contract_end'));
    }

    public function test_an_empty_leave_entitlement_means_inherit_not_zero(): void
    {
        // Zero is a deliberate "no annual leave"; empty is "use the company
        // default", and the two must not collapse.
        $id = Value::int($this->create(['annual_leave_days' => 25])->json('data.employee_id'));

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/update.php', ['employee_id' => $id, 'annual_leave_days' => ''])
            ->assertOk();

        $this->assertNull(DB::table('employees')->where('id', $id)->value('annual_leave_days'));
    }

    public function test_an_out_of_range_entitlement_is_refused(): void
    {
        $id = Value::int($this->create()->json('data.employee_id'));

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/update.php', ['employee_id' => $id, 'annual_leave_days' => 400])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'annual_leave_days_between_0');
    }

    public function test_sending_an_empty_category_list_removes_them_from_all(): void
    {
        // Sent at all means "these are now their categories", which is how
        // somebody is taken out of one.
        $id = Value::int($this->create(['category_ids' => [1]])->json('data.employee_id'));

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/update.php', ['employee_id' => $id, 'category_ids' => []])
            ->assertOk();

        $this->assertSame(0, DB::table('employee_category_assignments')->where('employee_id', $id)->count());
    }

    public function test_editing_somebody_from_another_company_is_not_found(): void
    {
        $other = Employee::query()->where('tenant_id', '!=', $this->tenantId)->first();
        if ($other === null) {
            $this->markTestSkipped('needs a second company');
        }

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/update.php', ['employee_id' => $other->id, 'name' => 'Hijacked'])
            ->assertNotFound();
    }
}
