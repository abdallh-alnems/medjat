<?php

declare(strict_types=1);

namespace Tests\Feature\Settlements;

use App\Models\EmployeeAuthToken;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Modules\Settlements\Domain\SettlementCalculator;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\CreatesFixtures;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The final account with somebody leaving.
 */
final class SettlementTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    private const LAST_DAY = '2026-04-30';

    private int $tenantId;

    private int $employeeId;

    private FakeFirebaseTokenVerifier $firebase;

    private string $adminToken;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = $this->createTenant();

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Leaving employee',
            'status' => 'active',
            'base_salary' => 6000,
            'hire_date' => '2020-05-01',
        ]);

        $this->adminToken = $this->admin('general_manager');
    }

    private function admin(string $role): string
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Admin '.$role,
            'role' => $role,
            'is_active' => 1,
        ]);

        return $this->firebase->issue($uid);
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function send(string $path, array $payload = [], ?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)->postJson($path, $payload);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function save(array $overrides = []): TestResponse
    {
        return $this->send('/v1/settlements', $overrides + [
            'employee_id' => $this->employeeId,
            'reason' => 'resignation',
            'last_working_day' => self::LAST_DAY,
            'pending_salary' => 4000,
            'gratuity_amount' => 20000,
            'leave_encashment' => 1000,
            'outstanding_loans' => 2000,
        ]);
    }

    public function test_a_draft_is_saved_with_its_totals_recomputed_from_the_parts(): void
    {
        $this->save()->assertOk();

        // 4000 + 20000 + 1000 earned, 2000 owed back.
        $this->assertDatabaseHas('employee_settlements', [
            'employee_id' => $this->employeeId,
            'total_earnings' => 25000.00,
            'total_deductions' => 2000.00,
            'net_amount' => 23000.00,
            'status' => 'draft',
        ]);
    }

    public function test_a_client_supplied_net_cannot_disagree_with_its_own_lines(): void
    {
        // The totals are always recomputed here, so a settlement can never
        // record a figure nobody could reconstruct from the parts.
        $this->save(['net_amount' => 999999, 'total_earnings' => 999999])->assertOk();

        $this->assertDatabaseHas('employee_settlements', [
            'employee_id' => $this->employeeId, 'net_amount' => 23000.00,
        ]);
    }

    public function test_custom_lines_are_folded_into_the_right_side(): void
    {
        $this->save(['line_items' => [
            ['label' => 'Notice period', 'kind' => 'earning', 'amount' => 3000],
            ['label' => 'Company laptop', 'kind' => 'deduction', 'amount' => 500],
        ]])->assertOk();

        $this->assertDatabaseHas('employee_settlements', [
            'employee_id' => $this->employeeId,
            'total_earnings' => 28000.00,
            'total_deductions' => 2500.00,
            'net_amount' => 25500.00,
        ]);
    }

    public function test_an_unlabelled_line_is_dropped(): void
    {
        // The settlement is handed to somebody as the account of what they are
        // owed; an unexplained figure on it is the one that gets disputed.
        $this->save(['line_items' => [
            ['label' => '   ', 'kind' => 'earning', 'amount' => 5000],
            ['label' => 'Handover bonus', 'kind' => 'earning', 'amount' => 1000],
        ]])->assertOk();

        $response = $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/settlements?employee_id='.$this->employeeId)
            ->assertOk();

        $this->assertCount(1, (array) $response->json('data.settlement.line_items'));
        $this->assertDatabaseHas('employee_settlements', [
            'employee_id' => $this->employeeId, 'total_earnings' => 26000.00,
        ]);
    }

    public function test_saving_twice_edits_the_same_settlement(): void
    {
        $first = Value::int($this->save()->json('data.settlement_id'));
        $second = Value::int($this->save(['pending_salary' => 5000])->json('data.settlement_id'));

        // One per employee: a second row would leave two accounts of what the
        // same person is owed.
        $this->assertSame($first, $second);
        $this->assertSame(1, DB::table('employee_settlements')
            ->where('employee_id', $this->employeeId)->count());
    }

    public function test_an_unknown_reason_is_refused(): void
    {
        $this->save(['reason' => 'abducted'])->assertStatus(422);
    }

    public function test_a_malformed_last_working_day_is_refused(): void
    {
        $this->save(['last_working_day' => '30-04-2026'])->assertStatus(422);
    }

    public function test_somebody_already_terminated_cannot_be_settled_again(): void
    {
        DB::table('employees')->where('id', $this->employeeId)->update(['status' => 'terminated']);

        $this->save()->assertStatus(422);
    }

    public function test_approving_freezes_the_figures_and_ends_the_service(): void
    {
        $this->save()->assertOk();

        $this->send('/v1/settlements/approve', ['employee_id' => $this->employeeId])
            ->assertOk()
            ->assertJsonPath('data.settlement.status', 'approved');

        $this->assertDatabaseHas('employees', [
            'id' => $this->employeeId,
            'status' => 'terminated',
            'terminated_at' => self::LAST_DAY,
        ]);

        $frozen = DB::table('employee_settlements')->where('employee_id', $this->employeeId)->first();
        $this->assertNotNull($frozen);
        $breakdown = json_decode(Value::string($frozen->breakdown), true);
        $this->assertIsArray($breakdown);
        $this->assertSame('23000.00', Value::string($breakdown['net_amount'] ?? null));
    }

    public function test_the_snapshot_does_not_freeze_an_administrators_name(): void
    {
        $this->save()->assertOk();
        $this->send('/v1/settlements/approve', ['employee_id' => $this->employeeId])->assertOk();

        $frozen = DB::table('employee_settlements')->where('employee_id', $this->employeeId)->first();
        $breakdown = json_decode(Value::string($frozen?->breakdown), true);
        $this->assertIsArray($breakdown);

        // Those columns are joins, not settlement data.
        $this->assertArrayNotHasKey('created_by_name', $breakdown);
        $this->assertArrayNotHasKey('approved_by_name', $breakdown);
    }

    public function test_approving_signs_the_employee_out_of_the_app(): void
    {
        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-leaver',
        ]);

        $this->save()->assertOk();
        $this->send('/v1/settlements/approve', ['employee_id' => $this->employeeId])->assertOk();

        // Otherwise the app keeps showing a former employer's roster until the
        // token happens to expire.
        $this->withHeader('X-Employee-Token', $plain)
            ->postJson('/v1/biometric/self/status')
            ->assertStatus(401);
    }

    public function test_an_approved_settlement_cannot_be_edited(): void
    {
        $this->save()->assertOk();
        $this->send('/v1/settlements/approve', ['employee_id' => $this->employeeId])->assertOk();

        $this->save(['pending_salary' => 99999])->assertStatus(422);
    }

    public function test_approving_twice_is_refused(): void
    {
        $this->save()->assertOk();
        $this->send('/v1/settlements/approve', ['employee_id' => $this->employeeId])->assertOk();

        $this->send('/v1/settlements/approve', ['employee_id' => $this->employeeId])
            ->assertStatus(409);
    }

    public function test_approving_without_a_saved_settlement_is_refused(): void
    {
        $this->send('/v1/settlements/approve', ['employee_id' => $this->employeeId])
            ->assertStatus(404);
    }

    public function test_payment_can_only_be_recorded_after_approval(): void
    {
        $this->save()->assertOk();

        $this->send('/v1/settlements/mark-paid', ['employee_id' => $this->employeeId])
            ->assertStatus(409);

        $this->send('/v1/settlements/approve', ['employee_id' => $this->employeeId])->assertOk();

        $this->send('/v1/settlements/mark-paid', ['employee_id' => $this->employeeId])
            ->assertOk()
            ->assertJsonPath('data.settlement.status', 'paid');
    }

    public function test_paying_twice_is_refused(): void
    {
        $this->save()->assertOk();
        $this->send('/v1/settlements/approve', ['employee_id' => $this->employeeId])->assertOk();
        $this->send('/v1/settlements/mark-paid', ['employee_id' => $this->employeeId])->assertOk();

        $this->send('/v1/settlements/mark-paid', ['employee_id' => $this->employeeId])
            ->assertStatus(409);
    }

    public function test_the_page_is_prefilled_with_a_computed_suggestion(): void
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/settlements?employee_id='.$this->employeeId)
            ->assertOk()
            ->assertJsonPath('data.employee.id', $this->employeeId)
            ->assertJsonPath('data.settlement', null)
            // 6000 / 30.
            ->assertJsonPath('data.suggested.daily_rate', 200);
    }

    public function test_the_preview_recomputes_for_a_different_leaving_date(): void
    {
        $earlier = $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/settlements/preview?employee_id='.$this->employeeId
                .'&last_working_day=2024-05-01')
            ->assertOk();

        $later = $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/settlements/preview?employee_id='.$this->employeeId
                .'&last_working_day=2030-05-01')
            ->assertOk();

        // Every extra year of service buys more gratuity.
        $this->assertGreaterThan(
            Value::float($earlier->json('data.suggested.gratuity_amount')),
            Value::float($later->json('data.suggested.gratuity_amount')),
        );

        // And nothing was saved by looking.
        $this->assertSame(0, DB::table('employee_settlements')
            ->where('employee_id', $this->employeeId)->count());
    }

    public function test_the_preview_refuses_a_malformed_date(): void
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/settlements/preview?employee_id='.$this->employeeId
                .'&last_working_day=next-friday')
            ->assertStatus(422);
    }

    public function test_gratuity_accrues_faster_after_the_fifth_year(): void
    {
        // 21 days a year for the first five, 30 after.
        $this->assertSame(105.0, SettlementCalculator::gratuityDays(5.0));
        $this->assertSame(135.0, SettlementCalculator::gratuityDays(6.0));
        $this->assertSame(0.0, SettlementCalculator::gratuityDays(0.0));
    }

    public function test_service_is_measured_in_fractional_years(): void
    {
        $this->assertSame(1.0, SettlementCalculator::yearsOfService('2025-01-01', '2026-01-01'));
        // A leaving date before the hire date is nonsense, not negative service.
        $this->assertSame(0.0, SettlementCalculator::yearsOfService('2026-01-01', '2025-01-01'));
        $this->assertSame(0.0, SettlementCalculator::yearsOfService(null, '2026-01-01'));
    }

    public function test_another_companys_employee_is_out_of_reach(): void
    {
        $otherTenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Other company', 'timezone' => 'Africa/Cairo', 'is_active' => 1,
        ]);
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $otherTenant,
            'name' => 'Stranger',
            'status' => 'active',
            'base_salary' => 1000,
            'hire_date' => '2022-01-01',
        ]);

        $this->send('/v1/settlements', [
            'employee_id' => $stranger,
            'last_working_day' => self::LAST_DAY,
        ])->assertStatus(404);
    }

    public function test_a_viewer_cannot_settle_anybody(): void
    {
        $this->save([])->assertOk();

        $this->send('/v1/settlements/approve', ['employee_id' => $this->employeeId], $this->admin('viewer'))
            ->assertStatus(403);
    }
}
