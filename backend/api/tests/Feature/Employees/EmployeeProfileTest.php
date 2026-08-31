<?php

declare(strict_types=1);

namespace Tests\Feature\Employees;

use App\Models\ActivationCode;
use App\Models\Admin;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * The profile screen, the compliance list, year-to-date, and the activation
 * code.
 */
final class EmployeeProfileTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private Employee $employee;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);

        $this->employee = Employee::query()->where('status', 'active')->firstOrFail();
        $this->tenantId = $this->employee->tenant_id;

        $uid = 'uid-'.bin2hex(random_bytes(6));
        Admin::query()->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);

        $this->token = $firebase->issue($uid);

        // The dump carries real history for this person. These cases are about
        // what the request produces, so the slate is cleared first.
        DB::table('employee_auth_tokens')->where('employee_id', $this->employee->id)->delete();
        DB::table('warnings')->where('employee_id', $this->employee->id)->delete();
        DB::table('employee_activation_codes')->where('employee_id', $this->employee->id)->delete();
    }

    // ── Profile ──────────────────────────────────────────────────────────

    public function test_the_profile_never_carries_the_biometric_template_or_the_pin_digest(): void
    {
        // Handing out the template gives away the very thing an impersonation
        // would otherwise have to produce, and a six-digit hash is a short
        // offline search away from the code itself.
        Employee::query()->whereKey($this->employee->id)->update([
            'face_embedding' => json_encode(array_fill(0, 192, 0.1)),
            'kiosk_pin_hash' => password_hash('123456', PASSWORD_BCRYPT, ['cost' => 4]),
        ]);

        $employee = $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/profile?id='.$this->employee->id)
            ->assertOk()
            ->json('data.employee');

        $this->assertIsArray($employee);
        $this->assertArrayNotHasKey('face_embedding', $employee);
        $this->assertArrayNotHasKey('kiosk_pin_hash', $employee);

        // Replaced by what the interface actually wants, so no screen has a
        // reason to ask for the originals.
        $this->assertTrue($employee['face_enrolled']);
        $this->assertTrue($employee['kiosk_pin_set']);
    }

    public function test_the_profile_carries_the_supporting_blocks(): void
    {
        $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/profile?id='.$this->employee->id)
            ->assertOk()
            ->assertJsonStructure(['data' => [
                'employee', 'documents', 'warnings', 'leave_balance',
                'categories', 'cycle_start_day', 'active_suspension',
            ]]);
    }

    public function test_an_elapsed_suspension_is_reconciled_before_the_status_is_read(): void
    {
        // Otherwise the screen shows the state from a moment before the
        // reactivation it just performed.
        Employee::query()->whereKey($this->employee->id)->update(['status' => 'suspended']);
        DB::table('employee_suspensions')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'reason' => 'Elapsed',
            'pay_mode' => 'unpaid',
            'start_date' => date('Y-m-d', strtotime('-9 days')),
            'end_date' => date('Y-m-d', strtotime('-1 day')),
            'previous_status' => 'active',
            'status' => 'active',
        ]);

        $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/profile?id='.$this->employee->id)
            ->assertOk()
            ->assertJsonPath('data.employee.status', 'active')
            ->assertJsonPath('data.active_suspension', null);
    }

    public function test_a_profile_from_another_company_is_not_found(): void
    {
        $other = Employee::query()->where('tenant_id', '!=', $this->tenantId)->first();
        if ($other === null) {
            $this->markTestSkipped('needs a second company');
        }

        $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/profile?id='.$other->id)
            ->assertNotFound();
    }

    // ── Compliance ───────────────────────────────────────────────────────

    public function test_an_already_expired_credential_is_listed_first(): void
    {
        // Expiry turns a legal employee into an illegal one without anybody
        // doing anything, and an expired iqama is more urgent than one expiring
        // next week.
        Employee::query()->whereKey($this->employee->id)->update([
            'iqama_number' => 'A123',
            'iqama_expiry' => date('Y-m-d', strtotime('-5 days')),
        ]);

        $items = $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/expiring-compliance?days=30')
            ->assertOk()
            ->json('data.items');

        $this->assertIsArray($items);
        $this->assertNotEmpty($items);

        $first = $items[0];
        $this->assertIsArray($first);
        $this->assertTrue($first['is_expired']);
        $this->assertLessThan(0, $first['days_left']);
    }

    public function test_expired_items_can_be_excluded(): void
    {
        Employee::query()->whereKey($this->employee->id)->update([
            'iqama_expiry' => date('Y-m-d', strtotime('-5 days')),
        ]);

        $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/expiring-compliance?days=30&include_expired=0')
            ->assertOk()
            ->assertJsonPath('data.expired_count', 0);
    }

    public function test_one_person_with_two_lapsing_credentials_appears_twice(): void
    {
        // They need chasing twice.
        Employee::query()->whereKey($this->employee->id)->update([
            'iqama_expiry' => date('Y-m-d', strtotime('+3 days')),
            'passport_expiry' => date('Y-m-d', strtotime('+5 days')),
        ]);

        $items = $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/expiring-compliance?days=30')
            ->assertOk()
            ->json('data.items');

        $this->assertIsArray($items);
        $mine = array_filter($items, fn (mixed $i): bool => is_array($i) && $i['employee_id'] === $this->employee->id);
        $this->assertGreaterThanOrEqual(2, count($mine));
    }

    public function test_the_window_is_clamped(): void
    {
        $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/expiring-compliance?days=99999')
            ->assertOk()
            ->assertJsonPath('data.days', 365);
    }

    // ── Year to date ─────────────────────────────────────────────────────

    public function test_year_to_date_totals_the_saved_payroll_rows(): void
    {
        $year = (int) date('Y');
        DB::table('payroll')->where('employee_id', $this->employee->id)->delete();
        DB::table('payroll')->insert([
            [
                'tenant_id' => $this->tenantId, 'employee_id' => $this->employee->id,
                'month' => $year.'-01', 'base_salary' => 5000, 'total_deductions' => 200,
                'total_bonuses' => 300, 'net_salary' => 5100, 'status' => 'paid',
            ],
            [
                'tenant_id' => $this->tenantId, 'employee_id' => $this->employee->id,
                'month' => $year.'-02', 'base_salary' => 5000, 'total_deductions' => 0,
                'total_bonuses' => 0, 'net_salary' => 5000, 'status' => 'draft',
            ],
        ]);

        $totals = $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/year-to-date?employee_id='.$this->employee->id)
            ->assertOk()
            ->json('data.totals');

        $this->assertIsArray($totals);
        $this->assertEquals(10000, $totals['total_base']);
        $this->assertEquals(10100, $totals['total_net']);
        $this->assertSame(2, $totals['months_count']);
        $this->assertSame(1, $totals['paid_count']);
        $this->assertSame(1, $totals['draft_count']);
    }

    public function test_an_impossible_year_is_refused(): void
    {
        $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/year-to-date?employee_id='.$this->employee->id.'&year=1800')
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'invalid_year');
    }

    // ── Activation code ──────────────────────────────────────────────────

    public function test_the_live_code_and_the_bound_handset_are_reported(): void
    {
        ActivationCode::generateFor($this->tenantId, $this->employee->id);
        EmployeeAuthToken::issue($this->tenantId, $this->employee->id, 'device-a', 'Pixel 8', 'android', '1.2.3');

        $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/activation-code?id='.$this->employee->id)
            ->assertOk()
            ->assertJsonPath('data.device_bound', true)
            ->assertJsonPath('data.device.device_model', 'Pixel 8')
            ->assertJsonStructure(['data' => ['activation_code', 'activation_token', 'join_link', 'expires_at']]);
    }

    public function test_a_browser_session_is_not_reported_as_a_bound_handset(): void
    {
        // Otherwise a web session answers a question the administrator is asking
        // about a phone.
        EmployeeAuthToken::issueWeb($this->tenantId, $this->employee->id, 'browser-1', 3600);

        $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/v1/employees/activation-code?id='.$this->employee->id)
            ->assertOk()
            ->assertJsonPath('data.device_bound', false);
    }

    public function test_reissuing_for_an_active_employee_severs_the_old_handset(): void
    {
        // "Somebody asked for a new code for a working account" is the shape of
        // both a lost phone and an account takeover, so the old device loses
        // access immediately and a warning is filed.
        Employee::query()->whereKey($this->employee->id)->update(['status' => 'active']);
        $old = EmployeeAuthToken::issue($this->tenantId, $this->employee->id, 'device-a', null, 'android', null);

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/v1/employees/activation-code', ['id' => $this->employee->id])
            ->assertOk()
            ->assertJsonPath('data.device_revoked', true);

        $this->assertNull(EmployeeAuthToken::findActiveByPlain($old));
        $this->assertSame(
            'pending_activation',
            DB::table('employees')->where('id', $this->employee->id)->value('status')
        );
        $this->assertDatabaseHas('warnings', [
            'employee_id' => $this->employee->id,
            'type' => 'device_change',
        ]);
    }

    public function test_reissuing_for_a_pending_employee_is_not_a_device_reset(): void
    {
        Employee::query()->whereKey($this->employee->id)->update(['status' => 'pending_activation']);

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/v1/employees/activation-code', ['id' => $this->employee->id])
            ->assertOk()
            ->assertJsonPath('data.device_revoked', false);

        $this->assertDatabaseMissing('warnings', [
            'employee_id' => $this->employee->id,
            'type' => 'device_change',
        ]);
    }

    public function test_a_terminated_employee_gets_no_new_code(): void
    {
        Employee::query()->whereKey($this->employee->id)->update(['status' => 'terminated']);

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/v1/employees/activation-code', ['id' => $this->employee->id])
            ->assertStatus(409)
            ->assertJsonPath('error_code', 'cannot_generate_code_terminated_employee');
    }

    public function test_reissuing_expires_the_previous_code(): void
    {
        $first = ActivationCode::generateFor($this->tenantId, $this->employee->id);

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/v1/employees/activation-code', ['id' => $this->employee->id])
            ->assertOk();

        $this->assertNull(
            ActivationCode::findUsableByCode($first['code']),
            'a stale message must not be able to activate an account after a deliberate reissue'
        );
    }
}
