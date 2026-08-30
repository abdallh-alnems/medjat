<?php

declare(strict_types=1);

namespace Tests\Feature\Attendance;

use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Recording a departure.
 *
 * The theme throughout is that every control guarding the arrival is repeated
 * here. A control applied only on the way in is a control an employee can walk
 * away from, so most of these tests exist to catch a check quietly living on
 * check-in alone.
 */
final class CheckOutTest extends TestCase
{
    use DatabaseTransactions;

    private const ENDPOINT = '/app/attendance/check_out.php';

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
            'latitude' => 30.0444, 'longitude' => 31.2357, 'gps_radius_meters' => 100,
            'rotating_qr_enabled' => 0, 'wifi_mode' => null,
        ]);

        DB::table('tenants')->where('id', $this->employee->tenant_id)->update([
            'attendance_methods' => json_encode(['gps_only']),
            'require_local_biometric' => 0,
            'reject_mock_location' => 0,
            'web_attendance_enabled' => 1,
            // Evidence is on by default for the browser channel, which is right
            // but not what these cases are about — the photo rule has its own
            // test above.
            'web_attendance_photo_required' => 0,
        ]);

        Employee::query()->whereKey($this->employee->id)->update(['attendance_methods' => null]);

        $this->openTheDay();
        $this->token = $this->issueToken('android');
    }

    private function openTheDay(): void
    {
        $tenantId = $this->employee->tenant_id;
        $today = TenantClock::date($tenantId);

        DB::table('attendance')->where('employee_id', $this->employee->id)->where('date', $today)->delete();
        DB::table('attendance')->insert([
            'tenant_id' => $tenantId,
            'employee_id' => $this->employee->id,
            'branch_id' => $this->branchId,
            'date' => $today,
            // Midnight rather than a plausible-looking 09:00: check-out stamps
            // the tenant's current time, so a fixed morning arrival makes the
            // worked span negative — and the assertion below fail — whenever
            // the suite happens to run before 09:00 local time.
            'check_in_time' => '00:00:00',
            'check_in_method' => 'gps_only',
            'check_in_origin' => 'app',
            'status' => 'present',
        ]);
    }

    private function issueToken(string $platform): string
    {
        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->employee->tenant_id,
            'employee_id' => $this->employee->id,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => $platform,
            'device_id' => 'device-'.$platform,
        ]);

        return $plain;
    }

    /**
     * @param  array<string, mixed>  $body
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function punch(array $body = [], ?string $token = null): TestResponse
    {
        return $this->withHeader('X-Employee-Token', $token ?? $this->token)
            ->postJson(self::ENDPOINT, $body);
    }

    public function test_an_open_day_is_closed(): void
    {
        $this->punch()
            ->assertOk()
            ->assertJsonPath('data.message', 'Check-out successful')
            ->assertJsonStructure(['data' => ['message', 'time', 'cancelled_breaks', 'session_ended']]);

        $row = DB::table('attendance')
            ->where('employee_id', $this->employee->id)
            ->where('date', TenantClock::date($this->employee->tenant_id))
            ->first();

        $this->assertNotNull($row);
        $this->assertNotNull($row->check_out_time);

        // The span is derived from the two stamps, not left at zero.
        $checkOut = strtotime(Value::string($row->check_out_time));
        $this->assertNotFalse($checkOut);
        $this->assertSame(
            (int) max(0, ($checkOut - strtotime('00:00:00')) / 60),
            Value::int($row->worked_minutes),
        );
    }

    public function test_closing_a_day_that_was_never_opened_is_refused(): void
    {
        DB::table('attendance')
            ->where('employee_id', $this->employee->id)
            ->where('date', TenantClock::date($this->employee->tenant_id))
            ->delete();

        $this->punch()->assertNotFound();
    }

    public function test_a_placeholder_row_with_no_arrival_cannot_be_closed(): void
    {
        DB::table('attendance')
            ->where('employee_id', $this->employee->id)
            ->where('date', TenantClock::date($this->employee->tenant_id))
            ->update(['check_in_time' => null, 'status' => 'absent']);

        $this->punch()->assertNotFound();
    }

    public function test_a_mocked_location_is_refused_on_the_way_out_too(): void
    {
        // Enforcing on arrival only would leave the hole half open: arrive
        // legitimately, then clock out from home on a spoofed location.
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['reject_mock_location' => 1]);

        $this->punch(['is_mock_location' => 1])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'MOCK_LOCATION');
    }

    public function test_the_biometric_gate_applies_on_the_way_out_too(): void
    {
        // Otherwise a colleague could clock someone out.
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['require_local_biometric' => 1]);

        $this->punch()
            ->assertForbidden()
            ->assertJsonPath('error_code', 'LOCAL_BIOMETRIC_REQUIRED');
    }

    public function test_an_employee_whose_only_method_is_face_cannot_leave_with_an_empty_body(): void
    {
        // Without this clause, sending nothing at all would step around the face
        // check entirely.
        Employee::query()->whereKey($this->employee->id)
            ->update(['attendance_methods' => json_encode(['face_selfie'])]);

        $this->punch()
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'FACE_REQUIRED');
    }

    public function test_an_employee_whose_only_method_is_a_photo_cannot_leave_without_one(): void
    {
        Employee::query()->whereKey($this->employee->id)
            ->update(['attendance_methods' => json_encode(['photo_gps'])]);

        $this->punch()
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'PHOTO_REQUIRED');
    }

    public function test_a_rotating_branch_requires_a_code_on_the_way_out(): void
    {
        // A colleague holding a forwarded screenshot could otherwise close
        // someone's day.
        DB::table('branches')->where('id', $this->branchId)->update(['rotating_qr_enabled' => 1]);
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['attendance_methods' => json_encode(['qr_gps'])]);

        $this->punch(['method' => 'qr_gps'])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'QR_REQUIRED');
    }

    public function test_leaving_uses_a_separate_claim_from_arriving(): void
    {
        // Arriving and leaving inside one code's window is unusual but
        // legitimate; refusing it would mean a short errand costs the day.
        DB::table('branches')->where('id', $this->branchId)->update(['rotating_qr_enabled' => 1]);
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['attendance_methods' => json_encode(['qr_gps'])]);

        $nonce = bin2hex(random_bytes(16));
        DB::insert(
            'INSERT INTO branch_qr_challenges (tenant_id, branch_id, nonce, expires_at)
             VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 90 SECOND))',
            [$this->employee->tenant_id, $this->branchId, $nonce]
        );
        DB::table('branch_qr_uses')->insert([
            'challenge_id' => DB::table('branch_qr_challenges')->where('nonce', $nonce)->value('id'),
            'employee_id' => $this->employee->id,
            'purpose' => 'check_in',
        ]);

        $this->punch(['method' => 'qr_gps', 'qr_code' => $nonce])->assertOk();
    }

    public function test_a_browser_check_out_ends_every_browser_session(): void
    {
        // A shared office computer has to be left safe by the system, not by the
        // person walking out remembering a button.
        $web = $this->issueToken('web');

        $this->punch([], $web)->assertOk()->assertJsonPath('data.session_ended', true);

        $this->assertNull(EmployeeAuthToken::findActiveByPlain($web));
    }

    public function test_a_browser_check_out_leaves_the_phone_session_alone(): void
    {
        $web = $this->issueToken('web');

        $this->punch([], $web)->assertOk();

        $this->assertNotNull(EmployeeAuthToken::findActiveByPlain($this->token));
    }

    public function test_a_company_that_disables_the_channel_mid_shift_can_still_close_the_day(): void
    {
        // Refusing would leave an open row only an administrator can fix, so a
        // settings change would cost the employee their hours.
        $web = $this->issueToken('web');
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['web_attendance_enabled' => 0]);

        $this->punch([], $web)->assertOk();

        $this->assertDatabaseHas('attendance_security_logs', [
            'employee_id' => $this->employee->id,
            'reason' => 'web_not_permitted',
            'action' => 'flagged',
        ]);
    }

    public function test_a_disabled_channel_refuses_when_there_is_no_open_day(): void
    {
        $web = $this->issueToken('web');
        DB::table('attendance')
            ->where('employee_id', $this->employee->id)
            ->where('date', TenantClock::date($this->employee->tenant_id))
            ->update(['check_out_time' => '17:00:00']);
        DB::table('tenants')->where('id', $this->employee->tenant_id)
            ->update(['web_attendance_enabled' => 0]);

        $this->punch([], $web)->assertForbidden();
    }

    public function test_pending_permissions_are_cancelled_on_the_way_out(): void
    {
        DB::table('break_requests')->insert([
            'tenant_id' => $this->employee->tenant_id,
            'employee_id' => $this->employee->id,
            'date' => TenantClock::date($this->employee->tenant_id),
            'start_time' => '12:00:00',
            'end_time' => '12:30:00',
            'status' => 'pending',
        ]);

        $this->punch()->assertOk()->assertJsonPath('data.cancelled_breaks', 1);

        $this->assertDatabaseHas('break_requests', [
            'employee_id' => $this->employee->id,
            'status' => 'cancelled',
        ]);
    }
}
