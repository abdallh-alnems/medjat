<?php

declare(strict_types=1);

namespace Tests\Feature\Kiosk;

use App\Domain\Face\FaceEmbedding;
use App\Domain\Kiosk\KioskEmployeeCode;
use App\Domain\Kiosk\KioskPairing;
use App\Domain\Kiosk\KioskToken;
use App\Domain\Notifications\PushSender;
use App\Domain\Time\TenantClock;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Services\RemoteConfig\RemoteConfigGate;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\Support\FakeRemoteConfigGate;
use Tests\TestCase;

/**
 * Standing at a tablet: being recognised, and the punch that follows.
 */
final class KioskPunchTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private int $stationId;

    private int $employeeId;

    private string $kioskToken;

    private string $adminToken;

    private FakeRemoteConfigGate $gate;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->gate = new FakeRemoteConfigGate;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(RemoteConfigGate::class, $this->gate);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        DB::table('tenants')->where('id', $this->tenantId)->update([
            'attendance_methods' => json_encode(['kiosk']),
            'face_enforce_mode' => 'enforce',
            'face_liveness_required' => 0,
        ]);

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Punch branch',
            'station_enabled' => 1,
            'station_code_fallback_enabled' => 1,
            'station_anti_spoofing_enabled' => 0,
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Kiosk worker',
            'status' => 'active',
            'base_salary' => 3000,
            'branch_id' => $this->branchId,
            'hire_date' => '2020-01-01',
            'face_embedding' => json_encode(self::vector(0.0)),
            'face_model_version' => FaceEmbedding::MODEL_VERSION,
            'face_embedding_dim' => 128,
        ]);

        $this->stationId = (int) DB::table('attendance_stations')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => 'Main gate',
            'platform' => 'android',
            'app_version' => '1.0.0',
            'paired_at' => DB::raw('NOW()'),
            'last_seen_at' => DB::raw('NOW()'),
        ]);

        $this->kioskToken = KioskToken::issueFor($this->tenantId, $this->stationId, 'tablet-1');

        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Kiosk manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);
        $this->adminToken = $firebase->issue($uid);
    }

    /**
     * @return list<float>
     */
    private static function vector(float $tilt): array
    {
        $out = [cos($tilt), sin($tilt)];

        while (count($out) < 128) {
            $out[] = 0.0;
        }

        return $out;
    }

    private function asKiosk(): self
    {
        $this->withHeader('X-Kiosk-Token', $this->kioskToken);

        return $this;
    }

    private function nonce(): string
    {
        return Value::string(
            $this->asKiosk()->postJson('/app/kiosk/challenge.php')->assertOk()->json('data.nonce')
        );
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function identify(array $overrides = []): TestResponse
    {
        return $this->asKiosk()->postJson('/app/kiosk/identify.php', $overrides + [
            'nonce' => $this->nonce(),
            'embedding' => self::vector(0.01),
            'model_version' => FaceEmbedding::MODEL_VERSION,
            'liveness_passed' => true,
        ]);
    }

    // ── The heartbeat ────────────────────────────────────────────────────

    public function test_a_kiosk_reports_in_and_is_told_how_to_behave(): void
    {
        $this->asKiosk()->postJson('/app/kiosk/heartbeat.php', ['app_version' => '1.0.0'])
            ->assertOk()
            ->assertJsonPath('data.station_status', 'active')
            ->assertJsonPath('data.branch.name', 'Punch branch')
            ->assertJsonPath('data.settings.code_fallback_enabled', true)
            ->assertJsonStructure(['data' => ['server_time']]);
    }

    public function test_an_outdated_build_is_told_to_update_rather_than_served(): void
    {
        $this->gate->set('medjat_kiosk', '2.0.0');

        $this->asKiosk()->postJson('/app/kiosk/heartbeat.php', ['app_version' => '1.0.0'])
            ->assertStatus(426)
            ->assertJsonPath('error_code', 'kiosk_update_required')
            ->assertJsonPath('meta.min_version', '2.0.0');
    }

    public function test_maintenance_takes_the_tablet_out_of_service(): void
    {
        $this->gate->set('medjat_kiosk', '0.0.0', maintenance: true);

        $this->asKiosk()->postJson('/app/kiosk/heartbeat.php')
            ->assertStatus(503)
            ->assertJsonPath('error_code', 'kiosk_maintenance');
    }

    public function test_a_branch_with_the_kiosk_switched_off_stops_serving(): void
    {
        DB::table('branches')->where('id', $this->branchId)->update(['station_enabled' => 0]);

        $this->asKiosk()->postJson('/app/kiosk/heartbeat.php')
            ->assertForbidden()
            ->assertJsonPath('error_code', 'kiosk_pair_branch_disabled');
    }

    public function test_a_kiosk_needs_a_token(): void
    {
        $this->postJson('/app/kiosk/heartbeat.php')->assertUnauthorized();
    }

    // ── Identification ───────────────────────────────────────────────────

    public function test_a_recognised_face_gets_a_ticket_and_is_told_what_happens_next(): void
    {
        $this->identify()
            ->assertOk()
            ->assertJsonPath('data.outcome', 'matched')
            ->assertJsonPath('data.employee.id', $this->employeeId)
            ->assertJsonPath('data.next_action', 'check_in')
            ->assertJsonStructure(['data' => ['punch_ticket', 'recognition_log_id']]);
    }

    public function test_every_attempt_leaves_a_row_whatever_the_outcome(): void
    {
        $this->identify(['embedding' => self::vector(1.5)])
            ->assertOk()
            ->assertJsonPath('data.outcome', 'no_match');

        $this->assertDatabaseHas('station_recognition_logs', [
            'station_id' => $this->stationId,
            'result' => 'no_match',
            'accepted' => 0,
        ]);
    }

    public function test_a_failed_identification_is_guidance_not_an_error(): void
    {
        // Somebody stood in front of a camera and was not recognised. The
        // tablet has to render that as advice, so it answers 200.
        $this->identify(['embedding' => self::vector(1.5)])
            ->assertOk()
            ->assertJsonPath('data.message_key', 'kiosk_no_match')
            ->assertJsonPath('data.code_fallback_available', true);
    }

    public function test_a_nonce_cannot_be_used_twice(): void
    {
        // Otherwise a recorded capture could be replayed at the door.
        $nonce = $this->nonce();

        $payload = [
            'nonce' => $nonce,
            'embedding' => self::vector(0.01),
            'model_version' => FaceEmbedding::MODEL_VERSION,
            'liveness_passed' => true,
        ];

        $this->asKiosk()->postJson('/app/kiosk/identify.php', $payload)
            ->assertOk()->assertJsonPath('data.outcome', 'matched');

        $this->asKiosk()->postJson('/app/kiosk/identify.php', $payload)
            ->assertStatus(410)->assertJsonPath('error_code', 'kiosk_nonce_spent');
    }

    public function test_an_embedding_from_a_different_model_is_refused(): void
    {
        // Embeddings from a different model live in a different space, and
        // comparing across them yields numbers that mean nothing.
        $this->identify(['model_version' => 'some_other_model_v9'])
            ->assertOk()
            ->assertJsonPath('data.outcome', 'model_mismatch');
    }

    public function test_a_photograph_held_up_to_the_camera_is_refused_when_liveness_is_enforced(): void
    {
        DB::table('tenants')->where('id', $this->tenantId)->update(['face_liveness_required' => 1]);
        DB::table('branches')->where('id', $this->branchId)->update(['station_anti_spoofing_enabled' => 1]);

        $this->identify(['liveness_passed' => false])
            ->assertOk()
            ->assertJsonPath('data.outcome', 'liveness_failed');
    }

    public function test_somebody_whose_company_does_not_allow_kiosk_attendance_is_turned_away(): void
    {
        DB::table('tenants')->where('id', $this->tenantId)
            ->update(['attendance_methods' => json_encode(['gps_only'])]);

        $this->identify()->assertOk()->assertJsonPath('data.outcome', 'wrong_method');
    }

    public function test_a_second_identification_offers_the_way_out_not_the_way_in(): void
    {
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'branch_id' => $this->branchId,
            'date' => TenantClock::date($this->tenantId),
            'check_in_time' => '08:00:00',
            'status' => 'present',
        ]);

        $this->identify()->assertOk()->assertJsonPath('data.next_action', 'check_out');
    }

    public function test_a_finished_day_is_not_punched_again(): void
    {
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'branch_id' => $this->branchId,
            'date' => TenantClock::date($this->tenantId),
            'check_in_time' => '08:00:00',
            'check_out_time' => '17:00:00',
            'status' => 'present',
        ]);

        $this->identify()->assertOk()->assertJsonPath('data.outcome', 'too_soon');
    }

    // ── The personal code ────────────────────────────────────────────────

    public function test_a_personal_code_identifies_somebody_the_camera_missed(): void
    {
        $code = KioskEmployeeCode::issueFor($this->employeeId, $this->tenantId, $this->branchId);

        $this->asKiosk()->postJson('/app/kiosk/identify_by_code.php', ['code' => $code])
            ->assertOk()
            ->assertJsonPath('data.outcome', 'matched')
            ->assertJsonPath('data.method', 'code')
            ->assertJsonPath('data.employee.id', $this->employeeId);
    }

    public function test_a_code_from_another_branch_is_useless_here(): void
    {
        $otherBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Elsewhere',
            'station_enabled' => 1,
        ]);
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Other branch worker',
            'status' => 'active',
            'base_salary' => 1000,
            'branch_id' => $otherBranch,
        ]);
        $code = KioskEmployeeCode::issueFor($stranger, $this->tenantId, $otherBranch);

        $this->asKiosk()->postJson('/app/kiosk/identify_by_code.php', ['code' => $code])
            ->assertOk()
            ->assertJsonPath('data.outcome', 'no_match');
    }

    public function test_a_branch_that_disabled_the_code_refuses_it(): void
    {
        DB::table('branches')->where('id', $this->branchId)->update(['station_code_fallback_enabled' => 0]);

        $this->asKiosk()->postJson('/app/kiosk/identify_by_code.php', ['code' => '123456'])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'kiosk_code_disabled');
    }

    public function test_repeated_wrong_codes_are_throttled_and_flagged(): void
    {
        // A person cannot type ten wrong six-digit codes in five minutes by
        // accident, so it is recorded as a security event rather than a mistake.
        for ($attempt = 0; $attempt < 10; $attempt++) {
            $this->asKiosk()->postJson('/app/kiosk/identify_by_code.php', ['code' => '000000'])->assertOk();
        }

        $this->asKiosk()->postJson('/app/kiosk/identify_by_code.php', ['code' => '000000'])
            ->assertStatus(429)
            ->assertJsonPath('error_code', 'kiosk_code_throttled');

        $this->assertDatabaseHas('attendance_security_logs', [
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'reason' => 'kiosk_pin_bruteforce',
            'action' => 'blocked',
        ]);
    }

    public function test_a_code_is_stored_peppered_not_in_the_clear(): void
    {
        $code = KioskEmployeeCode::issueFor($this->employeeId, $this->tenantId, $this->branchId);

        $this->assertDatabaseMissing('employees', ['id' => $this->employeeId, 'kiosk_pin_hash' => $code]);
        $this->assertDatabaseHas('employees', [
            'id' => $this->employeeId,
            'kiosk_pin_hash' => KioskEmployeeCode::hash($code),
        ]);
    }

    // ── The punch ────────────────────────────────────────────────────────

    /**
     * @return array{ticket: string, log_id: int}
     */
    private function ticket(): array
    {
        $response = $this->identify()->assertOk();

        return [
            'ticket' => Value::string($response->json('data.punch_ticket')),
            'log_id' => Value::int($response->json('data.recognition_log_id')),
        ];
    }

    public function test_a_ticket_is_redeemed_into_an_attendance_row(): void
    {
        $issued = $this->ticket();

        $this->asKiosk()->postJson('/app/kiosk/punch.php', [
            'punch_ticket' => $issued['ticket'],
            'idempotency_key' => 'key-1',
            'direction' => 'check_in',
            'recognition_log_id' => $issued['log_id'],
        ])->assertOk()->assertJsonPath('data.replayed', false);

        $this->assertDatabaseHas('attendance', [
            'employee_id' => $this->employeeId,
            'date' => TenantClock::date($this->tenantId),
            'check_in_method' => 'kiosk',
            'station_id' => $this->stationId,
            'recognition_method' => 'station_face',
        ]);
    }

    public function test_a_ticket_cannot_be_spent_twice(): void
    {
        $issued = $this->ticket();

        $this->asKiosk()->postJson('/app/kiosk/punch.php', [
            'punch_ticket' => $issued['ticket'],
            'idempotency_key' => 'key-1',
        ])->assertOk();

        $this->asKiosk()->postJson('/app/kiosk/punch.php', [
            'punch_ticket' => $issued['ticket'],
            'idempotency_key' => 'key-2',
        ])->assertStatus(410)->assertJsonPath('error_code', 'kiosk_ticket_spent');
    }

    public function test_a_retry_after_a_lost_response_reports_the_punch_that_succeeded(): void
    {
        // Telling the employee their punch failed when it succeeded is worse
        // than any duplicate, so the key is checked before the ticket.
        $issued = $this->ticket();

        $first = $this->asKiosk()->postJson('/app/kiosk/punch.php', [
            'punch_ticket' => $issued['ticket'],
            'idempotency_key' => 'key-retry',
        ])->assertOk();

        $this->asKiosk()->postJson('/app/kiosk/punch.php', [
            'punch_ticket' => $issued['ticket'],
            'idempotency_key' => 'key-retry',
        ])
            ->assertOk()
            ->assertJsonPath('data.replayed', true)
            ->assertJsonPath('data.attendance_id', Value::int($first->json('data.attendance_id')));
    }

    public function test_a_punch_without_a_verifiable_log_claims_no_recognition_method(): void
    {
        // A null is honest; a face claim would be evidence that does not exist.
        $issued = $this->ticket();

        $this->asKiosk()->postJson('/app/kiosk/punch.php', [
            'punch_ticket' => $issued['ticket'],
            'idempotency_key' => 'key-3',
            'recognition_log_id' => 999999,
        ])->assertOk();

        $this->assertDatabaseHas('attendance', [
            'employee_id' => $this->employeeId,
            'recognition_method' => null,
        ]);
    }

    public function test_a_tablet_cannot_upgrade_a_code_punch_into_a_face_punch(): void
    {
        // Face versus code is the security boundary of the feature, so the
        // method is read off what the server wrote, never off the request.
        $code = KioskEmployeeCode::issueFor($this->employeeId, $this->tenantId, $this->branchId);

        $response = $this->asKiosk()
            ->postJson('/app/kiosk/identify_by_code.php', ['code' => $code])
            ->assertOk();

        $this->asKiosk()->postJson('/app/kiosk/punch.php', [
            'punch_ticket' => Value::string($response->json('data.punch_ticket')),
            'idempotency_key' => 'key-4',
            'recognition_log_id' => Value::int($response->json('data.recognition_log_id')),
        ])->assertOk();

        $this->assertDatabaseHas('attendance', [
            'employee_id' => $this->employeeId,
            'recognition_method' => 'station_code',
        ]);
    }

    public function test_somebody_transferred_out_of_the_branch_cannot_punch_here(): void
    {
        // The ticket is thirty seconds old, but a transfer in that window must
        // not land a punch on the wrong branch's books.
        $issued = $this->ticket();

        $otherBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Elsewhere',
        ]);
        DB::table('employees')->where('id', $this->employeeId)->update(['branch_id' => $otherBranch]);

        $this->asKiosk()->postJson('/app/kiosk/punch.php', [
            'punch_ticket' => $issued['ticket'],
            'idempotency_key' => 'key-5',
        ])->assertForbidden()->assertJsonPath('error_code', 'kiosk_out_of_branch');
    }

    public function test_the_recognition_attempt_points_at_the_punch_it_produced(): void
    {
        // So a disputed row can be traced back to the scores behind it.
        $issued = $this->ticket();

        $response = $this->asKiosk()->postJson('/app/kiosk/punch.php', [
            'punch_ticket' => $issued['ticket'],
            'idempotency_key' => 'key-6',
            'recognition_log_id' => $issued['log_id'],
        ])->assertOk();

        $this->assertDatabaseHas('station_recognition_logs', [
            'id' => $issued['log_id'],
            'attendance_id' => Value::int($response->json('data.attendance_id')),
        ]);
    }

    public function test_a_punch_increments_the_stations_counter(): void
    {
        $issued = $this->ticket();

        $this->asKiosk()->postJson('/app/kiosk/punch.php', [
            'punch_ticket' => $issued['ticket'],
            'idempotency_key' => 'key-7',
        ])->assertOk();

        $this->assertSame(
            1,
            Value::int(DB::table('attendance_stations')->where('id', $this->stationId)->value('punch_count'))
        );
    }

    // ── Enrolling at the tablet ──────────────────────────────────────────

    private function adminSession(): string
    {
        $code = Value::string(
            $this->withHeader('X-Firebase-Token', $this->adminToken)
                ->postJson('/app/kiosk/create_access_code.php', ['station_id' => $this->stationId])
                ->assertOk()->json('data.code')
        );

        return Value::string(
            $this->asKiosk()->postJson('/app/kiosk/open_admin.php', ['code' => $code])
                ->assertOk()->json('data.admin_session')
        );
    }

    public function test_the_roster_puts_unenrolled_people_first(): void
    {
        $unenrolled = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Aaa Newcomer',
            'status' => 'active',
            'base_salary' => 1000,
            'branch_id' => $this->branchId,
        ]);

        $this->asKiosk()
            ->postJson('/app/kiosk/admin/roster.php', ['admin_session' => $this->adminSession()])
            ->assertOk()
            ->assertJsonPath('data.employees.0.id', $unenrolled)
            ->assertJsonPath('data.employees.0.face_enrolled', false);
    }

    public function test_a_supervisor_enrols_somebody_at_the_tablet(): void
    {
        $newcomer = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Newcomer',
            'status' => 'active',
            'base_salary' => 1000,
            'branch_id' => $this->branchId,
        ]);

        $this->asKiosk()->postJson('/app/kiosk/admin/enroll.php', [
            'admin_session' => $this->adminSession(),
            'employee_id' => $newcomer,
            'embedding' => self::vector(0.9),
            'model_version' => FaceEmbedding::MODEL_VERSION,
            'quality_score' => 0.9,
        ])->assertOk()->assertJsonPath('data.replaced_previous', false);

        $this->assertDatabaseHas('employees', [
            'id' => $newcomer,
            'face_model_version' => FaceEmbedding::MODEL_VERSION,
            'face_enrolled_by_station_id' => $this->stationId,
            'biometric_enrollment_status' => 'face_only',
        ]);
    }

    public function test_a_poor_capture_is_refused_and_recorded(): void
    {
        // A blurry enrollment does not fail loudly — it quietly stops matching
        // its owner and starts resembling other people.
        $this->asKiosk()->postJson('/app/kiosk/admin/enroll.php', [
            'admin_session' => $this->adminSession(),
            'employee_id' => $this->employeeId,
            'embedding' => self::vector(0.5),
            'model_version' => FaceEmbedding::MODEL_VERSION,
            'quality_score' => 0.2,
            'confirm_replace' => true,
        ])->assertStatus(422)->assertJsonPath('error_code', 'quality_too_low');

        $this->assertDatabaseHas('station_recognition_logs', [
            'employee_id' => $this->employeeId,
            'purpose' => 'enroll',
            'result' => 'not_enrolled',
        ]);
    }

    public function test_replacing_an_existing_enrollment_must_be_asked_for(): void
    {
        // Without this, a second person enrolled onto an existing employee is a
        // silent overwrite, and afterwards nothing distinguishes it.
        $this->asKiosk()->postJson('/app/kiosk/admin/enroll.php', [
            'admin_session' => $this->adminSession(),
            'employee_id' => $this->employeeId,
            'embedding' => self::vector(0.9),
            'model_version' => FaceEmbedding::MODEL_VERSION,
            'quality_score' => 0.9,
        ])->assertStatus(409)->assertJsonPath('error_code', 'kiosk_enroll_replaced');
    }

    public function test_a_tablet_cannot_enrol_somebody_at_another_branch(): void
    {
        $otherBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Elsewhere',
        ]);
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Other branch worker',
            'status' => 'active',
            'base_salary' => 1000,
            'branch_id' => $otherBranch,
        ]);

        $this->asKiosk()->postJson('/app/kiosk/admin/enroll.php', [
            'admin_session' => $this->adminSession(),
            'employee_id' => $stranger,
            'embedding' => self::vector(0.9),
            'model_version' => FaceEmbedding::MODEL_VERSION,
            'quality_score' => 0.9,
        ])->assertNotFound();
    }

    public function test_an_admin_session_survives_a_queue_of_enrollments(): void
    {
        // Refreshed on every call, which is what lets a supervisor work through
        // thirty people without being thrown out mid-enrollment.
        $session = $this->adminSession();

        $this->asKiosk()->postJson('/app/kiosk/admin/roster.php', ['admin_session' => $session])->assertOk();

        DB::table('attendance_stations')->where('id', $this->stationId)
            ->update(['admin_session_expires_at' => DB::raw('DATE_ADD(NOW(), INTERVAL 5 SECOND)')]);

        $this->asKiosk()->postJson('/app/kiosk/admin/roster.php', ['admin_session' => $session])->assertOk();

        // Compared in SQL: PHP runs UTC and MySQL runs the server zone, so
        // subtracting a PHP timestamp from a stored one is hours out.
        $remaining = Value::int(
            DB::table('attendance_stations')->where('id', $this->stationId)
                ->selectRaw('TIMESTAMPDIFF(SECOND, NOW(), admin_session_expires_at) AS remaining')
                ->value('remaining')
        );

        $this->assertGreaterThan(60, $remaining);
        $this->assertLessThanOrEqual(KioskPairing::ADMIN_SESSION_TTL_SECONDS, $remaining);
    }
}
