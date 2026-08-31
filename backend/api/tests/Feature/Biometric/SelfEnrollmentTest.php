<?php

declare(strict_types=1);

namespace Tests\Feature\Biometric;

use App\Models\EmployeeAuthToken;
use App\Shared\Face\FaceEmbedding;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\CreatesFixtures;
use Tests\TestCase;

/**
 * An employee enrolling their own face from the employee app.
 */
final class SelfEnrollmentTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private int $employeeId;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();

        $this->tenantId = $this->createTenant();
        DB::table('tenants')->where('id', $this->tenantId)->update(['face_liveness_required' => 1]);

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Self-enroll branch',
            'is_active' => 1,
            'face_liveness_required' => null,
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => 'Self-enroll fixture',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
            'biometric_enrollment_status' => 'not_enrolled',
        ]);

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-self',
        ]);
        $this->token = $plain;
    }

    /**
     * @return list<float>
     */
    private static function vector(): array
    {
        return array_fill(0, 128, 0.1);
    }

    /** A live challenge, obtained the way the app obtains one. */
    private function nonce(): string
    {
        $response = $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/face-challenge', ['purpose' => 'enroll'])
            ->assertOk();

        return Value::string($response->json('data.nonce'));
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function enroll(array $overrides = []): TestResponse
    {
        return $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/biometric/self/face', $overrides + [
                'embedding' => self::vector(),
                'quality_score' => 0.9,
                'face_nonce' => $this->nonce(),
                'liveness_passed' => true,
            ]);
    }

    public function test_an_employee_can_enrol_their_own_face(): void
    {
        $this->enroll()
            ->assertStatus(201)
            ->assertJsonPath('data.status', 'face_enrolled')
            ->assertJsonPath('data.model_version', FaceEmbedding::MODEL_VERSION);

        $this->assertDatabaseHas('employees', [
            'id' => $this->employeeId, 'biometric_enrollment_status' => 'face_only',
        ]);
    }

    public function test_enrolling_without_a_challenge_is_refused(): void
    {
        // Without the nonce a captured embedding could be submitted whenever
        // its holder liked — including one lifted from a photograph.
        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/biometric/self/face', [
                'embedding' => self::vector(),
                'quality_score' => 0.9,
                'liveness_passed' => true,
            ])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'FACE_INVALID_CHALLENGE');
    }

    public function test_a_nonce_cannot_be_spent_twice(): void
    {
        $nonce = $this->nonce();

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/biometric/self/face', [
                'embedding' => self::vector(),
                'quality_score' => 0.9,
                'face_nonce' => $nonce,
                'liveness_passed' => true,
            ])->assertStatus(201);

        DB::table('employees')->where('id', $this->employeeId)->update([
            'face_embedding' => null, 'face_enrolled_at' => null, 'face_model_version' => null,
        ]);

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/biometric/self/face', [
                'embedding' => self::vector(),
                'quality_score' => 0.9,
                'face_nonce' => $nonce,
                'liveness_passed' => true,
            ])->assertStatus(400);
    }

    public function test_a_check_in_nonce_cannot_be_redeemed_against_enrollment(): void
    {
        DB::table('employees')->where('id', $this->employeeId)
            ->update(['face_embedding' => json_encode(self::vector())]);

        $response = $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/attendance/face-challenge', ['purpose' => 'check_in'])
            ->assertOk();

        DB::table('employees')->where('id', $this->employeeId)->update(['face_embedding' => null]);

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/biometric/self/face', [
                'embedding' => self::vector(),
                'quality_score' => 0.9,
                'face_nonce' => Value::string($response->json('data.nonce')),
                'liveness_passed' => true,
            ])->assertStatus(400);
    }

    public function test_failing_liveness_is_refused(): void
    {
        // Enrollment clears the same bar as a check-in; otherwise somebody
        // could enrol a printed photo, and every later match would verify
        // cleanly against it.
        $this->enroll(['liveness_passed' => false])
            ->assertStatus(403)
            ->assertJsonPath('error_code', 'FACE_LIVENESS_FAILED');
    }

    public function test_a_blurry_capture_is_refused(): void
    {
        // A poor enrollment does not fail loudly — it quietly stops matching
        // its owner and starts resembling other people.
        $this->enroll(['quality_score' => 0.2])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'FACE_QUALITY_TOO_LOW');
    }

    public function test_a_malformed_vector_is_refused(): void
    {
        $this->enroll(['embedding' => 'not-a-vector'])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'FACE_BAD_EMBEDDING');
    }

    public function test_enrolling_twice_needs_an_hr_reset(): void
    {
        $this->enroll()->assertStatus(201);

        // One-time by design: a second enrollment would let somebody quietly
        // replace the reference face after the first was approved.
        $this->enroll()
            ->assertStatus(409)
            ->assertJsonPath('error_code', 'FACE_ALREADY_ENROLLED');
    }

    public function test_a_model_upgrade_reopens_enrollment_without_a_reset(): void
    {
        $this->enroll()->assertStatus(201);

        DB::table('employees')->where('id', $this->employeeId)
            ->update(['face_model_version' => 'retired_v0']);

        // The old embedding cannot be compared against anything any more, so
        // refusing would strand the employee outside their own shift.
        $this->enroll()->assertStatus(201);

        $this->assertDatabaseHas('employees', [
            'id' => $this->employeeId, 'face_model_version' => FaceEmbedding::MODEL_VERSION,
        ]);
    }

    public function test_the_status_sends_an_unenrolled_employee_to_the_camera(): void
    {
        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/biometric/self/status')
            ->assertOk()
            ->assertJsonPath('data.enrolled', false)
            ->assertJsonPath('data.needs_reenrollment', false)
            ->assertJsonPath('data.liveness_required', true)
            ->assertJsonPath('data.model_version', FaceEmbedding::MODEL_VERSION);
    }

    public function test_the_status_reports_an_enrolled_employee(): void
    {
        $this->enroll()->assertStatus(201);

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/biometric/self/status')
            ->assertOk()
            ->assertJsonPath('data.enrolled', true)
            ->assertJsonPath('data.needs_reenrollment', false);
    }

    public function test_a_stale_enrollment_reads_as_not_enrolled_and_needing_a_redo(): void
    {
        $this->enroll()->assertStatus(201);

        DB::table('employees')->where('id', $this->employeeId)
            ->update(['face_model_version' => 'retired_v0']);

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/biometric/self/status')
            ->assertOk()
            ->assertJsonPath('data.enrolled', false)
            ->assertJsonPath('data.needs_reenrollment', true);
    }

    public function test_a_branch_can_relax_liveness_for_its_own_staff(): void
    {
        DB::table('branches')->where('id', $this->branchId)->update(['face_liveness_required' => 0]);

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/v1/biometric/self/status')
            ->assertOk()
            ->assertJsonPath('data.liveness_required', false);

        $this->enroll(['liveness_passed' => false])->assertStatus(201);
    }

    public function test_an_unauthenticated_request_is_refused(): void
    {
        $this->postJson('/v1/biometric/self/status')->assertStatus(401);
    }
}
