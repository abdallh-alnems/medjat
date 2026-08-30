<?php

declare(strict_types=1);

namespace Tests\Feature\Attendance;

use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Shared\Face\FaceEmbedding;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * The smaller attendance endpoints: the liveness challenge, the supervisor's
 * crew, and the client-reported security log.
 */
final class AttendanceSupportTest extends TestCase
{
    use DatabaseTransactions;

    private Employee $employee;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        $this->employee = Employee::query()
            ->where('status', '!=', 'terminated')
            ->whereNotNull('branch_id')
            ->firstOrFail();

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

    private function enrol(): void
    {
        Employee::query()->whereKey($this->employee->id)->update([
            'face_embedding' => json_encode(array_fill(0, 192, 0.1)),
            'face_model_version' => FaceEmbedding::MODEL_VERSION,
        ]);
    }

    // ── Liveness challenge ───────────────────────────────────────────────

    public function test_a_challenge_is_issued_for_an_enrolled_employee(): void
    {
        $this->enrol();

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/face-challenge', ['purpose' => 'check_in'])
            ->assertOk()
            ->assertJsonStructure(['data' => ['nonce', 'challenge', 'expires_in', 'liveness_required', 'model_version']])
            ->assertJsonPath('data.model_version', FaceEmbedding::MODEL_VERSION);
    }

    public function test_only_one_live_challenge_exists_per_purpose(): void
    {
        // Holding several would let somebody bank them.
        $this->enrol();

        for ($i = 0; $i < 3; $i++) {
            $this->withHeader('X-Employee-Token', $this->token)
                ->postJson('/v1/attendance/face-challenge', ['purpose' => 'check_in'])
                ->assertOk();
        }

        $this->assertSame(1, DB::table('face_challenges')
            ->where('employee_id', $this->employee->id)
            ->where('purpose', 'check_in')
            ->count());
    }

    public function test_the_expiry_is_in_the_future(): void
    {
        // A PHP-built timestamp lands hours in MySQL's past here, so every
        // challenge would be born expired.
        $this->enrol();

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/face-challenge', ['purpose' => 'check_in'])
            ->assertOk();

        $this->assertTrue(
            DB::table('face_challenges')
                ->where('employee_id', $this->employee->id)
                ->where('expires_at', '>', DB::raw('NOW()'))
                ->exists(),
            'the challenge must still be live by the database clock'
        );
    }

    public function test_an_unenrolled_employee_is_told_so_rather_than_refused_later(): void
    {
        Employee::query()->whereKey($this->employee->id)->update(['face_embedding' => null]);

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/face-challenge', ['purpose' => 'check_in'])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'FACE_NOT_ENROLLED');
    }

    public function test_enrolment_does_not_require_an_existing_enrolment(): void
    {
        Employee::query()->whereKey($this->employee->id)->update(['face_embedding' => null]);

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/face-challenge', ['purpose' => 'enroll'])
            ->assertOk();
    }

    public function test_an_unknown_purpose_is_refused(): void
    {
        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/face-challenge', ['purpose' => 'whatever'])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'invalid_purpose');
    }

    // ── Crew ─────────────────────────────────────────────────────────────

    public function test_an_employee_with_no_crew_is_not_a_supervisor(): void
    {
        // The two are the same state by construction rather than two flags that
        // can disagree.
        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/crew')
            ->assertOk()
            ->assertJsonPath('data.is_supervisor', false)
            ->assertJsonPath('data.members', []);
    }

    public function test_a_supervisor_gets_their_crew_with_todays_state(): void
    {
        $member = Employee::query()
            ->whereKeyNot($this->employee->id)
            ->where('tenant_id', $this->employee->tenant_id)
            ->firstOrFail();

        Employee::query()->whereKey($member->id)
            ->update(['crew_supervisor_id' => $this->employee->id, 'status' => 'active']);

        DB::table('attendance')->where('employee_id', $member->id)
            ->where('date', TenantClock::date($this->employee->tenant_id))->delete();
        DB::table('attendance')->insert([
            'tenant_id' => $this->employee->tenant_id,
            'employee_id' => $member->id,
            'date' => TenantClock::date($this->employee->tenant_id),
            'check_in_time' => '08:30:00',
            'status' => 'present',
        ]);

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/crew')
            ->assertOk()
            ->assertJsonPath('data.is_supervisor', true)
            ->assertJsonPath('data.members.0.id', $member->id)
            // Today's times arrive with the names so a foreman on one bar of
            // signal pays for one round trip, not two.
            ->assertJsonPath('data.members.0.check_in_time', '08:30:00');
    }

    public function test_a_terminated_member_is_left_out(): void
    {
        $member = Employee::query()
            ->whereKeyNot($this->employee->id)
            ->where('tenant_id', $this->employee->tenant_id)
            ->firstOrFail();

        Employee::query()->whereKey($member->id)
            ->update(['crew_supervisor_id' => $this->employee->id, 'status' => 'terminated']);

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/crew')
            ->assertOk()
            ->assertJsonPath('data.is_supervisor', false);
    }

    // ── Client-reported security log ─────────────────────────────────────

    public function test_a_recognised_reason_is_recorded(): void
    {
        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/security-log', ['reason' => 'rooted'])
            ->assertOk()
            ->assertJsonPath('data.logged', true);

        $this->assertDatabaseHas('attendance_security_logs', [
            'employee_id' => $this->employee->id,
            'reason' => 'rooted',
            'action' => 'blocked',
        ]);
    }

    public function test_an_unrecognised_reason_is_refused_rather_than_stored(): void
    {
        // Everything here is client-asserted, so the reason is matched against a
        // literal list rather than written as sent.
        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/security-log', ['reason' => "'; DROP TABLE attendance; --"])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'invalid_reason');

        $this->assertGreaterThan(0, Value::int(DB::table('attendance')->count()));
    }
}
