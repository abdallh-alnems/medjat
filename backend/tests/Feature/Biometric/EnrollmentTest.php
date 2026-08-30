<?php

declare(strict_types=1);

namespace Tests\Feature\Biometric;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Shared\Face\FaceEmbedding;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The HR side of biometrics: recording a face or fingerprint for somebody else.
 */
final class EnrollmentTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private int $employeeId;

    private FakeFirebaseTokenVerifier $firebase;

    private string $adminToken;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Biometric branch', 'is_active' => 1,
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => 'Enrollment fixture',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
            'biometric_enrollment_status' => 'not_enrolled',
        ]);

        $this->adminToken = $this->admin('general_manager');
    }

    private function admin(string $role, ?int $branchId = null): string
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'branch_id' => $branchId,
            'name' => 'Admin '.$role,
            'role' => $role,
            'is_active' => 1,
        ]);

        return $this->firebase->issue($uid);
    }

    /**
     * @return list<float>
     */
    private static function vector(float $seed = 0.1): array
    {
        return array_fill(0, 128, $seed);
    }

    /**
     * @return array<string, mixed>
     */
    private function employeeRow(): array
    {
        /** @var array<string, mixed> $row */
        $row = (array) DB::table('employees')->where('id', $this->employeeId)->first();

        return $row;
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function send(string $path, array $payload = [], ?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)->postJson($path, $payload);
    }

    public function test_a_face_enrollment_records_the_vector_and_derives_the_status(): void
    {
        $this->send('/app/biometric/enroll_face.php', [
            'employee_id' => $this->employeeId,
            'embedding' => self::vector(),
            'quality_score' => 0.9,
        ])->assertStatus(201)->assertJsonPath('data.status', 'face_enrolled');

        $row = $this->employeeRow();
        $this->assertNotNull($row['face_embedding']);
        $this->assertSame(128, Value::int($row['face_embedding_dim']));
        $this->assertSame(FaceEmbedding::MODEL_VERSION, Value::string($row['face_model_version']));
        // Derived, never set directly: two columns that could disagree about
        // the same fact eventually will.
        $this->assertSame('face_only', Value::string($row['biometric_enrollment_status']));
    }

    public function test_a_malformed_vector_is_refused_at_the_door(): void
    {
        // Stored happily, it would fail every check-in with an opaque error.
        $this->send('/app/biometric/enroll_face.php', [
            'employee_id' => $this->employeeId,
            'embedding' => [1, 2, 3],
            'quality_score' => 0.9,
        ])->assertStatus(422);

        $this->assertDatabaseHas('employees', [
            'id' => $this->employeeId, 'biometric_enrollment_status' => 'not_enrolled',
        ]);
    }

    public function test_holding_both_templates_is_reflected_in_the_status(): void
    {
        $this->send('/app/biometric/enroll_face.php', [
            'employee_id' => $this->employeeId,
            'embedding' => self::vector(),
            'quality_score' => 0.9,
        ])->assertStatus(201);

        $this->send('/app/biometric/enroll_fingerprint.php', [
            'employee_id' => $this->employeeId,
            'template_base64' => base64_encode('template-bytes'),
        ])->assertStatus(201);

        $this->assertDatabaseHas('employees', [
            'id' => $this->employeeId, 'biometric_enrollment_status' => 'both',
        ]);
    }

    public function test_clearing_the_face_leaves_the_fingerprint_standing(): void
    {
        $this->send('/app/biometric/enroll_face.php', [
            'employee_id' => $this->employeeId,
            'embedding' => self::vector(),
            'quality_score' => 0.9,
        ])->assertStatus(201);
        $this->send('/app/biometric/enroll_fingerprint.php', [
            'employee_id' => $this->employeeId,
            'template_base64' => base64_encode('template-bytes'),
        ])->assertStatus(201);

        $this->send('/app/biometric/delete.php', [
            'employee_id' => $this->employeeId, 'type' => 'face',
        ])->assertOk()->assertJsonPath('data.deleted_type', 'face');

        $row = $this->employeeRow();
        $this->assertNull($row['face_embedding']);
        $this->assertNull($row['face_enrolled_at']);
        $this->assertNotNull($row['fingerprint_enrolled_at']);
        $this->assertSame('fingerprint_only', Value::string($row['biometric_enrollment_status']));
    }

    public function test_clearing_everything_returns_the_employee_to_unenrolled(): void
    {
        $this->send('/app/biometric/enroll_face.php', [
            'employee_id' => $this->employeeId,
            'embedding' => self::vector(),
            'quality_score' => 0.9,
        ])->assertStatus(201);

        $this->send('/app/biometric/delete.php', ['employee_id' => $this->employeeId])->assertOk();

        $this->assertDatabaseHas('employees', [
            'id' => $this->employeeId, 'biometric_enrollment_status' => 'not_enrolled',
        ]);
    }

    public function test_the_legacy_url_still_answers_the_delete_verb(): void
    {
        // Published app bundles speak POST, but the original answered both.
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->json('DELETE', '/app/biometric/delete.php', ['employee_id' => $this->employeeId])
            ->assertOk();
    }

    public function test_an_unknown_removal_type_is_refused(): void
    {
        $this->send('/app/biometric/delete.php', [
            'employee_id' => $this->employeeId, 'type' => 'retina',
        ])->assertStatus(422);
    }

    public function test_enrolling_does_not_confer_the_right_to_clear(): void
    {
        // Clearing is what authorises a re-enrollment, so it is the step that
        // could be used to swap somebody's reference face.
        $clerk = $this->admin('attendance');

        $this->send('/app/biometric/enroll_face.php', [
            'employee_id' => $this->employeeId,
            'embedding' => self::vector(),
            'quality_score' => 0.9,
        ], $clerk)->assertStatus(201);

        $this->send('/app/biometric/delete.php', ['employee_id' => $this->employeeId], $clerk)
            ->assertStatus(403);
    }

    public function test_a_branch_manager_cannot_enrol_somebody_from_another_branch(): void
    {
        $otherBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Not theirs', 'is_active' => 1,
        ]);
        $token = $this->admin('branch_manager', $otherBranch);

        $this->send('/app/biometric/enroll_face.php', [
            'employee_id' => $this->employeeId,
            'embedding' => self::vector(),
            'quality_score' => 0.9,
        ], $token)->assertStatus(403);
    }

    public function test_another_companys_employee_is_out_of_reach(): void
    {
        $otherTenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Other company', 'timezone' => 'Africa/Cairo', 'is_active' => 1,
        ]);
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $otherTenant,
            'name' => 'Stranger',
            'status' => 'active',
            'base_salary' => 1000,
            'hire_date' => '2022-01-01',
        ]);

        $this->send('/app/biometric/enroll_face.php', [
            'employee_id' => $stranger,
            'embedding' => self::vector(),
            'quality_score' => 0.9,
        ])->assertStatus(404);
    }

    public function test_the_status_screen_reports_what_is_held(): void
    {
        $this->send('/app/biometric/enroll_face.php', [
            'employee_id' => $this->employeeId,
            'embedding' => self::vector(),
            'quality_score' => 0.82,
        ])->assertStatus(201);

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/app/biometric/status.php?employee_id='.$this->employeeId)
            ->assertOk()
            ->assertJsonPath('data.biometric_enrollment_status', 'face_only')
            ->assertJsonPath('data.needs_reenrollment', false);
    }

    public function test_an_embedding_from_a_retired_model_is_flagged_for_re_enrollment(): void
    {
        $this->send('/app/biometric/enroll_face.php', [
            'employee_id' => $this->employeeId,
            'embedding' => self::vector(),
            'quality_score' => 0.9,
        ])->assertStatus(201);

        DB::table('employees')->where('id', $this->employeeId)
            ->update(['face_model_version' => 'retired_v0']);

        // Otherwise every check-in fails with a mismatch nobody can explain.
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/app/biometric/status.php?employee_id='.$this->employeeId)
            ->assertOk()
            ->assertJsonPath('data.needs_reenrollment', true);
    }

    public function test_an_enrollment_from_before_the_version_column_is_not_flagged(): void
    {
        $this->send('/app/biometric/enroll_face.php', [
            'employee_id' => $this->employeeId,
            'embedding' => self::vector(),
            'quality_score' => 0.9,
        ])->assertStatus(201);

        DB::table('employees')->where('id', $this->employeeId)
            ->update(['face_model_version' => null]);

        // The verifier accepts a null version, so telling HR to reset these
        // would send people back through enrollment for nothing.
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/app/biometric/status.php?employee_id='.$this->employeeId)
            ->assertOk()
            ->assertJsonPath('data.needs_reenrollment', false);
    }

    public function test_a_status_request_for_nobody_is_a_404(): void
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/app/biometric/status.php?employee_id=0')
            ->assertStatus(404);
    }
}
