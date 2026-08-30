<?php

declare(strict_types=1);

namespace Tests\Feature\Employees;

use App\Models\Admin;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * The employee list, the terminated list, deactivation, and the employee's own
 * profile.
 */
final class EmployeeListTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private Employee $employee;

    private FakeFirebaseTokenVerifier $firebase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);

        $this->employee = Employee::query()
            ->where('status', 'active')->whereNotNull('branch_id')->firstOrFail();
        $this->tenantId = $this->employee->tenant_id;
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array{Admin, string}
     */
    private function admin(array $overrides = []): array
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        $id = Admin::query()->insertGetId(array_merge([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ], $overrides));

        return [Admin::query()->findOrFail($id), $this->firebase->issue($uid)];
    }

    public function test_the_list_comes_back_paginated_with_headcount_chips(): void
    {
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/app/employees/list.php')
            ->assertOk()
            ->assertJsonStructure(['data' => [
                'items', 'page',
                'stats' => ['total', 'active', 'on_leave', 'pending_activation', 'suspended'],
            ]]);
    }

    public function test_the_face_template_and_pin_digest_never_reach_a_client(): void
    {
        // SELECT e.* would otherwise send both to everybody who opens the list.
        [, $token] = $this->admin();
        Employee::query()->whereKey($this->employee->id)
            ->update(['face_embedding' => json_encode(array_fill(0, 192, 0.1))]);

        $items = $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/app/employees/list.php')
            ->assertOk()
            ->json('data.items');

        $this->assertIsArray($items);
        $this->assertNotEmpty($items);

        // Keyed rather than by substring: face_embedding_dim is a different
        // column — the vector's length — and is not sensitive.
        foreach ($items as $item) {
            $this->assertIsArray($item);
            $this->assertArrayNotHasKey('face_embedding', $item);
            $this->assertArrayNotHasKey('kiosk_pin_hash', $item);
            $this->assertArrayNotHasKey('login_code_hash', $item);
        }
    }

    public function test_terminated_people_are_not_in_the_ordinary_list(): void
    {
        // Showing former staff among current ones is how somebody gets paid
        // twice.
        [, $token] = $this->admin();
        Employee::query()->whereKey($this->employee->id)->update(['status' => 'terminated']);

        $ids = array_column(
            (array) $this->withHeader('X-Firebase-Token', $token)
                ->getJson('/app/employees/list.php')->json('data.items'),
            'id'
        );

        $this->assertNotContains($this->employee->id, $ids);
    }

    public function test_the_search_matches_a_name(): void
    {
        [, $token] = $this->admin();

        $items = $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/app/employees/list.php?search='.urlencode((string) $this->employee->name))
            ->assertOk()
            ->json('data.items');

        $this->assertIsArray($items);
        $this->assertNotEmpty($items);
    }

    public function test_an_unknown_sort_key_falls_back_rather_than_reaching_the_query(): void
    {
        // The value lands in an ORDER BY, which cannot be bound, so it has to
        // come from a list the caller cannot add to.
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/app/employees/list.php?sort='.urlencode('name; DROP TABLE employees'))
            ->assertOk();

        $this->assertGreaterThan(0, Value::int(DB::table('employees')->count()));
    }

    public function test_the_page_size_is_capped(): void
    {
        [, $token] = $this->admin();

        $items = $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/app/employees/list.php?limit=5000')
            ->assertOk()
            ->json('data.items');

        $this->assertIsArray($items);
        $this->assertLessThanOrEqual(50, count($items));
    }

    public function test_the_chips_ignore_the_other_filters(): void
    {
        // They show what the company has, not what is on screen.
        [, $token] = $this->admin();

        $unfiltered = $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/app/employees/list.php')->json('data.stats.total');

        $filtered = $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/app/employees/list.php?search=zzzzz-no-such-person')->json('data.stats.total');

        $this->assertSame($unfiltered, $filtered);
    }

    public function test_a_manager_without_the_permission_is_refused(): void
    {
        [, $token] = $this->admin(['role' => 'attendance']);

        $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/app/employees/list.php')
            ->assertForbidden()
            ->assertJsonPath('error_code', 'missing_permission');
    }

    // ── Terminated ───────────────────────────────────────────────────────

    public function test_the_terminated_list_shows_only_former_staff(): void
    {
        [, $token] = $this->admin();
        Employee::query()->whereKey($this->employee->id)->update(['status' => 'terminated']);

        $ids = array_column(
            (array) $this->withHeader('X-Firebase-Token', $token)
                ->getJson('/app/employees/list_terminated.php')->json('data.items'),
            'id'
        );

        $this->assertContains($this->employee->id, $ids);
    }

    public function test_the_terminated_list_reports_the_currency(): void
    {
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/app/employees/list_terminated.php')
            ->assertOk()
            ->assertJsonStructure(['data' => ['items', 'page', 'total', 'currency']]);
    }

    // ── Deactivation ─────────────────────────────────────────────────────

    public function test_deactivation_keeps_the_history_and_ends_the_session(): void
    {
        // A company that let somebody go still has to answer questions about
        // the years they worked, so the record stays and only the access goes.
        [, $token] = $this->admin();

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-a',
        ]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/employees/delete.php', ['employee_id' => $this->employee->id])
            ->assertOk();

        $this->assertDatabaseHas('employees', ['id' => $this->employee->id, 'status' => 'terminated']);
        $this->assertNull(EmployeeAuthToken::findActiveByPlain($plain));
    }

    public function test_deactivating_somebody_from_another_company_is_not_found(): void
    {
        [, $token] = $this->admin();

        $other = Employee::query()->where('tenant_id', '!=', $this->tenantId)->first();
        if ($other === null) {
            $this->markTestSkipped('needs a second company');
        }

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/employees/delete.php', ['employee_id' => $other->id])
            ->assertNotFound();
    }

    public function test_deactivation_is_audited(): void
    {
        [$admin, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/employees/delete.php', ['employee_id' => $this->employee->id])
            ->assertOk();

        $this->assertDatabaseHas('audit_log', [
            'admin_id' => $admin->id,
            'action' => 'employee.delete',
            'target_type' => 'employee',
        ]);
    }

    // ── The employee's own profile ───────────────────────────────────────

    public function test_an_employee_sees_their_checklist_and_balance(): void
    {
        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-a',
        ]);

        $this->withHeader('X-Employee-Token', $plain)
            ->getJson('/app/employees/my_profile.php')
            ->assertOk()
            ->assertJsonPath('data.employee.id', $this->employee->id)
            ->assertJsonStructure(['data' => [
                'employee', 'documents',
                'leave_balance' => ['year', 'entitlement_days', 'carried_over_days', 'total_days', 'used_days', 'remaining_days'],
            ]]);
    }

    public function test_the_remaining_balance_never_goes_negative(): void
    {
        // An over-taken balance is a payroll question, not a number to show
        // somebody as minus three days.
        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-a',
        ]);

        Employee::query()->whereKey($this->employee->id)->update(['annual_leave_days' => 1]);

        $year = (int) date('Y');
        DB::table('leaves')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'date' => $year.'-06-01',
            'start_date' => $year.'-06-01',
            'end_date' => $year.'-06-30',
            'type' => 'annual',
            'status' => 'approved',
        ]);

        $remaining = $this->withHeader('X-Employee-Token', $plain)
            ->getJson('/app/employees/my_profile.php')
            ->assertOk()
            ->json('data.leave_balance.remaining_days');

        $this->assertSame(0, $remaining);
    }
}
