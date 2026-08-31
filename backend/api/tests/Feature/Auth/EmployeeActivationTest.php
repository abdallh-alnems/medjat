<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\ActivationCode;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Models\EmployeeWebCredential;
use App\Shared\Access\PinPolicy;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;
use Tests\TestCase;

/**
 * First-time activation, by join link on the phone and by PIN in the browser.
 */
final class EmployeeActivationTest extends TestCase
{
    use DatabaseTransactions;

    private function employee(): Employee
    {
        $employee = Employee::query()
            ->where('status', '!=', 'terminated')
            ->whereNotNull('phone')
            ->where('phone', '!=', '')
            ->firstOrFail();

        DB::table('tenants')->where('id', $employee->tenant_id)->update(['web_attendance_enabled' => 1]);
        RateLimiter::clear('web_activate:'.preg_replace('/\D/', '', (string) $employee->phone));

        return $employee;
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function activationCode(Employee $employee, array $overrides = []): ActivationCode
    {
        return ActivationCode::query()->create(array_merge([
            'tenant_id' => $employee->tenant_id,
            'employee_id' => $employee->id,
            'code' => strtoupper(bin2hex(random_bytes(4))),
            'token' => bin2hex(random_bytes(16)),
            'expires_at' => now()->addDay(),
        ], $overrides));
    }

    // ── Join link / QR ───────────────────────────────────────────────────

    public function test_a_join_link_activates_without_needing_the_phone(): void
    {
        // The token is the secret: opening the link is the proof, so unlike the
        // phone-and-code path there is nothing to match.
        $employee = $this->employee();
        $code = $this->activationCode($employee);

        $response = $this->postJson('/v1/auth/employee/activate', [
            'token' => $code->token,
            'device_id' => 'device-a',
        ])->assertOk()->assertJsonPath('data.employee.id', $employee->id);

        $token = $response->json('data.token');
        $this->assertIsString($token);
        $this->assertNotNull(EmployeeAuthToken::findActiveByPlain($token));
    }

    public function test_a_join_link_is_single_use(): void
    {
        $employee = $this->employee();
        $code = $this->activationCode($employee);
        $payload = ['token' => $code->token, 'device_id' => 'device-a'];

        $this->postJson('/v1/auth/employee/activate', $payload)->assertOk();

        $this->postJson('/v1/auth/employee/activate', $payload)
            ->assertNotFound()
            ->assertJsonPath('error_code', 'join_link_invalid');
    }

    public function test_consuming_the_link_also_invalidates_its_sibling_code(): void
    {
        // Both name the same activation row, so spending one must spend both.
        $employee = $this->employee();
        $code = $this->activationCode($employee);

        $this->postJson('/v1/auth/employee/activate', [
            'token' => $code->token, 'device_id' => 'device-a',
        ])->assertOk();

        $this->assertNull(ActivationCode::findUsableByCode($code->code));
    }

    public function test_an_expired_link_is_refused(): void
    {
        $employee = $this->employee();
        $code = $this->activationCode($employee, ['expires_at' => now()->subMinute()]);

        $this->postJson('/v1/auth/employee/activate', [
            'token' => $code->token, 'device_id' => 'device-a',
        ])->assertNotFound()->assertJsonPath('error_code', 'join_link_invalid');
    }

    public function test_activation_creates_the_admins_row_the_employee_needs(): void
    {
        // Shared with the phone-and-code path on purpose: the two drifting apart
        // is how one of them quietly stops doing this.
        $employee = $this->employee();
        Employee::query()->whereKey($employee->id)->update(['admin_id' => null, 'status' => 'pending_activation']);

        $this->postJson('/v1/auth/employee/activate', [
            'token' => $this->activationCode($employee)->token, 'device_id' => 'device-a',
        ])->assertOk();

        $row = DB::table('employees')->where('id', $employee->id)->first();
        $this->assertNotNull($row);
        $this->assertNotNull($row->admin_id);
        $this->assertSame('active', $row->status);
    }

    public function test_missing_fields_are_refused(): void
    {
        $this->postJson('/v1/auth/employee/activate', ['token' => '', 'device_id' => ''])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'missing_fields');
    }

    // ── Browser activation ───────────────────────────────────────────────

    public function test_activation_exchanges_the_code_for_a_pin_and_a_session(): void
    {
        $employee = $this->employee();
        DB::table('employee_web_credentials')->where('employee_id', $employee->id)->delete();
        $code = $this->activationCode($employee);

        $response = $this->postJson('/v1/auth/employee/web/activate', [
            'phone' => $employee->phone,
            'activation_code' => $code->code,
            'pin' => '481920',
            'device_id' => 'browser-1',
        ])->assertOk()->assertJsonStructure(['data' => ['token', 'expires_at', 'employee']]);

        $token = $response->json('data.token');
        $this->assertIsString($token);
        $this->assertNotNull(EmployeeAuthToken::findActiveByPlain($token));
        $this->assertNotNull(EmployeeWebCredential::findFor($employee->id, $employee->tenant_id));
        $this->assertNull(ActivationCode::findUsableByCode($code->code));
    }

