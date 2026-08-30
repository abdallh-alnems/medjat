<?php

declare(strict_types=1);

namespace Tests\Feature\Categories;

use App\Domain\Notifications\PushSender;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Job categories, and the browser-attendance exception attached to them.
 */
final class CategoryTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $employeeId;

    private string $adminToken;

    private string $hrToken;

    private string $viewerToken;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Categorised',
            'status' => 'active',
            'base_salary' => 3000,
        ]);

        $this->adminToken = $this->admin($firebase, 'general_manager');
        $this->hrToken = $this->admin($firebase, 'hr');
        $this->viewerToken = $this->admin($firebase, 'viewer');
    }

    private function admin(FakeFirebaseTokenVerifier $firebase, string $role): string
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Admin '.$role,
            'role' => $role,
            'is_active' => 1,
        ]);

        return $firebase->issue($uid);
    }

    private function asAdmin(): self
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken);

        return $this;
    }

    private function created(string $name = 'Drivers'): int
    {
        $response = $this->asAdmin()->postJson('/app/categories/create.php', ['name' => $name])
            ->assertStatus(201);

        return Value::int($response->json('data.category_id'));
    }

    public function test_a_category_is_created_and_listed(): void
    {
        $id = $this->created();

        $categories = $this->asAdmin()->getJson('/app/categories/list.php')->assertOk()->json('data.categories');
        $this->assertIsArray($categories);

        $names = array_map(static fn (mixed $c): string => is_array($c) ? Value::string($c['name']) : '', $categories);
        $this->assertContains('Drivers', $names);
        $this->assertGreaterThan(0, $id);
    }

    public function test_two_categories_cannot_share_a_name(): void
    {
        $this->created();

        $this->asAdmin()->postJson('/app/categories/create.php', ['name' => 'Drivers'])
            ->assertStatus(409)->assertJsonPath('error_code', 'category_name_exists');
    }

    public function test_renaming_onto_an_existing_name_is_refused(): void
    {
        $this->created('Drivers');
        $second = $this->created('Cleaners');

        $this->asAdmin()->postJson('/app/categories/update.php', ['id' => $second, 'name' => 'Drivers'])
            ->assertStatus(409)->assertJsonPath('error_code', 'category_name_exists');
    }

    public function test_renaming_to_its_own_name_is_allowed(): void
    {
        $id = $this->created();

        $this->asAdmin()->postJson('/app/categories/update.php', ['id' => $id, 'name' => 'Drivers'])->assertOk();
    }

    public function test_the_headcount_counts_who_is_still_here(): void
    {
        $id = $this->created();
        $gone = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Left',
            'status' => 'terminated',
            'base_salary' => 1000,
        ]);

        DB::table('employee_category_assignments')->insert([
            ['employee_id' => $this->employeeId, 'category_id' => $id, 'tenant_id' => $this->tenantId],
            ['employee_id' => $gone, 'category_id' => $id, 'tenant_id' => $this->tenantId],
        ]);

        $categories = $this->asAdmin()->getJson('/app/categories/list.php')->assertOk()->json('data.categories');
        $this->assertIsArray($categories);

        foreach ($categories as $category) {
            if (is_array($category) && Value::int($category['id']) === $id) {
                $this->assertSame(1, Value::int($category['employee_count']));
            }
        }
    }

    public function test_an_employees_categories_are_replaced_wholesale(): void
    {
        // The list is what they are now, not a history of what has been added.
        $first = $this->created('Drivers');
        $second = $this->created('Cleaners');

        $this->asAdmin()->postJson('/app/categories/assign.php', [
            'employee_id' => $this->employeeId,
            'category_ids' => [$first],
        ])->assertOk();

        $this->asAdmin()->postJson('/app/categories/assign.php', [
            'employee_id' => $this->employeeId,
            'category_ids' => [$second],
        ])->assertOk();

        $this->assertDatabaseHas('employee_category_assignments', [
            'employee_id' => $this->employeeId, 'category_id' => $second,
        ]);
        $this->assertDatabaseMissing('employee_category_assignments', [
            'employee_id' => $this->employeeId, 'category_id' => $first,
        ]);
    }

    public function test_an_empty_list_clears_them(): void
    {
        $id = $this->created();
        $this->asAdmin()->postJson('/app/categories/assign.php', [
            'employee_id' => $this->employeeId,
            'category_ids' => [$id],
        ])->assertOk();

        $this->asAdmin()->postJson('/app/categories/assign.php', [
            'employee_id' => $this->employeeId,
            'category_ids' => [],
        ])->assertOk();

        $this->assertDatabaseMissing('employee_category_assignments', ['employee_id' => $this->employeeId]);
    }

    public function test_a_category_a_document_requirement_needs_cannot_be_deleted(): void
    {
        // Removing it would drop the requirement, not just the label.
        $id = $this->created();
        $requiredId = (int) DB::table('required_documents')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Driving licence',
            'scope_type' => 'category',
        ]);
        DB::table('required_document_categories')->insert([
            'required_document_id' => $requiredId,
            'category_id' => $id,
            'tenant_id' => $this->tenantId,
        ]);

        $this->asAdmin()->postJson('/app/categories/delete.php', ['id' => $id])
            ->assertStatus(409)->assertJsonPath('error_code', 'category_cannot_delete');
    }

    public function test_an_unused_category_can_be_deleted(): void
    {
        $id = $this->created();

        $this->asAdmin()->postJson('/app/categories/delete.php', ['id' => $id])->assertOk();

        $this->assertDatabaseMissing('employee_categories', ['id' => $id]);
    }

    // ── The browser exception ────────────────────────────────────────────

    public function test_a_category_can_allow_refuse_or_inherit_the_browser_channel(): void
    {
        $id = $this->created();

        foreach ([true, false] as $choice) {
            $this->asAdmin()->postJson('/app/categories/update_web_access.php', [
                'id' => $id,
                'web_attendance_allowed' => $choice,
            ])->assertOk()->assertJsonPath('data.web_attendance_allowed', $choice);
        }

        // Null is the default, and the reason a company that simply turns the
        // channel on needs no category configuration at all.
        $this->asAdmin()->postJson('/app/categories/update_web_access.php', [
            'id' => $id,
            'web_attendance_allowed' => null,
        ])->assertOk()->assertJsonPath('data.web_attendance_allowed', null);

        $this->assertNull(DB::table('employee_categories')->where('id', $id)->value('web_attendance_allowed'));
    }

    public function test_the_field_must_be_supplied_at_all(): void
    {
        $id = $this->created();

        $this->asAdmin()->postJson('/app/categories/update_web_access.php', ['id' => $id])
            ->assertStatus(422)->assertJsonPath('error_code', 'web_attendance_allowed_required');
    }

    public function test_renaming_a_category_does_not_let_somebody_open_the_browser_channel(): void
    {
        // It is the company switch at a finer grain, so it costs the same
        // permission the switch does.
        $id = $this->created();

        $this->withHeader('X-Firebase-Token', $this->hrToken)
            ->postJson('/app/categories/update.php', ['id' => $id, 'name' => 'Renamed'])
            ->assertOk();

        $this->withHeader('X-Firebase-Token', $this->hrToken)
            ->postJson('/app/categories/update_web_access.php', [
                'id' => $id,
                'web_attendance_allowed' => true,
            ])->assertForbidden();
    }

    public function test_the_list_is_readable_by_the_roles_that_filter_by_it(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/app/categories/list.php')->assertOk();
    }
}
