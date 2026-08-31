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
use Tests\Support\CreatesFixtures;
use Tests\TestCase;

/**
 * The crew batch and the offline queue.
 *
 * The crew endpoint is the only place an employee credential writes somebody
 * else's rows, so most of these are about the four things that bound it. The
 * offline queue is the least trustworthy input the system takes, so most of
 * those are about what it refuses.
 */
final class CrewAndOfflineTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    private const BRANCH_LAT = 30.0444;

    private const BRANCH_LNG = 31.2357;

    private Employee $supervisor;

    private Employee $member;

    private int $branchId;

    private int $tenantId;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        $this->supervisor = $this->createEmployee($this->createTenant());

        $this->branchId = (int) $this->supervisor->branch_id;
        $this->tenantId = $this->supervisor->tenant_id;

        $this->member = $this->createEmployee($this->tenantId);

        Employee::query()->whereKey($this->member->id)->update([
            'crew_supervisor_id' => $this->supervisor->id,
            'status' => 'active',
            'work_start_time' => '09:00:00',
            'work_end_time' => '17:00:00',
        ]);

        DB::table('branches')->where('id', $this->branchId)->update([
            'latitude' => self::BRANCH_LAT, 'longitude' => self::BRANCH_LNG,
            'gps_radius_meters' => 100, 'qr_code' => 'BRANCH-QR',
        ]);

        DB::table('tenants')->where('id', $this->tenantId)->update([
            'attendance_methods' => json_encode(['gps_only', 'crew_gps']),
            'reject_mock_location' => 0,
            'crew_photo_required' => 0,
        ]);

        Employee::query()->whereKey($this->supervisor->id)->update(['attendance_methods' => null]);

        $today = TenantClock::date($this->tenantId);
        DB::table('attendance')->whereIn('employee_id', [$this->supervisor->id, $this->member->id])
            ->where('date', $today)->delete();

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->supervisor->id,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-a',
        ]);
        $this->token = $plain;
    }

    /**
     * @param  array<string, mixed>  $body
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function crew(array $body = []): TestResponse
    {
        return $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/crew/punch', array_merge([
                'employee_ids' => [$this->member->id],
                'latitude' => self::BRANCH_LAT,
                'longitude' => self::BRANCH_LNG,
            ], $body));
    }

    // ── Crew ─────────────────────────────────────────────────────────────

    public function test_a_supervisor_records_their_crew(): void
    {
        $this->crew()->assertOk()->assertJsonPath('data.count', 1);

        $this->assertDatabaseHas('attendance', [
            'employee_id' => $this->member->id,
            'date' => TenantClock::date($this->tenantId),
            'check_in_method' => 'crew_gps',
            'recorded_by_employee_id' => $this->supervisor->id,
        ]);
    }

    public function test_a_name_that_is_not_theirs_refuses_the_whole_batch(): void
    {
        // Quietly recording the rest would leave the supervisor believing all of
        // them were marked. Telling them costs one retry; the silent version
        // costs somebody a day's pay.
        $outsider = $this->createEmployee($this->tenantId);

        Employee::query()->whereKey($outsider->id)->update(['crew_supervisor_id' => null]);

        $this->crew(['employee_ids' => [$this->member->id, $outsider->id]])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'CREW_NOT_SUPERVISOR');

        $this->assertDatabaseMissing('attendance', [
            'employee_id' => $this->member->id,
            'date' => TenantClock::date($this->tenantId),
            'check_in_method' => 'crew_gps',
        ]);
    }

    public function test_an_unauthorised_target_is_recorded_as_a_security_event(): void
    {
        $outsider = $this->createEmployee($this->tenantId);

        Employee::query()->whereKey($outsider->id)->update(['crew_supervisor_id' => null]);

        $this->crew(['employee_ids' => [$outsider->id]])->assertForbidden();

        $this->assertDatabaseHas('attendance_security_logs', [
            'employee_id' => $outsider->id,
            'reason' => 'crew_not_supervisor',
            'action' => 'blocked',
        ]);
    }

    public function test_an_oversized_batch_is_refused(): void
    {
        // A foreman's crew is tens of people; the cap stops a malformed body
        // turning one request into an unbounded write.
        $this->crew(['employee_ids' => range(1, 201)])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'CREW_TOO_LARGE');
    }

    public function test_an_empty_batch_is_refused(): void
    {
        $this->crew(['employee_ids' => []])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'CREW_EMPTY');
    }

    public function test_a_supervisor_without_the_method_is_refused(): void
    {
        DB::table('tenants')->where('id', $this->tenantId)
            ->update(['attendance_methods' => json_encode(['gps_only'])]);

        $this->crew()->assertForbidden()->assertJsonPath('error_code', 'METHOD_NOT_ALLOWED');
    }

    public function test_the_batch_is_geofenced_on_the_supervisors_fix(): void
    {
        $this->crew(['latitude' => 30.5, 'longitude' => 31.9])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'GPS_OUT_OF_RANGE');
    }

    public function test_check_out_is_not_geofenced(): void
    {
        // A crew that has moved off site by knocking-off time should not be
        // left stranded clocked in.
        $this->crew()->assertOk();

        $this->crew(['is_check_out' => true, 'latitude' => 30.5, 'longitude' => 31.9])
            ->assertOk()
            ->assertJsonPath('data.count', 1);
    }

    public function test_someone_already_marked_is_skipped_with_a_reason(): void
    {
        // So the app can say "28 recorded, 2 already marked" rather than a bare
        // success that hides what did not happen.
        $this->crew()->assertOk();

        $this->crew()
            ->assertOk()
            ->assertJsonPath('data.count', 0)
            ->assertJsonPath('data.skipped.'.$this->member->id, 'already_checked_in');
    }

    public function test_a_photo_is_captured_before_anything_is_written(): void
    {
        // Otherwise a company that asked for one ends up with thirty rows and no
        // picture.
        DB::table('tenants')->where('id', $this->tenantId)->update(['crew_photo_required' => 1]);

        $this->crew()->assertStatus(422)->assertJsonPath('error_code', 'PHOTO_REQUIRED');

        $this->assertDatabaseMissing('attendance', [
            'employee_id' => $this->member->id,
            'date' => TenantClock::date($this->tenantId),
            'check_in_method' => 'crew_gps',
        ]);
    }

    // ── Offline queue ────────────────────────────────────────────────────

    /**
     * @param  array<string, mixed>  $overrides
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function sync(array $overrides = []): TestResponse
    {
        return $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/sync-offline', ['records' => [array_merge([
                'client_record_id' => 'r1',
                'branch_id' => $this->branchId,
                'date' => TenantClock::date($this->tenantId),
                'captured_at' => TenantClock::now($this->tenantId)->format('Y-m-d H:i:s'),
                'check_in_time' => '09:00:00',
                'check_in_latitude' => self::BRANCH_LAT,
                'check_in_longitude' => self::BRANCH_LNG,
            ], $overrides)]]);
    }

    public function test_a_queued_punch_is_accepted_and_marked_offline(): void
    {
        $this->sync()->assertOk()->assertJsonPath('data.synced', 1);

        $this->assertDatabaseHas('attendance', [
            'employee_id' => $this->supervisor->id,
            'date' => TenantClock::date($this->tenantId),
            'check_in_method' => 'offline',
            'is_offline' => 1,
        ]);
    }

    public function test_the_geofence_is_evaluated_again_on_arrival(): void
    {
        // The phone verified nothing anybody can see.
        $this->sync(['check_in_latitude' => 30.5, 'check_in_longitude' => 31.9])
            ->assertOk()
            ->assertJsonPath('data.failed', 1)
            ->assertJsonPath('data.results.0.reason', 'GPS_OUT_OF_RANGE');
    }

    public function test_a_future_timestamp_is_refused(): void
    {
        // The phone chose it offline: a future one is a wrong clock or an
        // attempt to book tomorrow's shift today.
        $this->sync(['captured_at' => TenantClock::now($this->tenantId)->modify('+2 hours')->format('Y-m-d H:i:s')])
            ->assertOk()
            ->assertJsonPath('data.results.0.reason', 'FUTURE_DATE');
    }

    public function test_a_stale_queue_is_dropped_rather_than_back_dated(): void
    {
        $this->sync(['captured_at' => TenantClock::now($this->tenantId)->modify('-3 days')->format('Y-m-d H:i:s')])
            ->assertOk()
            ->assertJsonPath('data.results.0.reason', 'EXPIRED');
    }

    public function test_a_spoofed_location_is_refused_and_recorded(): void
    {
        $this->sync(['is_mock_location' => 1])
            ->assertOk()
            ->assertJsonPath('data.results.0.reason', 'MOCK_LOCATION');

        $this->assertDatabaseHas('attendance_security_logs', [
            'employee_id' => $this->supervisor->id,
            'reason' => 'mock_location',
            'action' => 'blocked',
        ]);
    }

    public function test_an_online_punch_for_the_same_day_wins(): void
    {
        // The online one was verified as it happened; the queued one was not.
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->supervisor->id,
            'branch_id' => $this->branchId,
            'date' => TenantClock::date($this->tenantId),
            'check_in_time' => '08:30:00',
            'status' => 'present',
            'is_offline' => 0,
        ]);

        $this->sync()->assertOk()->assertJsonPath('data.results.0.reason', 'ONLINE_EXISTS');

        $this->assertSame('08:30:00', DB::table('attendance')
            ->where('employee_id', $this->supervisor->id)
            ->where('date', TenantClock::date($this->tenantId))
            ->value('check_in_time'));
    }

    public function test_one_bad_record_does_not_fail_the_batch(): void
    {
        // A queue is a whole day's punches from a phone that has finally found
        // signal; refusing all of them because one is malformed strands the
        // rest.
        $today = TenantClock::date($this->tenantId);

        $response = $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/sync-offline', ['records' => [
                ['client_record_id' => 'bad', 'branch_id' => 0],
                [
                    'client_record_id' => 'good',
                    'branch_id' => $this->branchId,
                    'date' => $today,
                    'captured_at' => TenantClock::now($this->tenantId)->format('Y-m-d H:i:s'),
                    'check_in_time' => '09:00:00',
                    'check_in_latitude' => self::BRANCH_LAT,
                    'check_in_longitude' => self::BRANCH_LNG,
                ],
            ]]);

        $response->assertOk()
            ->assertJsonPath('data.synced', 1)
            ->assertJsonPath('data.failed', 1)
            ->assertJsonPath('data.results.0.reason', 'INVALID_BRANCH')
            ->assertJsonPath('data.results.1.status', 'synced');
    }

    public function test_an_empty_queue_is_refused(): void
    {
        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/sync-offline', ['records' => []])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'records_required');
    }

    public function test_a_wrong_branch_qr_is_refused(): void
    {
        $this->sync(['qr_code' => 'SOMEONE-ELSES'])
            ->assertOk()
            ->assertJsonPath('data.results.0.reason', 'INVALID_QR');
    }

    public function test_the_late_minutes_are_computed_from_the_queued_time(): void
    {
        Employee::query()->whereKey($this->supervisor->id)->update(['work_start_time' => '09:00:00']);

        $this->sync(['check_in_time' => '09:20:00'])->assertOk()->assertJsonPath('data.synced', 1);

        $this->assertSame(20, Value::int(DB::table('attendance')
            ->where('employee_id', $this->supervisor->id)
            ->where('date', TenantClock::date($this->tenantId))
            ->value('late_minutes')));
    }
}
