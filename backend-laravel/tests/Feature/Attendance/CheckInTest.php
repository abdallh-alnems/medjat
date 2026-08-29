<?php

declare(strict_types=1);

namespace Tests\Feature\Attendance;

use App\Domain\Time\TenantClock;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Recording an arrival.
 *
 * Most of these assert the *order* of the checks rather than any one check,
 * because the ordering is the part that is easy to break silently: a rearranged
 * pipeline still passes every individual rule while charging an out-of-range
 * employee a rotating code they will need thirty seconds later.
 */
final class CheckInTest extends TestCase
{
    use DatabaseTransactions;

    private const ENDPOINT = '/app/attendance/check_in.php';

    private const BRANCH_LAT = 30.0444;

    private const BRANCH_LNG = 31.2357;

    private Employee $employee;

    private int $branchId;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        $this->employee = Employee::query()
            ->where('status', '!=', 'terminated')
            ->whereNotNull('branch_id')
            ->firstOrFail();

        $this->branchId = (int) $this->employee->branch_id;

        DB::table('branches')->where('id', $this->branchId)->update([
            'latitude' => self::BRANCH_LAT,
            'longitude' => self::BRANCH_LNG,
            'gps_radius_meters' => 100,
            'qr_code' => 'BRANCH-QR',
            'rotating_qr_enabled' => 0,
            'wifi_mode' => null,
        ]);

        DB::table('tenants')->where('id', $this->employee->tenant_id)->update([
            'attendance_methods' => json_encode(['gps_only', 'qr_gps']),
            'require_local_biometric' => 0,
            'reject_mock_location' => 0,
        ]);

        Employee::query()->whereKey($this->employee->id)->update(['attendance_methods' => null]);