    public function test_browser_activation_creates_the_account_permissions_hang_off(): void
    {
        // An employee carries permissions through an `admins` row. Creating it
        // on the phone path and not here made an account differ depending on
        // which surface the person first activated on.
        $employee = $this->employee();
        DB::table('employee_web_credentials')->where('employee_id', $employee->id)->delete();
        DB::table('employees')->where('id', $employee->id)->update(['admin_id' => null]);
        $code = $this->activationCode($employee);

        $this->postJson('/v1/auth/employee/web/activate', [
            'phone' => $employee->phone,
            'activation_code' => $code->code,
            'pin' => '481920',
            'device_id' => 'browser-1',
        ])->assertOk();

        $adminId = Value::nullableInt(
            DB::table('employees')->where('id', $employee->id)->value('admin_id')
        );

        $this->assertNotNull($adminId);
        $this->assertDatabaseHas('admins', [
            'id' => $adminId,
            'tenant_id' => $employee->tenant_id,
            'role' => 'employee',
        ]);
        $this->assertDatabaseHas('employees', [
            'id' => $employee->id, 'status' => 'active', 'has_linked_account' => 1,
        ]);
    }

    public function test_a_weak_pin_is_refused_before_the_code_is_spent(): void
    {
        // Burning the code on a rejected PIN would leave the employee unable to
        // activate at all without going back to their administrator.
        $employee = $this->employee();
        DB::table('employee_web_credentials')->where('employee_id', $employee->id)->delete();
        $code = $this->activationCode($employee);

        $this->postJson('/v1/auth/employee/web/activate', [
            'phone' => $employee->phone,
            'activation_code' => $code->code,
            'pin' => '123456',
            'device_id' => 'browser-1',
        ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_pin_format');

        $this->assertNotNull(
            ActivationCode::findUsableByCode($code->code),
            'a rejected PIN must not consume the activation code'
        );
    }

    public function test_a_pin_drawn_from_the_phone_number_is_refused(): void
    {
        $employee = $this->employee();
        DB::table('employee_web_credentials')->where('employee_id', $employee->id)->delete();
        $digits = preg_replace('/\D/', '', (string) $employee->phone) ?? '';

        $this->postJson('/v1/auth/employee/web/activate', [
            'phone' => $employee->phone,
            'activation_code' => $this->activationCode($employee)->code,
            'pin' => substr($digits, -PinPolicy::LENGTH),
            'device_id' => 'browser-1',
        ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_pin_format');
    }

    public function test_activating_twice_is_refused(): void
    {
        $employee = $this->employee();
        DB::table('employee_web_credentials')->where('employee_id', $employee->id)->delete();

        $this->postJson('/v1/auth/employee/web/activate', [
            'phone' => $employee->phone,
            'activation_code' => $this->activationCode($employee)->code,
            'pin' => '481920',
            'device_id' => 'browser-1',
        ])->assertOk();

        $this->postJson('/v1/auth/employee/web/activate', [
            'phone' => $employee->phone,
            'activation_code' => $this->activationCode($employee)->code,
            'pin' => '481920',
            'device_id' => 'browser-1',
        ])->assertStatus(409)->assertJsonPath('error_code', 'already_activated');
    }

    public function test_the_channel_being_off_is_checked_before_the_code_is_spent(): void
    {
        // Burning a code for a company that does not allow the channel would
        // leave the employee unable to activate on their phone either.
        $employee = $this->employee();
        DB::table('employee_web_credentials')->where('employee_id', $employee->id)->delete();
        DB::table('tenants')->where('id', $employee->tenant_id)->update(['web_attendance_enabled' => 0]);
        $code = $this->activationCode($employee);

        $this->postJson('/v1/auth/employee/web/activate', [
            'phone' => $employee->phone,
            'activation_code' => $code->code,
            'pin' => '481920',
            'device_id' => 'browser-1',
        ])->assertForbidden();

        $this->assertNotNull(ActivationCode::findUsableByCode($code->code));
    }

    public function test_a_mismatched_phone_is_refused(): void
    {
        $employee = $this->employee();

        $this->postJson('/v1/auth/employee/web/activate', [
            'phone' => '+201555444333',
            'activation_code' => $this->activationCode($employee)->code,
            'pin' => '481920',
            'device_id' => 'browser-1',
        ])->assertUnauthorized()->assertJsonPath('error_code', 'invalid_activation');
    }
}
