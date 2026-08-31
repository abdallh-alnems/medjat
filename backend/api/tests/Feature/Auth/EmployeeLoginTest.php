<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\ActivationCode;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\CreatesFixtures;
use Tests\TestCase;

/**
 * Sign-in with a phone number and a single-use activation code.
 *
 * Every case here was previously only reachable by installing the app on a
 * handset and typing a real code.
 */
final class EmployeeLoginTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    private const ENDPOINT = '/v1/auth/employee/login';

    /**
     * A sign-in candidate needs a phone number: not every employee row has one,
     * because a record can be created by an administrator long before the person
     * is given app access.
     */
    private function employee(): Employee
    {
        return $this->createEmployee($this->createTenant(), ['phone' => $this->uniquePhone()]);
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

    public function test_a_valid_code_issues_a_token_and_returns_the_employee(): void
    {
        $employee = $this->employee();
        $code = $this->activationCode($employee);

        $response = $this->postJson(self::ENDPOINT, [
            'phone' => $employee->phone,
            'activation_code' => $code->code,
            'device_id' => 'device-a',
            'platform' => 'android',
        ]);

        $response->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.success', true)
            ->assertJsonPath('data.employee.id', $employee->id)
            ->assertJsonStructure(['data' => ['token', 'employee' => [
                'id', 'name', 'phone', 'tenant_id', 'tenant_name',
                'branch_id', 'branch_name', 'job_title', 'profile_image',
            ]]]);

        $token = $response->json('data.token');
        $this->assertIsString($token);
        $this->assertNotNull(EmployeeAuthToken::findActiveByPlain($token));
    }

    public function test_signing_in_consumes_the_code(): void
    {
        $employee = $this->employee();
        $code = $this->activationCode($employee);

        $this->postJson(self::ENDPOINT, [
            'phone' => $employee->phone,
            'activation_code' => $code->code,
            'device_id' => 'device-a',
        ])->assertOk();

        $this->assertNull(
            ActivationCode::findUsableByCode($code->code),
            'an activation code is single-use'
        );

        $this->assertSame(
            'device:device-a',
            DB::table('employee_activation_codes')->where('id', $code->id)->value('used_by_firebase_uid')
        );
    }

    public function test_the_same_code_cannot_be_used_twice(): void
    {
        $employee = $this->employee();
        $code = $this->activationCode($employee);
        $payload = ['phone' => $employee->phone, 'activation_code' => $code->code, 'device_id' => 'device-a'];

        $this->postJson(self::ENDPOINT, $payload)->assertOk();

        $this->postJson(self::ENDPOINT, $payload)
            ->assertNotFound()
            ->assertJsonPath('error_code', 'activation_code_invalid');
    }

    public function test_an_expired_code_is_refused(): void
    {
        $employee = $this->employee();
        $code = $this->activationCode($employee, ['expires_at' => now()->subMinute()]);

        $this->postJson(self::ENDPOINT, [
            'phone' => $employee->phone,
            'activation_code' => $code->code,
            'device_id' => 'device-a',
        ])->assertNotFound()->assertJsonPath('error_code', 'activation_code_invalid');
    }

    public function test_a_code_belonging_to_someone_else_is_refused(): void
    {
        $employee = $this->employee();
        $other = $this->createEmployee((int) $employee->tenant_id);

        // Give the other employee an unmistakably different number: the guard
        // compares the tail of the significant digits, so "different" has to
        // mean different, not merely differently formatted.
        Employee::query()->whereKey($other->id)->update(['phone' => '+201999888777']);
        $other->refresh();

        $code = $this->activationCode($other);

        $this->postJson(self::ENDPOINT, [
            'phone' => $employee->phone,
            'activation_code' => $code->code,
            'device_id' => 'device-a',
        ])->assertForbidden()->assertJsonPath('error_code', 'phone_code_mismatch');
    }

    public function test_a_locally_typed_phone_number_still_matches(): void
    {
        // Stored as +201023809407, typed as 01023809407. Rejecting this would
        // fail a correct code over formatting.
        $employee = $this->employee();
        $code = $this->activationCode($employee);
        $local = '0'.ltrim(preg_replace('/\D/', '', (string) $employee->phone) ?? '', '0');
        $local = '0'.substr($local, -10);

        $this->postJson(self::ENDPOINT, [
            'phone' => $local,
            'activation_code' => $code->code,
            'device_id' => 'device-a',
        ])->assertOk();
    }

    public function test_missing_fields_are_refused_before_any_lookup(): void
    {
        $this->postJson(self::ENDPOINT, ['phone' => '', 'activation_code' => '', 'device_id' => ''])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'missing_fields');
    }

    public function test_a_terminated_employee_cannot_sign_in(): void
    {
        $employee = $this->employee();
        $code = $this->activationCode($employee);
        Employee::query()->whereKey($employee->id)->update(['status' => 'terminated']);

        $this->postJson(self::ENDPOINT, [
            'phone' => $employee->phone,
            'activation_code' => $code->code,
            'device_id' => 'device-a',
        ])->assertForbidden()->assertJsonPath('error_code', 'account_suspended');
    }

    public function test_signing_in_again_ends_the_previous_phone_session(): void
    {
        $employee = $this->employee();

        $first = $this->postJson(self::ENDPOINT, [
            'phone' => $employee->phone,
            'activation_code' => $this->activationCode($employee)->code,
            'device_id' => 'device-a',
        ])->json('data.token');

        $second = $this->postJson(self::ENDPOINT, [
            'phone' => $employee->phone,
            'activation_code' => $this->activationCode($employee)->code,
            'device_id' => 'device-b',
        ])->json('data.token');

        $this->assertIsString($first);
        $this->assertIsString($second);
        $this->assertNull(EmployeeAuthToken::findActiveByPlain($first), 'the old device must be signed out');
        $this->assertNotNull(EmployeeAuthToken::findActiveByPlain($second));
    }

    public function test_a_phone_login_does_not_end_a_browser_session(): void
    {
        // The two channels are independent sessions for the same person;
        // signing in on a handset must not evict the browser.
        $employee = $this->employee();
        $web = EmployeeAuthToken::issueWeb($employee->tenant_id, $employee->id, 'browser-1', 3600);

        $this->postJson(self::ENDPOINT, [
            'phone' => $employee->phone,
            'activation_code' => $this->activationCode($employee)->code,
            'device_id' => 'device-a',
        ])->assertOk();

        $this->assertNotNull(EmployeeAuthToken::findActiveByPlain($web['token']));
    }

    public function test_signing_in_activates_the_employee_and_links_the_account(): void
    {
        $employee = $this->employee();
        // The state a new hire is in before they ever open the app.
        Employee::query()->whereKey($employee->id)
            ->update(['has_linked_account' => 0, 'status' => 'pending_activation']);

        $this->postJson(self::ENDPOINT, [
            'phone' => $employee->phone,
            'activation_code' => $this->activationCode($employee)->code,
            'device_id' => 'device-a',
        ])->assertOk();

        $row = DB::table('employees')->where('id', $employee->id)->first();
        $this->assertNotNull($row);
        $this->assertSame('active', $row->status);
        $this->assertEquals(1, $row->has_linked_account);
        $this->assertNotNull($row->admin_id, 'an employee must end up with an admins row for permission checks');
    }

    public function test_an_unknown_platform_falls_back_to_android(): void
    {
        $employee = $this->employee();

        $token = $this->postJson(self::ENDPOINT, [
            'phone' => $employee->phone,
            'activation_code' => $this->activationCode($employee)->code,
            'device_id' => 'device-a',
            'platform' => 'windows-phone',
        ])->assertOk()->json('data.token');

        $this->assertIsString($token);
        $this->assertSame(
            'android',
            DB::table('employee_auth_tokens')
                ->where('token_hash', EmployeeAuthToken::hash($token))->value('platform')
        );
    }
}
