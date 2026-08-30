<?php

declare(strict_types=1);

namespace Tests\Feature\Performance;

use App\Domain\Notifications\PushSender;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Written assessments of somebody's work.
 */
final class ReviewTest extends TestCase
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
            'tenant_id' => $this->tenantId, 'name' => 'Review branch', 'is_active' => 1,
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => 'Reviewed employee',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
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
     * @param  array<string, mixed>  $payload
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function send(string $path, array $payload = [], ?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)->postJson($path, $payload);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function create(array $overrides = [], ?string $token = null): TestResponse
    {
        return $this->send('/app/performance/review_create.php', $overrides + [
            'employee_id' => $this->employeeId,
            'rating' => 4,
            'review' => 'Solid quarter',
        ], $token);
    }

    public function test_a_review_records_who_made_it_and_from_what_angle(): void
    {
        // "Rated 3" means four different things depending on who said it.
        $id = Value::int($this->create(['reviewer_type' => 'peer'])->assertStatus(201)->json('data.id'));

        $this->assertDatabaseHas('performance_reviews', [
            'id' => $id,
            'employee_id' => $this->employeeId,
            'reviewer_type' => 'peer',
            'rating' => 4.00,
            'status' => 'submitted',
        ]);
    }

    public function test_a_review_defaults_to_a_submitted_manager_assessment(): void
    {
        $id = Value::int($this->create()->assertStatus(201)->json('data.id'));

        $this->assertDatabaseHas('performance_reviews', [
            'id' => $id, 'reviewer_type' => 'manager', 'status' => 'submitted',
        ]);
    }

    public function test_a_draft_can_be_saved(): void
    {
        $id = Value::int($this->create(['status' => 'draft'])->assertStatus(201)->json('data.id'));

        $this->assertDatabaseHas('performance_reviews', ['id' => $id, 'status' => 'draft']);
    }

    public function test_a_review_without_a_rating_is_allowed(): void
    {
        // A written assessment with no number is still an assessment.
        $this->create(['rating' => null, 'strengths' => 'Mentors the new starters'])
            ->assertStatus(201);
    }

    public function test_a_rating_outside_the_scale_is_refused(): void
    {
        $this->create(['rating' => 6])->assertStatus(422);
        $this->create(['rating' => -1])->assertStatus(422);
    }

    public function test_an_unknown_reviewer_type_or_status_is_refused(): void
    {
        $this->create(['reviewer_type' => 'customer'])->assertStatus(422);
        $this->create(['status' => 'archived'])->assertStatus(422);
    }

    public function test_an_unknown_cycle_is_refused(): void
    {
        $this->create(['cycle_id' => 99999999])->assertStatus(404);
    }

    public function test_reviews_are_listed_newest_first(): void
    {
        $this->create(['review' => 'First'])->assertStatus(201);
        $this->create(['review' => 'Second'])->assertStatus(201);

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/app/performance/review_list.php?employee_id='.$this->employeeId)
            ->assertOk()
            ->assertJsonCount(2, 'data.items');
    }

    public function test_the_list_names_the_reviewer(): void
    {
        $this->create()->assertStatus(201);

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/app/performance/review_list.php?employee_id='.$this->employeeId)
            ->assertOk()
            ->assertJsonPath('data.items.0.reviewer_name', 'Admin general_manager');
    }

    public function test_the_list_can_be_narrowed_to_a_cycle(): void
    {
        $cycleId = (int) DB::table('performance_cycles')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Q1 2026',
            'start_date' => '2026-01-01',
            'end_date' => '2026-03-31',
        ]);

        $this->create(['cycle_id' => $cycleId])->assertStatus(201);
        $this->create()->assertStatus(201);

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/app/performance/review_list.php?employee_id='.$this->employeeId.'&cycle_id='.$cycleId)
            ->assertOk()
            ->assertJsonCount(1, 'data.items');
    }

    public function test_a_review_can_be_deleted(): void
    {
        $id = Value::int($this->create()->assertStatus(201)->json('data.id'));

        $this->send('/app/performance/review_delete.php', ['id' => $id])->assertOk();

        $this->assertDatabaseMissing('performance_reviews', ['id' => $id]);
    }

    public function test_deleting_an_unknown_review_is_a_404(): void
    {
        $this->send('/app/performance/review_delete.php', ['id' => 99999999])->assertStatus(404);
    }

    public function test_a_branch_manager_cannot_review_outside_their_branch(): void
    {
        $otherBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Not theirs', 'is_active' => 1,
        ]);
        $token = $this->admin('branch_manager', $otherBranch);

        $this->create([], $token)->assertStatus(403);

        $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/app/performance/review_list.php?employee_id='.$this->employeeId)
            ->assertStatus(403);
    }

    public function test_a_branch_manager_cannot_delete_a_review_of_somebody_elses_staff(): void
    {
        $id = Value::int($this->create()->assertStatus(201)->json('data.id'));

        $otherBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Not theirs either', 'is_active' => 1,
        ]);

        // The branch check follows the review's subject, not the review.
        $this->send('/app/performance/review_delete.php', ['id' => $id], $this->admin('branch_manager', $otherBranch))
            ->assertStatus(403);

        $this->assertDatabaseHas('performance_reviews', ['id' => $id]);
    }

    public function test_another_companys_employee_cannot_be_reviewed(): void
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

        $this->create(['employee_id' => $stranger])->assertStatus(404);
    }

    public function test_a_viewer_cannot_read_or_write_reviews(): void
    {
        $token = $this->admin('viewer');

        $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/app/performance/review_list.php?employee_id='.$this->employeeId)
            ->assertStatus(403);

        $this->create([], $token)->assertStatus(403);
    }
}
