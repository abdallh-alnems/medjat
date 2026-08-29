<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Models\EmployeeWebCredential;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Browser sign-in with phone and PIN.
 *
 * The security properties are the point here: a six-digit secret is only safe
 * because of the lockout and because the endpoint refuses to say which half of
 * the credential was wrong.
 */
final class EmployeeWebLoginTest extends TestCase
{
    use DatabaseTransactions;

    private const ENDPOINT = '/app/auth/employee_web_login.php';

    protected function setUp(): void
    {
        parent::setUp();

        // The per-phone limiter is keyed on the number, so attempts would carry
        // between tests otherwise.
        RateLimiter::clear('web_login:201000000000');
    }

    private function employee(): Employee
    {
        $employee = Employee::query()
            ->where('status', '!=', 'terminated')
            ->whereNotNull('phone')
            ->where('phone', '!=', '')
            ->firstOrFail();

        // The channel ships switched off per company; these tests are about the
        // credential, so turn it on for this one.
        DB::table('tenants')->where('id', $employee->tenant_id)->update(['web_attendance_enabled' => 1]);

        return $employee;
    }

    private function givePin(Employee $employee, string $pin = '481920'): void
    {
        DB::table('employee_web_credentials')->where('employee_id', $employee->id)->delete();

        EmployeeWebCredential::query()->create([
            'tenant_id' => $employee->tenant_id,
            'employee_id' => $employee->id,
            // Cheapest rounds: bcrypt at the default cost dominates the runtime
            // of this file, and nothing here is testing the hash itself.
            'pin_hash' => password_hash($pin, PASSWORD_BCRYPT, ['cost' => 4]),
            'failed_attempts' => 0,
            'pin_set_at' => now(),
        ]);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function attempt(Employee $employee, array $overrides = []): TestResponse
    {
        return $this->postJson(self::ENDPOINT, array_merge([
            'phone' => $employee->phone,
            'pin' => '481920',
            'device_id' => 'browser-1',
        ], $overrides));
    }

    public function test_a_correct_pin_issues_an_expiring_browser_session(): void
    {
        $employee = $this->employee();
        $this->givePin($employee);

        $response = $this->attempt($employee)
            ->assertOk()
            ->assertJsonPath('data.employee.id', $employee->id)
            ->assertJsonStructure(['data' => ['token', 'expires_at', 'employee' => [
                'id', 'name', 'branch_id', 'branch_name', 'tenant_name',
            ]]]);

        $token = $response->json('data.token');
        $this->assertIsString($token);
        $this->assertNotNull(EmployeeAuthToken::findActiveByPlain($token));

        $this->assertNotNull(
            $response->json('data.expires_at'),
            'a browser session expires; a session left open on a shared branch computer must not last'
        );
    }

    public function test_a_browser_session_does_not_end_the_phone_session(): void
    {
        $employee = $this->employee();
        $this->givePin($employee);

        $phone = EmployeeAuthToken::issue($employee->tenant_id, $employee->id, 'handset', null, 'android', null);

        $this->attempt($employee)->assertOk();

        $this->assertNotNull(
            EmployeeAuthToken::findActiveByPlain($phone),
            'using a computer once must not sign someone out of their phone'
        );
    }

    public function test_a_second_browser_sign_in_ends_the_first(): void
    {
        $employee = $this->employee();
        $this->givePin($employee);

        $first = $this->attempt($employee)->json('data.token');
        $second = $this->attempt($employee)->json('data.token');

        $this->assertIsString($first);
        $this->assertIsString($second);
        $this->assertNull(EmployeeAuthToken::findActiveByPlain($first));
        $this->assertNotNull(EmployeeAuthToken::findActiveByPlain($second));
    }

    public function test_a_wrong_pin_and_an_unknown_phone_are_indistinguishable(): void
    {
        // Telling them apart would make this an oracle for which numbers are
        // enrolled, which is worth more than any single PIN.
        $employee = $this->employee();
        $this->givePin($employee);

        $wrongPin = $this->attempt($employee, ['pin' => '999999']);
        $unknownPhone = $this->attempt($employee, ['phone' => '+201555444333']);

        $wrongPin->assertUnauthorized()->assertJsonPath('error_code', 'invalid_credentials');
        $unknownPhone->assertUnauthorized()->assertJsonPath('error_code', 'invalid_credentials');
        $this->assertSame($wrongPin->json('message'), $unknownPhone->json('message'));
    }

    public function test_an_employee_who_never_set_a_pin_is_told_so(): void
    {
        // Distinct from invalid_credentials on purpose: "check your PIN" sends
        // a first-time user in a circle.
        $employee = $this->employee();
        DB::table('employee_web_credentials')->where('employee_id', $employee->id)->delete();

        $this->attempt($employee)
            ->assertNotFound()
            ->assertJsonPath('error_code', 'not_activated');
    }

    public function test_the_account_locks_on_the_fifth_wrong_pin_not_the_fourth(): void
    {
        // Counting the attempts is the only way this is checked. Doing the
        // increment and the lock decision in one UPDATE locks an attempt early,
        // because MySQL's later SET expressions see the already-updated column.
        $employee = $this->employee();
        $this->givePin($employee);

        for ($attempt = 1; $attempt <= EmployeeWebCredential::MAX_FAILED_ATTEMPTS - 1; $attempt++) {
            $this->attempt($employee, ['pin' => '999999'])
                ->assertUnauthorized()
                ->assertJsonPath('error_code', 'invalid_credentials');
        }

        $this->assertFalse(
            EmployeeWebCredential::isLocked($employee->id),
            'four wrong attempts must not lock the account'
        );

        $this->attempt($employee, ['pin' => '999999'])
            ->assertStatus(423)
            ->assertJsonPath('error_code', 'web_pin_locked');

        $this->assertTrue(EmployeeWebCredential::isLocked($employee->id));
    }

    public function test_a_locked_account_is_refused_even_with_the_correct_pin(): void
    {
        $employee = $this->employee();
        $this->givePin($employee);
        $this->lockAccount($employee);

        $this->attempt($employee)->assertStatus(423)->assertJsonPath('error_code', 'web_pin_locked');
    }

    public function test_a_lockout_is_recorded_as_a_security_event(): void
    {
        // A blocked attempt that leaves no trace is indistinguishable from one
        // that never happened.
        $employee = $this->employee();
        $this->givePin($employee);
        $this->lockAccount($employee);

        $this->attempt($employee)->assertStatus(423);

        $this->assertDatabaseHas('attendance_security_logs', [
            'employee_id' => $employee->id,
            'reason' => 'web_pin_locked',
            'action' => 'blocked',
        ]);
    }

    public function test_a_successful_sign_in_clears_the_failure_counter(): void
    {
        $employee = $this->employee();
        $this->givePin($employee);

        $this->attempt($employee, ['pin' => '999999'])->assertUnauthorized();
        $this->attempt($employee)->assertOk();

        $this->assertSame(
            0,
            Value::int(DB::table('employee_web_credentials')->where('employee_id', $employee->id)->value('failed_attempts'))
        );
    }

    public function test_the_channel_being_switched_off_is_only_revealed_after_the_pin(): void
    {
        // Refusing before the PIN would let anyone enumerate which companies
        // have the channel enabled.
        $employee = $this->employee();
        $this->givePin($employee);
        DB::table('tenants')->where('id', $employee->tenant_id)->update(['web_attendance_enabled' => 0]);

        $this->attempt($employee, ['pin' => '999999'])
            ->assertUnauthorized()
            ->assertJsonPath('error_code', 'invalid_credentials');

        $this->attempt($employee)
            ->assertForbidden()
            ->assertJsonPath('error_code', 'WEB_NOT_PERMITTED');
    }

    public function test_a_terminated_employee_cannot_sign_in(): void
    {
        $employee = $this->employee();
        $this->givePin($employee);
        Employee::query()->whereKey($employee->id)->update(['status' => 'terminated']);

        $this->attempt($employee)->assertForbidden()->assertJsonPath('error_code', 'account_suspended');
    }

    public function test_missing_fields_are_refused(): void
    {
        $this->postJson(self::ENDPOINT, ['phone' => '', 'pin' => '', 'device_id' => ''])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'missing_fields');
    }