        // A clean slate: the row is one-per-day, so a leftover blocks everything.
        DB::table('attendance')
            ->where('employee_id', $this->employee->id)
            ->where('date', TenantClock::date($this->employee->tenant_id))
            ->delete();

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->employee->tenant_id,
            'employee_id' => $this->employee->id,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-a',
        ]);
        $this->token = $plain;
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function punch(array $overrides = []): TestResponse
    {
        return $this->withHeader('X-Employee-Token', $this->token)
            ->postJson(self::ENDPOINT, array_merge([
                'branch_id' => $this->branchId,
                'latitude' => self::BRANCH_LAT,
                'longitude' => self::BRANCH_LNG,
                'method' => 'gps_only',
            ], $overrides));
    }

    public function test_a_punch_inside_the_fence_is_recorded(): void
    {
        $this->punch()
            ->assertOk()
            ->assertJsonPath('data.message', 'Check-in successful')
            ->assertJsonStructure(['data' => ['message', 'time', 'branch']]);

        $this->assertDatabaseHas('attendance', [
            'employee_id' => $this->employee->id,
            'date' => TenantClock::date($this->employee->tenant_id),
            'status' => 'present',
            'check_in_method' => 'gps_only',
        ]);
    }

    public function test_the_time_stamped_is_the_companys_wall_clock(): void
    {
        // Stamping UTC here is the bug that meant no arrival ever counted as
        // late: PHP runs UTC while the shift times are in the company's zone.
        $response = $this->punch()->assertOk();

        $stored = DB::table('attendance')
            ->where('employee_id', $this->employee->id)
            ->where('date', TenantClock::date($this->employee->tenant_id))
            ->value('check_in_time');

        $this->assertSame($response->json('data.time'), Value::string($stored));

        $expected = TenantClock::now($this->employee->tenant_id);
        $actual = strtotime(Value::string($stored));
        $this->assertNotFalse($actual);
        $this->assertLessThan(
            120,
            abs($actual - strtotime($expected->format('H:i:s'))),
            'the stored time must be the company wall clock, not UTC'
        );
    }

    public function test_a_punch_outside_the_fence_is_refused(): void
    {
        $this->punch(['latitude' => 30.10, 'longitude' => 31.30])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'GPS_OUT_OF_RANGE');
    }

    public function test_a_denied_location_reading_is_refused(): void
    {
        // A denied permission arrives as 0,0. Letting that through would mean a
        // QR code alone passes with no location check behind it.
        $this->punch(['latitude' => 0, 'longitude' => 0])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'LOCATION_REQUIRED');
    }

    public function test_a_branch_with_no_coordinates_refuses_rather_than_allows(): void
    {
        // The columns are NOT NULL with a zero default, so an unconfigured
        // branch is 0,0 rather than NULL — which is exactly the value a denied
        // GPS reading also produces, and why it cannot be treated as a location.
        DB::table('branches')->where('id', $this->branchId)
            ->update(['latitude' => 0, 'longitude' => 0]);

        $this->punch()->assertStatus(400)->assertJsonPath('error_code', 'GEOFENCE_NOT_CONFIGURED');
    }

    public function test_a_method_the_company_disabled_is_refused(): void
    {
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['attendance_methods' => json_encode(['qr_gps'])]);

        $this->punch(['method' => 'gps_only'])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'QR_REQUIRED');
    }

    public function test_an_employee_override_beats_the_company_default(): void
    {
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['attendance_methods' => json_encode(['qr_gps'])]);
        Employee::query()->whereKey($this->employee->id)
            ->update(['attendance_methods' => json_encode(['gps_only'])]);

        $this->punch(['method' => 'gps_only'])->assertOk();
    }

    public function test_a_method_that_is_not_self_service_is_refused(): void
    {
        // 'manual' is recorded by an administrator and 'device' by a terminal;
        // neither may be claimed by the employee's own app.
        $this->punch(['method' => 'manual'])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'METHOD_NOT_ALLOWED');
    }

    public function test_a_wrong_printed_qr_is_refused(): void
    {
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['attendance_methods' => json_encode(['qr_gps'])]);

        $this->punch(['method' => 'qr_gps', 'qr_code' => 'SOMEONE-ELSES'])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'INVALID_QR');
    }

    public function test_the_biometric_gate_refuses_before_the_geofence_is_consulted(): void
    {
        // It is the cheapest check on the path and answers the question every
        // other control takes for granted, so it has to come first — including
        // before an out-of-range refusal.
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['require_local_biometric' => 1]);

        $this->punch(['latitude' => 30.10, 'longitude' => 31.30])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'LOCAL_BIOMETRIC_REQUIRED');
    }

    public function test_the_biometric_gate_is_not_enforced_unless_opted_in(): void
    {
        // Older builds never send the field; enforcing by default would lock
        // them all out.
        $this->punch()->assertOk();
    }

    public function test_a_mocked_location_is_refused_before_the_geofence(): void
    {
        // A mocked location invalidates the fence entirely, so evaluating the
        // fence first would be measuring a number the phone chose.
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['reject_mock_location' => 1]);

        $this->punch(['is_mock_location' => 1])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'MOCK_LOCATION');

        $this->assertDatabaseHas('attendance_security_logs', [
            'employee_id' => $this->employee->id,
            'reason' => 'mock_location',
            'action' => 'blocked',
        ]);
    }

    public function test_a_mocked_location_is_allowed_when_the_company_has_not_opted_in(): void
    {
        // iOS never reports the flag at all, so a company that has not chosen
        // this would otherwise be refusing only its Android staff.
        $this->punch(['is_mock_location' => 1])->assertOk();
    }

    public function test_a_rotating_branch_asks_for_the_code_before_checking_the_fence(): void
    {
        // Someone who scanned nothing should be told to look at the screen, not
        // told they are out of range.
        DB::table('branches')->where('id', $this->branchId)->update(['rotating_qr_enabled' => 1]);
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['attendance_methods' => json_encode(['qr_gps'])]);

        $this->punch(['method' => 'qr_gps', 'latitude' => 30.10, 'longitude' => 31.30])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'QR_REQUIRED');
    }

    public function test_an_out_of_range_employee_does_not_burn_a_rotating_code(): void
    {
        // The whole reason the claim happens after the geofence.
        DB::table('branches')->where('id', $this->branchId)->update(['rotating_qr_enabled' => 1]);
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['attendance_methods' => json_encode(['qr_gps'])]);

        $nonce = bin2hex(random_bytes(16));
        DB::insert(
            'INSERT INTO branch_qr_challenges (tenant_id, branch_id, nonce, expires_at)
             VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 60 SECOND))',
            [$this->employee->tenant_id, $this->branchId, $nonce]
        );

        $this->punch([
            'method' => 'qr_gps', 'qr_code' => $nonce,
            'latitude' => 30.10, 'longitude' => 31.30,
        ])->assertStatus(400)->assertJsonPath('error_code', 'GPS_OUT_OF_RANGE');

        $this->assertDatabaseCount('branch_qr_uses', 0);
    }

    public function test_a_rotating_code_cannot_be_spent_twice_by_the_same_person(): void
    {
        DB::table('branches')->where('id', $this->branchId)->update(['rotating_qr_enabled' => 1]);
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['attendance_methods' => json_encode(['qr_gps'])]);

        $nonce = bin2hex(random_bytes(16));
        DB::insert(
            'INSERT INTO branch_qr_challenges (tenant_id, branch_id, nonce, expires_at)
             VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 60 SECOND))',
            [$this->employee->tenant_id, $this->branchId, $nonce]
        );

        $this->punch(['method' => 'qr_gps', 'qr_code' => $nonce])->assertOk();

        // Clear the day so the second attempt fails on the code, not on the
        // duplicate-punch guard.
        DB::table('attendance')->where('employee_id', $this->employee->id)->delete();

        $this->punch(['method' => 'qr_gps', 'qr_code' => $nonce])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'QR_REPLAYED');
    }

    public function test_a_rotating_code_from_another_branch_is_refused(): void
    {
        // Otherwise a company with two sites effectively has one code.
        DB::table('branches')->where('id', $this->branchId)->update(['rotating_qr_enabled' => 1]);
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['attendance_methods' => json_encode(['qr_gps'])]);

        $nonce = bin2hex(random_bytes(16));
        DB::insert(
            'INSERT INTO branch_qr_challenges (tenant_id, branch_id, nonce, expires_at)
             VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 60 SECOND))',
            [$this->employee->tenant_id, $this->otherBranchId(), $nonce]
        );

        $this->punch(['method' => 'qr_gps', 'qr_code' => $nonce])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'QR_EXPIRED');
    }

    public function test_checking_in_twice_in_one_day_is_refused(): void
    {
        $this->punch()->assertOk();
        $this->punch()->assertStatus(400);
    }

    public function test_an_absent_placeholder_row_converts_into_a_real_check_in(): void
    {
        // A row with a NULL check_in_time is the absence cron's placeholder. If
        // it blocked the punch the employee could never check in at all.
        DB::table('attendance')->insert([
            'tenant_id' => $this->employee->tenant_id,
            'employee_id' => $this->employee->id,
            'branch_id' => $this->branchId,
            'date' => TenantClock::date($this->employee->tenant_id),
            'status' => 'absent',
        ]);

        $this->punch()->assertOk();

        $this->assertDatabaseHas('attendance', [
            'employee_id' => $this->employee->id,
            'status' => 'present',
        ]);
    }

    public function test_a_vpn_is_flagged_and_not_blocked(): void
    {
        // Plenty of people run one for ordinary reasons; the pattern is worth
        // seeing rather than punishing.
        $this->punch(['is_vpn' => 1])->assertOk();

        $this->assertDatabaseHas('attendance_security_logs', [
            'employee_id' => $this->employee->id,
            'reason' => 'vpn',
            'action' => 'flagged',
        ]);
    }

    public function test_the_channel_is_taken_from_the_session_not_the_body(): void
    {
        // A body field could otherwise make a browser punch present itself as an
        // app punch and slip past a company that restricted the channel.
        $this->punch(['platform' => 'web', 'origin' => 'app'])->assertOk();

        $this->assertSame(
            'app',
            Value::string(DB::table('attendance')
                ->where('employee_id', $this->employee->id)
                ->where('date', TenantClock::date($this->employee->tenant_id))
                ->value('check_in_origin')),
            'the recorded origin must come from the token, not the payload'
        );
    }

    /** A genuinely different branch: branch_qr_challenges has a foreign key. */
    private function otherBranchId(): int
    {
        return (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->employee->tenant_id,
            'name' => 'Other branch',
            'latitude' => 29.0,
            'longitude' => 30.0,
        ]);
    }
}
