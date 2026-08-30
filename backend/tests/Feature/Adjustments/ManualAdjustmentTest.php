<?php

declare(strict_types=1);

namespace Tests\Feature\Adjustments;

use App\Domain\Notifications\PushSender;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * One-off bonuses and deductions typed in against a single person.
 */
final class ManualAdjustmentTest extends TestCase
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
            'name' => 'Adjustment fixture',
            'status' => 'active',
            'base_salary' => 4000,
            'hire_date' => '2021-01-01',
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

    public function test_a_manual_deduction_is_recorded_against_the_current_month(): void
    {
        $response = $this->send('/app/deductions/add_manual.php', [
            'employee_id' => $this->employeeId,
            'amount' => 250,
            'reason' => 'Damaged equipment',
        ])->assertOk();

        $id = Value::int($response->json('data.id'));

        $this->assertDatabaseHas('manual_deductions', [
            'id' => $id,
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'amount' => 250.00,
            'reason' => 'Damaged equipment',
            // Not part of a batch: somebody typed this one in.
            'batch_id' => null,
        ]);
    }

    public function test_a_manual_bonus_lands_in_its_own_table(): void
    {
        $response = $this->send('/app/bonuses/add_manual.php', [
            'employee_id' => $this->employeeId,
            'amount' => 500,
            'reason' => 'Overtime weekend',
        ])->assertOk();

        $this->assertDatabaseHas('manual_bonuses', [
            'id' => Value::int($response->json('data.id')),
            'amount' => 500.00,
        ]);
        // Nothing was charged against them: the two live in separate tables.
        $this->assertSame(0, DB::table('manual_deductions')
            ->where('employee_id', $this->employeeId)->count());
    }

    public function test_the_employee_is_told_about_the_deduction(): void
    {
        $this->send('/app/deductions/add_manual.php', [
            'employee_id' => $this->employeeId,
            'amount' => 100,
            'reason' => 'Late fine',
        ])->assertOk();

        // A deduction nobody was told about is the one that produces the
        // argument on payday.
        $this->assertDatabaseHas('notifications', [
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'type' => 'payroll',
        ]);
    }

    public function test_a_zero_or_negative_amount_is_refused(): void
    {
        $this->send('/app/deductions/add_manual.php', [
            'employee_id' => $this->employeeId,
            'amount' => 0,
            'reason' => 'Nothing',
        ])->assertStatus(422);

        $this->send('/app/bonuses/add_manual.php', [
            'employee_id' => $this->employeeId,
            'amount' => -5,
            'reason' => 'Negative bonus',
        ])->assertStatus(422);
    }

    public function test_an_adjustment_against_somebody_elses_employee_is_refused(): void
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

        $this->send('/app/deductions/add_manual.php', [
            'employee_id' => $stranger,
            'amount' => 100,
            'reason' => 'Should not reach',
        ])->assertStatus(404);
    }

    public function test_an_existing_line_can_be_corrected(): void
    {
        $id = Value::int($this->send('/app/bonuses/add_manual.php', [
            'employee_id' => $this->employeeId,
            'amount' => 300,
            'reason' => 'Typo',
        ])->json('data.id'));

        $this->send('/app/bonuses/update_manual.php', [
            'id' => $id,
            'amount' => 350,
            'reason' => 'Corrected',
        ])->assertOk();

        $this->assertDatabaseHas('manual_bonuses', [
            'id' => $id, 'amount' => 350.00, 'reason' => 'Corrected',
        ]);
    }

    public function test_a_line_can_be_withdrawn(): void
    {
        $id = Value::int($this->send('/app/deductions/add_manual.php', [
            'employee_id' => $this->employeeId,
            'amount' => 75,
            'reason' => 'Applied by mistake',
        ])->json('data.id'));

        $this->send('/app/deductions/delete_manual.php', ['id' => $id])->assertOk();

        $this->assertDatabaseMissing('manual_deductions', ['id' => $id]);
    }

    public function test_a_bonus_id_cannot_be_used_to_edit_a_deduction(): void
    {
        // The two live in separate tables and the endpoints are separate for
        // the same reason: crossing them would let a bonus be silently turned
        // into a charge against somebody's pay.
        $bonusId = Value::int($this->send('/app/bonuses/add_manual.php', [
            'employee_id' => $this->employeeId,
            'amount' => 200,
            'reason' => 'Bonus',
        ])->json('data.id'));

        $this->send('/app/deductions/update_manual.php', [
            'id' => $bonusId,
            'amount' => 200,
            'reason' => 'Crossed over',
        ])->assertStatus(404);
    }

    public function test_a_viewer_cannot_record_an_adjustment(): void
    {
        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);

        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Viewer',
            'role' => 'viewer',
            'is_active' => 1,
        ]);

        $this->withHeader('X-Firebase-Token', $firebase->issue($uid))
            ->postJson('/app/deductions/add_manual.php', [
                'employee_id' => $this->employeeId,
                'amount' => 100,
                'reason' => 'Not allowed',
            ])->assertStatus(403);
    }
}