    public function test_logout_ends_the_browser_session(): void
    {
        $employee = $this->employee();
        $this->givePin($employee);
        $token = $this->attempt($employee)->json('data.token');
        $this->assertIsString($token);

        $this->withHeader('X-Employee-Token', $token)
            ->postJson('/app/auth/employee_web_logout.php')
            ->assertOk();

        $this->assertNull(EmployeeAuthToken::findActiveByPlain($token));
    }

    public function test_logout_without_a_session_still_succeeds(): void
    {
        $this->postJson('/app/auth/employee_web_logout.php')->assertOk();
    }

    /**
     * Locks the credential the way the application does — in SQL.
     *
     * Writing a PHP-computed timestamp here produces a lock that is already
     * expired: PHP runs UTC while MySQL runs the server's zone, so "fifteen
     * minutes from now" lands in the database's past and the account reads as
     * unlocked. The production path uses DATE_ADD(NOW(), ...) for this reason,
     * and a test that cheats around it proves nothing.
     */
    private function lockAccount(Employee $employee): void
    {
        DB::update(
            'UPDATE employee_web_credentials
                SET locked_until = DATE_ADD(NOW(), INTERVAL 900 SECOND), failed_attempts = ?
              WHERE employee_id = ?',
            [EmployeeWebCredential::MAX_FAILED_ATTEMPTS, $employee->id]
        );
    }
}
