<?php

declare(strict_types=1);

namespace Tests\Feature\Settings;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\CreatesFixtures;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Leave entitlement and carryover, and the statutory deductions a jurisdiction
 * imposes rather than a company choosing.
 */
final class LeaveAndStatutorySettingsTest extends TestCase
{
    use CreatesFixtures;
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

        $this->tenantId = $this->createTenant();
        DB::table('tenants')->where('id', $this->tenantId)->update([
            'leave_carryover_max_days' => null,
            'auto_rollover_enabled' => 0,
            'apply_legal_seniority_entitlement' => 1,
        ]);
        DB::table('leave_carryover_policies')->where('tenant_id', $this->tenantId)->delete();
        DB::table('payroll_statutory_settings')->where('tenant_id', $this->tenantId)->delete();

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
    private function send(string $path, array $payload, ?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)->postJson($path, $payload);
    }

    /**
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function read(string $path, ?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)->getJson($path);
    }

    public function test_a_company_with_no_policy_row_falls_back_to_the_legacy_column(): void
    {
        DB::table('tenants')->where('id', $this->tenantId)->update(['leave_carryover_max_days' => 5]);

        // Before any policy is saved, a cap on the tenant row is the whole
        // policy: carryover is on precisely when one is set.
        $this->read('/v1/settings/leave')
            ->assertOk()
            ->assertJsonPath('data.carryover_enabled', true)
            ->assertJsonPath('data.leave_carryover_max_days', 5);
    }

    public function test_no_cap_and_no_policy_means_carryover_is_off(): void
    {
        $this->read('/v1/settings/leave')
            ->assertOk()
            ->assertJsonPath('data.carryover_enabled', false)
            ->assertJsonPath('data.leave_carryover_max_days', null);
    }

    public function test_the_seniority_entitlement_defaults_on(): void
    {
        // It is a legal minimum; a company that never opened this screen should
        // still honour it.
        $this->read('/v1/settings/leave')
            ->assertOk()
            ->assertJsonPath('data.apply_legal_seniority_entitlement', true);
    }

    public function test_a_carryover_policy_is_saved_and_read_back(): void
    {
        $this->send('/v1/settings/leave', [
            'default_annual_leave_days' => 21,
            'leave_carryover_max_days' => 10,
            'carryover_expiry_months' => 6,
            'carryover_encash_excess' => true,
            'carryover_legal_min_days' => 5,
        ])->assertOk();

        $this->read('/v1/settings/leave')
            ->assertOk()
            ->assertJsonPath('data.default_annual_leave_days', 21)
            ->assertJsonPath('data.carryover_enabled', true)
            ->assertJsonPath('data.leave_carryover_max_days', 10)
            ->assertJsonPath('data.carryover_expiry_months', 6)
            ->assertJsonPath('data.carryover_encash_excess', true)
            ->assertJsonPath('data.carryover_legal_min_days', 5);
    }

    public function test_a_cap_on_its_own_switches_carryover_on(): void
    {
        // Sending a number and having nothing happen is the more surprising
        // behaviour.
        $this->send('/v1/settings/leave', ['leave_carryover_max_days' => 7])->assertOk();

        $this->read('/v1/settings/leave')->assertJsonPath('data.carryover_enabled', true);
    }

    public function test_the_legacy_column_is_kept_in_step(): void
    {
        $this->send('/v1/settings/leave', ['leave_carryover_max_days' => 8])->assertOk();

        // The resolver still falls back to it, and older clients still read it.
        $this->assertDatabaseHas('tenants', [
            'id' => $this->tenantId, 'leave_carryover_max_days' => 8,
        ]);

        $this->send('/v1/settings/leave', ['carryover_enabled' => false])->assertOk();

        $this->assertDatabaseHas('tenants', [
            'id' => $this->tenantId, 'leave_carryover_max_days' => null,
        ]);
    }

    public function test_saving_the_policy_twice_edits_one_row(): void
    {
        $this->send('/v1/settings/leave', ['leave_carryover_max_days' => 5])->assertOk();
        $this->send('/v1/settings/leave', ['leave_carryover_max_days' => 9])->assertOk();

        $this->assertSame(1, DB::table('leave_carryover_policies')
            ->where('tenant_id', $this->tenantId)->where('scope_type', 'tenant')->count());
        $this->read('/v1/settings/leave')->assertJsonPath('data.leave_carryover_max_days', 9);
    }

    public function test_out_of_range_leave_figures_are_refused(): void
    {
        $this->send('/v1/settings/leave', ['default_annual_leave_days' => 400])
            ->assertStatus(422);
        $this->send('/v1/settings/leave', ['leave_carryover_max_days' => 400])
            ->assertStatus(422);
        $this->send('/v1/settings/leave', ['carryover_expiry_months' => 120])
            ->assertStatus(422);
    }

    public function test_a_save_with_nothing_in_it_is_refused(): void
    {
        $this->send('/v1/settings/leave', [])->assertStatus(422);
    }

    public function test_statutory_settings_start_off(): void
    {
        // A wrong number here is applied to every payslip silently, so nothing
        // is on until somebody configures it.
        $this->read('/v1/settings/statutory-payroll')
            ->assertOk()
            ->assertJsonPath('data.social_insurance_enabled', false)
            ->assertJsonPath('data.income_tax_enabled', false)
            ->assertJsonPath('data.eosb_enabled', false)
            ->assertJsonPath('data.income_tax_brackets', []);
    }

    public function test_social_insurance_is_saved_with_its_band(): void
    {
        $this->send('/v1/settings/statutory-payroll', [
            'social_insurance_enabled' => true,
            'si_employee_rate' => 11,
            'si_min_wage' => 2000,
            'si_max_wage' => 12600,
        ])->assertOk();

        $this->read('/v1/settings/statutory-payroll')
            ->assertOk()
            ->assertJsonPath('data.social_insurance_enabled', true)
            ->assertJsonPath('data.si_employee_rate', 11)
            ->assertJsonPath('data.si_max_wage', 12600);
    }

    public function test_an_inverted_insurance_band_is_refused(): void
    {
        $this->send('/v1/settings/statutory-payroll', [
            'social_insurance_enabled' => true,
            'si_employee_rate' => 11,
            'si_min_wage' => 12000,
            'si_max_wage' => 2000,
        ])->assertStatus(422);
    }

    public function test_a_rate_outside_a_percentage_is_refused(): void
    {
        $this->send('/v1/settings/statutory-payroll', [
            'social_insurance_enabled' => true,
            'si_employee_rate' => 150,
        ])->assertStatus(422);
    }

    public function test_tax_brackets_are_stored_in_ascending_order_with_the_open_one_last(): void
    {
        // The progressive calculator walks the ladder in order, so storage is
        // sorted rather than trusting the order the screen sent.
        $this->send('/v1/settings/statutory-payroll', [
            'income_tax_enabled' => true,
            'tax_personal_exemption' => 20000,
            'income_tax_brackets' => [
                ['up_to' => null, 'rate' => 25],
                ['up_to' => 60000, 'rate' => 10],
                ['up_to' => 30000, 'rate' => 2.5],
            ],
        ])->assertOk();

        $this->read('/v1/settings/statutory-payroll')
            ->assertOk()
            ->assertJsonPath('data.income_tax_brackets.0.up_to', 30000)
            ->assertJsonPath('data.income_tax_brackets.1.up_to', 60000)
            ->assertJsonPath('data.income_tax_brackets.2.up_to', null)
            ->assertJsonPath('data.income_tax_brackets.2.rate', 25);
    }

    public function test_two_open_ended_brackets_are_refused(): void
    {
        // "And everything above" only makes sense once; two would leave income
        // with no single home.
        $this->send('/v1/settings/statutory-payroll', [
            'income_tax_enabled' => true,
            'income_tax_brackets' => [
                ['up_to' => null, 'rate' => 25],
                ['up_to' => null, 'rate' => 30],
            ],
        ])->assertStatus(422);
    }

    public function test_duplicate_ceilings_are_refused(): void
    {
        $this->send('/v1/settings/statutory-payroll', [
            'income_tax_enabled' => true,
            'income_tax_brackets' => [
                ['up_to' => 30000, 'rate' => 10],
                ['up_to' => 30000, 'rate' => 20],
            ],
        ])->assertStatus(422);
    }

    public function test_enabling_tax_with_no_brackets_is_refused(): void
    {
        $this->send('/v1/settings/statutory-payroll', [
            'income_tax_enabled' => true,
            'income_tax_brackets' => [],
        ])->assertStatus(422);
    }

    public function test_a_bracket_rate_outside_a_percentage_is_refused(): void
    {
        $this->send('/v1/settings/statutory-payroll', [
            'income_tax_enabled' => true,
            'income_tax_brackets' => [['up_to' => 30000, 'rate' => 250]],
        ])->assertStatus(422);
    }

    public function test_eosb_requires_a_figure_when_enabled(): void
    {
        $this->send('/v1/settings/statutory-payroll', ['eosb_enabled' => true])->assertStatus(422);

        $this->send('/v1/settings/statutory-payroll', [
            'eosb_enabled' => true, 'eosb_days_per_year' => 30,
        ])->assertOk();

        $this->read('/v1/settings/statutory-payroll')->assertJsonPath('data.eosb_days_per_year', 30);
    }

    public function test_turning_something_off_clears_its_figures(): void
    {
        $this->send('/v1/settings/statutory-payroll', [
            'social_insurance_enabled' => true,
            'si_employee_rate' => 11,
            'si_min_wage' => 2000,
        ])->assertOk();

        $this->send('/v1/settings/statutory-payroll', ['social_insurance_enabled' => false])->assertOk();

        // A rate stored but not applied is the one somebody re-enables a year
        // later without re-reading.
        $this->read('/v1/settings/statutory-payroll')
            ->assertJsonPath('data.si_employee_rate', null)
            ->assertJsonPath('data.si_min_wage', null);
    }

    public function test_saving_twice_edits_one_row(): void
    {
        $this->send('/v1/settings/statutory-payroll', ['eosb_enabled' => true, 'eosb_days_per_year' => 21])
            ->assertOk();
        $this->send('/v1/settings/statutory-payroll', ['eosb_enabled' => true, 'eosb_days_per_year' => 30])
            ->assertOk();

        $this->assertSame(1, DB::table('payroll_statutory_settings')
            ->where('tenant_id', $this->tenantId)->count());
    }

    public function test_statutory_settings_belong_to_payroll_not_the_office_manager(): void
    {
        $token = $this->admin('viewer');

        $this->read('/v1/settings/statutory-payroll', $token)->assertStatus(403);
        $this->send('/v1/settings/statutory-payroll', ['eosb_enabled' => false], $token)
            ->assertStatus(403);
    }

    public function test_only_a_settings_manager_may_change_leave_settings(): void
    {
        $token = $this->admin('viewer');

        // But reading is open: other screens render against it.
        $this->read('/v1/settings/leave', $token)->assertOk();
        $this->send('/v1/settings/leave', ['default_annual_leave_days' => 30], $token)
            ->assertStatus(403);
    }
}
