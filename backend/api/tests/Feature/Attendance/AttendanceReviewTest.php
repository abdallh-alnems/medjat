<?php

declare(strict_types=1);

namespace Tests\Feature\Attendance;

use App\Models\Admin;
use App\Models\Employee;
use App\Modules\Attendance\Domain\AbsenceBackfill;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * The management side of attendance: the day's board, the evidence images, the
 * face audit, and the rotating display.
 */
final class AttendanceReviewTest extends TestCase
{
    use DatabaseTransactions;

    private Employee $employee;

    private int $branchId;

    private int $tenantId;

    private FakeFirebaseTokenVerifier $firebase;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);

        $this->employee = Employee::query()
            ->where('status', 'active')
            ->whereNotNull('branch_id')
            ->firstOrFail();

        $this->branchId = (int) $this->employee->branch_id;
        $this->tenantId = $this->employee->tenant_id;
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array{Admin, string}
     */
    private function admin(array $overrides = []): array
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        $id = Admin::query()->insertGetId(array_merge([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Reviewer',
            'role' => 'general_manager',
            'is_active' => 1,
        ], $overrides));

        return [Admin::query()->findOrFail($id), $this->firebase->issue($uid)];
    }

    // ── The day's board ──────────────────────────────────────────────────

    public function test_an_employee_with_no_row_still_appears_as_not_arrived(): void
    {
        // The board starts from employees rather than from attendance rows, so
        // a no-show is visible rather than absent from the list.
        [, $token] = $this->admin();
        $today = TenantClock::date($this->tenantId);
        DB::table('attendance')->where('date', $today)->where('tenant_id', $this->tenantId)->delete();

        $response = $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/v1/attendance/branch?date='.$today)
            ->assertOk();

        $records = $response->json('data.records');
        $this->assertIsArray($records);
        $this->assertNotEmpty($records);
        $this->assertContains('not_arrived', array_column($records, 'status'));
    }

    public function test_the_photo_path_never_leaves_the_server(): void
    {
        // Handing out the path would invite exactly the direct-URL fetching that
        // uploads/ is now closed to.
        [, $token] = $this->admin();
        $today = TenantClock::date($this->tenantId);

        DB::table('attendance')->where('employee_id', $this->employee->id)->where('date', $today)->delete();
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'branch_id' => $this->branchId,
            'date' => $today,
            'check_in_time' => '09:00:00',
            'check_in_photo' => 'attendance/secret.jpg',
            'status' => 'present',
        ]);

        $body = (string) $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/v1/attendance/branch?date='.$today)
            ->assertOk()
            ->assertJsonFragment(['has_check_in_photo' => true])
            ->getContent();

        $this->assertStringNotContainsString('secret.jpg', $body);
    }

    public function test_a_past_day_is_backfilled_with_absences(): void
    {
        // Without it a past day with no check-in keeps reading "not arrived"
        // rather than "absent".
        [, $token] = $this->admin();
        $past = TenantClock::now($this->tenantId)->modify('-3 days')->format('Y-m-d');

        DB::table('attendance')->where('tenant_id', $this->tenantId)->where('date', $past)->delete();
        Employee::query()->whereKey($this->employee->id)->update(['weekly_off_days' => '']);

        $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/v1/attendance/branch?date='.$past)
            ->assertOk();

        $this->assertDatabaseHas('attendance', [
            'employee_id' => $this->employee->id,
            'date' => $past,
            'status' => 'absent',
        ]);
    }

    public function test_approved_leave_stops_someone_being_marked_absent(): void
    {
        // Every exemption missed here marks somebody absent who was legitimately
        // away.
        $past = TenantClock::now($this->tenantId)->modify('-4 days')->format('Y-m-d');
        DB::table('attendance')->where('tenant_id', $this->tenantId)->where('date', $past)->delete();
        DB::table('leaves')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'date' => $past,
            'start_date' => $past,
            'end_date' => $past,
            'status' => 'approved',
        ]);

        AbsenceBackfill::run($this->tenantId, $past);

        $this->assertDatabaseMissing('attendance', [
            'employee_id' => $this->employee->id,
            'date' => $past,
            'status' => 'absent',
        ]);
    }

    public function test_the_backfill_is_idempotent(): void
    {
        $past = TenantClock::now($this->tenantId)->modify('-5 days')->format('Y-m-d');
        DB::table('attendance')->where('tenant_id', $this->tenantId)->where('date', $past)->delete();

        AbsenceBackfill::run($this->tenantId, $past);
        $after = DB::table('attendance')->where('tenant_id', $this->tenantId)->where('date', $past)->count();

        AbsenceBackfill::run($this->tenantId, $past);

        $this->assertSame(
            $after,
            DB::table('attendance')->where('tenant_id', $this->tenantId)->where('date', $past)->count(),
            'running it on every view of a past day has to be safe'
        );
    }

    // ── Evidence images ──────────────────────────────────────────────────

    public function test_a_photo_is_served_privately_and_uncached(): void
    {
        // An employee's photograph, not an asset: it must not sit in a shared
        // proxy or on a CDN edge, which is how the payslip leak outlived the
        // origin being fixed.
        Storage::fake('uploads');
        Storage::disk('uploads')->put('attendance/p.jpg', 'not-really-a-jpeg');

        [, $token] = $this->admin();
        $today = TenantClock::date($this->tenantId);
        DB::table('attendance')->where('employee_id', $this->employee->id)->where('date', $today)->delete();
        $id = DB::table('attendance')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'branch_id' => $this->branchId,
            'date' => $today,
            'check_in_time' => '09:00:00',
            'check_in_photo' => 'attendance/p.jpg',
            'status' => 'present',
        ]);

        $response = $this->withHeader('X-Firebase-Token', $token)
            ->get('/v1/attendance/photo?attendance_id='.$id.'&which=check_in')
            ->assertOk()
            ->assertHeader('X-Content-Type-Options', 'nosniff');

        $cacheControl = $response->headers->get('Cache-Control') ?? '';
        $this->assertStringContainsString('private', $cacheControl);
        $this->assertStringContainsString('no-store', $cacheControl);
    }

    public function test_a_missing_photo_is_a_404(): void
    {
        [, $token] = $this->admin();
        $today = TenantClock::date($this->tenantId);
        DB::table('attendance')->where('employee_id', $this->employee->id)->where('date', $today)->delete();
        $id = DB::table('attendance')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'date' => $today,
            'status' => 'present',
        ]);

        $this->withHeader('X-Firebase-Token', $token)
            ->get('/v1/attendance/photo?attendance_id='.$id)
            ->assertNotFound();
    }

    public function test_an_attendance_row_from_another_company_is_not_visible(): void
    {
        [, $token] = $this->admin();

        $other = DB::table('attendance')->where('tenant_id', '!=', $this->tenantId)->value('id');
        if ($other === null) {
            $this->markTestSkipped('needs a second company with attendance');
        }

        $this->withHeader('X-Firebase-Token', $token)
            ->get('/v1/attendance/photo?attendance_id='.Value::int($other))
            ->assertNotFound();
    }

    // ── Face audit ───────────────────────────────────────────────────────

    public function test_the_distribution_view_reports_a_threshold_and_buckets(): void
    {
        // This is what turns log_only into a decision.
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/face-logs', ['view' => 'distribution', 'days' => 30])
            ->assertOk()
            ->assertJsonStructure(['data' => ['days', 'threshold', 'buckets']])
            ->assertJsonPath('data.days', 30);
    }

    public function test_the_distribution_window_is_clamped(): void
    {
        // An unbounded window is a table scan somebody eventually asks for by
        // accident.
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/face-logs', ['view' => 'distribution', 'days' => 99999])
            ->assertOk()
            ->assertJsonPath('data.days', 365);
    }

    public function test_the_employee_view_returns_their_attempts(): void
    {
        [, $token] = $this->admin();

        DB::table('face_verification_logs')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'purpose' => 'check_in',
            'result' => 'below_threshold',
            'accepted' => 0,
            'match_score' => 0.31,
            'threshold' => 0.45,
            'liveness_passed' => 1,
        ]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/face-logs', ['employee_id' => $this->employee->id])
            ->assertOk()
            ->assertJsonPath('data.logs.0.result', 'below_threshold')
            ->assertJsonPath('data.logs.0.match_score', 0.31);
    }

    // ── Rotating display ─────────────────────────────────────────────────

    public function test_a_display_gets_a_code_with_overlapping_windows(): void
    {
        // expires_in is longer than rotate_in on purpose, so a code cannot
        // expire between being rendered and being scanned.
        [, $token] = $this->admin();
        DB::table('branches')->where('id', $this->branchId)->update(['rotating_qr_enabled' => 1]);

        $response = $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/branch-qr', ['branch_id' => $this->branchId])
            ->assertOk()
            ->assertJsonStructure(['data' => ['nonce', 'expires_in', 'rotate_in']]);

        $this->assertGreaterThan(
            Value::int($response->json('data.rotate_in')),
            Value::int($response->json('data.expires_in')),
            'the windows must overlap'
        );
    }

    public function test_a_branch_still_on_the_printed_code_is_refused(): void
    {
        // A display quietly showing codes the punch path ignores is the kind of
        // failure discovered by a queue at the door.
        [, $token] = $this->admin();
        DB::table('branches')->where('id', $this->branchId)->update(['rotating_qr_enabled' => 0]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/branch-qr', ['branch_id' => $this->branchId])
            ->assertStatus(409)
            ->assertJsonPath('error_code', 'ROTATING_QR_DISABLED');
    }

    public function test_the_minted_code_is_live_by_the_database_clock(): void
    {
        [, $token] = $this->admin();
        DB::table('branches')->where('id', $this->branchId)->update(['rotating_qr_enabled' => 1]);

        $nonce = $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/branch-qr', ['branch_id' => $this->branchId])
            ->json('data.nonce');

        $this->assertTrue(
            DB::table('branch_qr_challenges')
                ->where('nonce', $nonce)
                ->where('expires_at', '>', DB::raw('NOW()'))
                ->exists()
        );
    }
}
