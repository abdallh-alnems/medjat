<?php

declare(strict_types=1);

namespace Tests\Feature\Documents;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\CreatesFixtures;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The catalogue of documents a company asks for, who owes each one, and where
 * the company stands.
 */
final class RequiredDocumentTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private int $employeeId;

    private string $adminToken;

    private string $viewerToken;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = $this->createTenant();

        // The dump carries a company's real catalogue and staff; these cases
        // are about what this test creates.
        DB::table('employee_documents')->where('tenant_id', $this->tenantId)->delete();
        DB::table('required_documents')->where('tenant_id', $this->tenantId)->delete();
        DB::table('employees')->where('tenant_id', $this->tenantId)->update(['status' => 'terminated']);

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Docs branch',
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Docs employee',
            'status' => 'active',
            'base_salary' => 3000,
            'branch_id' => $this->branchId,
        ]);

        $this->adminToken = $this->admin($firebase, 'general_manager');
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

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function createType(array $overrides = []): int
    {
        $response = $this->asAdmin()
            ->postJson('/v1/documents/required', $overrides + [
                'name' => 'Passport',
                'category' => 'identity',
                'is_required' => 1,
            ])
            ->assertStatus(201);

        return Value::int($response->json('data.required_document_id'));
    }

    // ── The catalogue ────────────────────────────────────────────────────

    public function test_a_document_type_is_created_and_read_back(): void
    {
        $id = $this->createType();

        $this->asAdmin()->getJson('/v1/documents/required')
            ->assertOk()
            ->assertJsonPath('data.required_documents.0.id', $id)
            ->assertJsonPath('data.required_documents.0.name', 'Passport')
            ->assertJsonPath('data.required_documents.0.scope_type', 'all');
    }

    public function test_an_unknown_category_is_refused(): void
    {
        $this->asAdmin()->postJson('/v1/documents/required', [
            'name' => 'Nonsense',
            'category' => 'astrology',
        ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_category');
    }

    public function test_zero_expiry_days_means_never_expires(): void
    {
        // Not a document with a zero-day life.
        $id = $this->createType(['expiry_days' => 0]);

        $this->assertNull(DB::table('required_documents')->where('id', $id)->value('expiry_days'));
    }

    public function test_a_branch_scope_needs_a_branch(): void
    {
        $this->asAdmin()->postJson('/v1/documents/required', [
            'name' => 'Branch thing',
            'scope_type' => 'branch',
        ])->assertStatus(422)->assertJsonPath('error_code', 'scope_branch_id_required');
    }

    public function test_naming_people_requires_naming_at_least_one(): void
    {
        $this->asAdmin()->postJson('/v1/documents/required', [
            'name' => 'Named thing',
            'scope_type' => 'employees',
            'scope_employee_ids' => [],
        ])->assertStatus(400)->assertJsonPath('error_code', 'scope_employee_ids_required_scope');
    }

    public function test_a_named_scope_reports_the_people_in_it(): void
    {
        // Names travel with the ids so a client can render the scope without a
        // second round trip.
        $id = $this->createType([
            'name' => 'Named thing',
            'scope_type' => 'employees',
            'scope_employee_ids' => [$this->employeeId],
        ]);

        $this->asAdmin()->getJson('/v1/documents/required')
            ->assertOk()
            ->assertJsonPath('data.required_documents.0.id', $id)
            ->assertJsonPath('data.required_documents.0.scope_employees.0.name', 'Docs employee')
            ->assertJsonPath('data.required_documents.0.scope_employee_ids', [$this->employeeId]);
    }

    public function test_widening_the_scope_clears_the_membership_it_leaves_behind(): void
    {
        // Otherwise the old six rows would resurrect if the type were ever
        // narrowed again.
        $id = $this->createType([
            'scope_type' => 'employees',
            'scope_employee_ids' => [$this->employeeId],
        ]);

        $this->asAdmin()->postJson('/v1/documents/required/update', [
            'id' => $id,
            'scope_type' => 'all',
        ])->assertOk();

        $this->assertDatabaseMissing('required_document_employees', ['required_document_id' => $id]);
    }

    public function test_a_scope_is_replaced_wholesale_rather_than_added_to(): void
    {
        $other = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Someone else',
            'status' => 'active',
            'base_salary' => 1000,
            'branch_id' => $this->branchId,
        ]);

        $id = $this->createType([
            'scope_type' => 'employees',
            'scope_employee_ids' => [$this->employeeId],
        ]);

        $this->asAdmin()->postJson('/v1/documents/required/update', [
            'id' => $id,
            'scope_employee_ids' => [$other],
        ])->assertOk();

        $this->assertDatabaseHas('required_document_employees', [
            'required_document_id' => $id, 'employee_id' => $other,
        ]);
        $this->assertDatabaseMissing('required_document_employees', [
            'required_document_id' => $id, 'employee_id' => $this->employeeId,
        ]);
    }

    public function test_a_type_is_switched_off_without_being_deleted(): void
    {
        $id = $this->createType();

        $this->asAdmin()->postJson('/v1/documents/required/toggle', ['id' => $id])
            ->assertOk()
            ->assertJsonPath('data.is_active', false);

        $this->assertDatabaseHas('required_documents', ['id' => $id, 'is_active' => 0]);
    }

    public function test_a_type_can_be_deleted(): void
    {
        $id = $this->createType();

        $this->asAdmin()->postJson('/v1/documents/required/delete', ['id' => $id])->assertOk();

        $this->assertDatabaseMissing('required_documents', ['id' => $id]);
    }

    public function test_a_type_from_another_company_is_not_found(): void
    {
        $otherTenant = $this->createTenant();
        $stranger = (int) DB::table('required_documents')->insertGetId([
            'tenant_id' => $otherTenant,
            'name' => 'Somebody else\'s',
            'scope_type' => 'all',
        ]);

        $this->asAdmin()->postJson('/v1/documents/required/delete', ['id' => $stranger])
            ->assertNotFound();
        $this->assertDatabaseHas('required_documents', ['id' => $stranger]);
    }

    public function test_changing_the_catalogue_needs_more_than_reading_it(): void
    {
        // Reading and changing are deliberately different permissions.
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->postJson('/v1/documents/required', ['name' => 'Nope'])
            ->assertForbidden();
    }

    // ── Who owes what ────────────────────────────────────────────────────

    public function test_the_submissions_list_shows_everybody_who_owes_the_document(): void
    {
        $id = $this->createType();

        $this->asAdmin()->getJson('/v1/documents/required/submissions?required_document_id='.$id)
            ->assertOk()
            ->assertJsonPath('data.required_document.name', 'Passport')
            ->assertJsonPath('data.submissions.0.employee_name', 'Docs employee')
            // Nothing handed in yet.
            ->assertJsonPath('data.submissions.0.document', null);
    }

    public function test_a_handed_in_document_appears_against_its_owner(): void
    {
        $id = $this->createType();
        DB::table('employee_documents')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'required_document_id' => $id,
            'file_path' => 'documents/x.pdf',
            'original_name' => 'passport.pdf',
            'status' => 'uploaded',
        ]);

        $this->asAdmin()->getJson('/v1/documents/required/submissions?required_document_id='.$id)
            ->assertOk()
            ->assertJsonPath('data.submissions.0.document.status', 'uploaded')
            ->assertJsonPath('data.submissions.0.document.original_name', 'passport.pdf');
    }

    public function test_somebody_outside_the_scope_is_not_asked_for_it(): void
    {
        $otherBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Elsewhere',
        ]);
        $id = $this->createType([
            'name' => 'Branch thing',
            'scope_type' => 'branch',
            'scope_branch_id' => $otherBranch,
        ]);

        $submissions = $this->asAdmin()
            ->getJson('/v1/documents/required/submissions?required_document_id='.$id)
            ->assertOk()
            ->json('data.submissions');

        $this->assertSame([], $submissions);
    }

    // ── Compliance ───────────────────────────────────────────────────────

    public function test_a_document_never_handed_in_is_reported_missing(): void
    {
        $this->createType();

        $this->asAdmin()->getJson('/v1/documents/reports/missing')
            ->assertOk()
            ->assertJsonPath('data.missing_documents.0.employee_name', 'Docs employee')
            ->assertJsonPath('data.missing_documents.0.document_name', 'Passport');
    }

    public function test_an_optional_type_is_not_chased(): void
    {
        // A company chases what it requires; listing the rest as missing buries
        // the ones that matter.
        $this->createType(['is_required' => 0]);

        $missing = $this->asAdmin()->getJson('/v1/documents/reports/missing')
            ->assertOk()->json('data.missing_documents');

        $this->assertSame([], $missing);
    }

    public function test_a_switched_off_type_is_not_chased_either(): void
    {
        $id = $this->createType();
        $this->asAdmin()->postJson('/v1/documents/required/toggle', ['id' => $id])->assertOk();

        $missing = $this->asAdmin()->getJson('/v1/documents/reports/missing')
            ->assertOk()->json('data.missing_documents');

        $this->assertSame([], $missing);
    }

    public function test_a_document_about_to_lapse_is_reported(): void
    {
        $id = $this->createType();
        DB::table('employee_documents')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'required_document_id' => $id,
            'file_path' => 'documents/x.pdf',
            'status' => 'uploaded',
            'expires_at' => DB::raw('DATE_ADD(CURDATE(), INTERVAL 10 DAY)'),
        ]);

        $this->asAdmin()->getJson('/v1/documents/reports/expiring-soon?days_ahead=30')
            ->assertOk()
            ->assertJsonPath('data.documents.0.employee_name', 'Docs employee');
    }

    public function test_something_lapsing_beyond_the_window_is_not_reported(): void
    {
        $id = $this->createType();
        DB::table('employee_documents')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'required_document_id' => $id,
            'file_path' => 'documents/x.pdf',
            'status' => 'uploaded',
            'expires_at' => DB::raw('DATE_ADD(CURDATE(), INTERVAL 90 DAY)'),
        ]);

        $documents = $this->asAdmin()->getJson('/v1/documents/reports/expiring-soon?days_ahead=30')
            ->assertOk()->json('data.documents');

        $this->assertSame([], $documents);
    }

    public function test_something_already_lapsed_is_reported_before_anybody_runs_the_sweep(): void
    {
        // Otherwise the report shows nothing until a person remembers to press
        // a button, which is the wrong way round.
        $id = $this->createType();
        DB::table('employee_documents')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'required_document_id' => $id,
            'file_path' => 'documents/x.pdf',
            'status' => 'uploaded',
            'expires_at' => DB::raw('DATE_SUB(CURDATE(), INTERVAL 5 DAY)'),
        ]);

        $this->asAdmin()->getJson('/v1/documents/reports/expired')
            ->assertOk()
            ->assertJsonPath('data.documents.0.employee_name', 'Docs employee');
    }

    public function test_the_sweep_flips_lapsed_documents_and_says_how_many(): void
    {
        $id = $this->createType();
        DB::table('employee_documents')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'required_document_id' => $id,
            'file_path' => 'documents/x.pdf',
            'status' => 'uploaded',
            'expires_at' => DB::raw('DATE_SUB(CURDATE(), INTERVAL 5 DAY)'),
        ]);

        $this->asAdmin()->postJson('/v1/documents/mark-expired')
            ->assertOk()
            ->assertJsonPath('data.marked_expired', 1);

        $this->assertDatabaseHas('employee_documents', [
            'employee_id' => $this->employeeId,
            'status' => 'expired',
        ]);
    }

    public function test_the_stats_agree_with_the_reports(): void
    {
        $this->createType();
        $this->createType(['name' => 'Contract', 'category' => 'contract']);

        $this->asAdmin()->getJson('/v1/documents/reports/stats')
            ->assertOk()
            ->assertJsonPath('data.stats.total_required', 2)
            ->assertJsonPath('data.stats.total_missing', 2)
            ->assertJsonPath('data.stats.total_uploaded', 0);
    }

    public function test_reading_the_reports_needs_the_reports_permission(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/v1/documents/reports/stats')
            ->assertForbidden();
    }
}
