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
 * The ladder a company charges lateness by, and what an absence costs.
 */
final class DeductionRulesTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private FakeFirebaseTokenVerifier $firebase;

    private string $adminToken;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        DB::table('deduction_rules')->where('tenant_id', $this->tenantId)->delete();
        DB::table('late_deduction_tiers')->where('tenant_id', $this->tenantId)->delete();

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
    private function save(array $payload, ?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)
            ->postJson('/v1/deduction-rules', $payload);
    }

    /**
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function read(): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/deduction-rules');
    }

    public function test_an_unconfigured_company_is_shown_what_payroll_actually_applies(): void
    {
        // If this default drifted from the calculator's fallback, opening the
        // screen and pressing save would silently change everybody's
        // deductions.
        $this->read()
            ->assertOk()
            ->assertJsonPath('data.config.late_type', 'tiered')
            ->assertJsonPath('data.config.absence_days', 1.5)
            ->assertJsonPath('data.config.tiers', []);
    }

    public function test_a_ladder_is_saved_and_read_back_in_order(): void
    {
        $this->save([
            'absence_days' => 2,
            'tiers' => [
                ['threshold_minutes' => 60, 'deduction_days' => 0.5],
                ['threshold_minutes' => 15, 'deduction_days' => 0.25],
            ],
        ])->assertOk();

        $this->read()
            ->assertOk()
            ->assertJsonPath('data.config.absence_days', 2)
            // Read back lowest rung first, which is the order it is applied in.
            ->assertJsonPath('data.config.tiers.0.threshold_minutes', 15)
            ->assertJsonPath('data.config.tiers.1.threshold_minutes', 60)
            ->assertJsonPath('data.config.tiers.1.deduction_days', 0.5);
    }

    public function test_saving_replaces_the_ladder_rather_than_adding_to_it(): void
    {
        $this->save([
            'absence_days' => 1,
            'tiers' => [
                ['threshold_minutes' => 15, 'deduction_days' => 0.25],
                ['threshold_minutes' => 30, 'deduction_days' => 0.5],
            ],
        ])->assertOk();

        $this->save([
            'absence_days' => 1,
            'tiers' => [['threshold_minutes' => 20, 'deduction_days' => 1]],
        ])->assertOk();

        // The ladder is a statement of what the company charges now; merging
        // would leave rungs nobody chose.
        $this->assertSame(1, DB::table('late_deduction_tiers')->where('tenant_id', $this->tenantId)->count());
        $this->read()->assertJsonPath('data.config.tiers.0.threshold_minutes', 20);
    }

    public function test_the_ladder_can_be_emptied(): void
    {
        $this->save([
            'absence_days' => 1,
            'tiers' => [['threshold_minutes' => 15, 'deduction_days' => 0.25]],
        ])->assertOk();

        $this->save(['absence_days' => 1, 'tiers' => []])->assertOk();

        $this->read()->assertJsonPath('data.config.tiers', []);
    }

    public function test_two_rungs_at_the_same_height_are_refused(): void
    {
        // Two rungs at one threshold makes the ladder ambiguous, with no way to
        // say which applies.
        $this->save([
            'absence_days' => 1,
            'tiers' => [
                ['threshold_minutes' => 15, 'deduction_days' => 0.25],
                ['threshold_minutes' => 15, 'deduction_days' => 0.5],
            ],
        ])->assertStatus(422);

        $this->assertSame(0, DB::table('late_deduction_tiers')->where('tenant_id', $this->tenantId)->count());
    }

    public function test_a_rung_with_no_height_or_no_cost_is_refused(): void
    {
        $this->save([
            'absence_days' => 1,
            'tiers' => [['threshold_minutes' => 0, 'deduction_days' => 0.5]],
        ])->assertStatus(422);

        $this->save([
            'absence_days' => 1,
            'tiers' => [['threshold_minutes' => 15, 'deduction_days' => 0]],
        ])->assertStatus(422);
    }

    public function test_a_negative_absence_charge_is_refused(): void
    {
        $this->save(['absence_days' => -1, 'tiers' => []])->assertStatus(422);
    }

    public function test_nothing_is_written_when_one_rung_is_invalid(): void
    {
        $this->save([
            'absence_days' => 3,
            'tiers' => [
                ['threshold_minutes' => 15, 'deduction_days' => 0.25],
                ['threshold_minutes' => -1, 'deduction_days' => 0.5],
            ],
        ])->assertStatus(422);

        // Half a ladder is worse than none: it would charge people by a policy
        // nobody approved.
        $this->assertSame(0, DB::table('late_deduction_tiers')->where('tenant_id', $this->tenantId)->count());
        $this->assertDatabaseMissing('deduction_rules', [
            'tenant_id' => $this->tenantId, 'rule_key' => 'absence_multiplier',
        ]);
    }

    public function test_running_payroll_does_not_confer_the_right_to_set_the_policy(): void
    {
        // Deciding what lateness costs is a policy decision; the clerk who
        // enters this month's bonuses is not necessarily the person who makes
        // it.
        $token = $this->admin('viewer');
        DB::table('custom_roles')->insert([
            'tenant_id' => $this->tenantId,
            'admin_id' => Value::int(DB::table('admins')->where('tenant_id', $this->tenantId)
                ->orderByDesc('id')->value('id')),
            'name' => 'Payroll clerk',
            'permissions' => json_encode(['manage_payroll']),
        ]);

        $this->save(['absence_days' => 1, 'tiers' => []], $token)->assertStatus(403);

        // But they can still read it — every screen explaining a deduction
        // needs it.
        $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/v1/deduction-rules')
            ->assertOk();
    }
}
