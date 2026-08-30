<?php

declare(strict_types=1);

namespace Tests\Feature\Adjustments;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Standing monthly additions, which recur because they have a window rather
 * than a date.
 */
final class AllowanceTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $employeeId;

    private string $adminToken;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Allowance fixture',
            'status' => 'active',
            'base_salary' => 5000,
            'hire_date' => '2021-06-01',
        ]);

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
     */
    private function create(array $overrides = []): int
    {
        $response = $this->send('/app/allowances/create.php', $overrides + [
            'employee_id' => $this->employeeId,
            'type' => 'housing',
            'amount' => 800,
            'start_month' => '2026-01',
        ])->assertOk();

        return Value::int($response->json('data.id'));
    }

    public function test_an_allowance_runs_from_a_month_with_no_end_by_default(): void
    {
        $id = $this->create();

        $this->assertDatabaseHas('employee_allowances', [
            'id' => $id,
            'employee_id' => $this->employeeId,
            'type' => 'housing',
            'amount' => 800.00,
            'start_month' => '2026-01',
            // Open-ended: it runs until somebody stops it, not until a date
            // chosen the day it was created.
            'end_month' => null,
        ]);
    }

    public function test_the_list_names_the_allowance_the_way_the_payslip_will(): void
    {
        $this->create();

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/app/allowances/list.php?employee_id='.$this->employeeId)
            ->assertOk()
            ->assertJsonPath('data.allowances.0.type', 'housing')
            // The screen and the payslip must not disagree about what this is
            // called.
            ->assertJsonPath('data.allowances.0.display_label', 'بدل سكن');
    }

    public function test_a_custom_label_wins_over_the_default_name(): void
    {
        $this->create(['type' => 'other', 'label' => 'بدل طبيعة عمل']);

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/app/allowances/list.php?employee_id='.$this->employeeId)
            ->assertOk()
            ->assertJsonPath('data.allowances.0.display_label', 'بدل طبيعة عمل');
    }

    public function test_an_unknown_type_is_refused(): void
    {
        $this->send('/app/allowances/create.php', [
            'employee_id' => $this->employeeId,
            'type' => 'yacht',
            'amount' => 800,
            'start_month' => '2026-01',
        ])->assertStatus(422);
    }

    public function test_a_window_that_ends_before_it_starts_is_refused(): void
    {
        $this->send('/app/allowances/create.php', [
            'employee_id' => $this->employeeId,
            'type' => 'transport',
            'amount' => 300,
            'start_month' => '2026-06',
            'end_month' => '2026-03',
        ])->assertStatus(422);
    }

    public function test_a_malformed_month_is_refused(): void
    {
        $this->send('/app/allowances/create.php', [
            'employee_id' => $this->employeeId,
            'type' => 'transport',
            'amount' => 300,
            'start_month' => '2026-6',
        ])->assertStatus(422);
    }

    public function test_an_allowance_can_be_closed_by_giving_it_an_end(): void
    {
        $id = $this->create();

        $this->send('/app/allowances/update.php', [
            'id' => $id,
            'type' => 'housing',
            'amount' => 800,
            'start_month' => '2026-01',
            'end_month' => '2026-06',
        ])->assertOk();

        $this->assertDatabaseHas('employee_allowances', ['id' => $id, 'end_month' => '2026-06']);
    }

    public function test_an_allowance_can_be_removed_outright(): void
    {
        $id = $this->create();

        $this->send('/app/allowances/delete.php', ['id' => $id])->assertOk();

        $this->assertDatabaseMissing('employee_allowances', ['id' => $id]);
    }

    public function test_another_companys_allowance_is_not_visible_here(): void
    {
        $otherTenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Other company',
            'timezone' => 'Africa/Cairo',
            'is_active' => 1,
        ]);
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $otherTenant,
            'name' => 'Stranger',
            'status' => 'active',
            'base_salary' => 1000,
            'hire_date' => '2022-01-01',
        ]);
        $foreign = (int) DB::table('employee_allowances')->insertGetId([
            'tenant_id' => $otherTenant,
            'employee_id' => $stranger,
            'type' => 'housing',
            'amount' => 999,
            'start_month' => '2026-01',
        ]);

        $this->send('/app/allowances/delete.php', ['id' => $foreign])->assertStatus(404);
        $this->assertDatabaseHas('employee_allowances', ['id' => $foreign]);
    }
}
