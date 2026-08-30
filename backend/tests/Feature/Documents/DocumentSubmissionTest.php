<?php

declare(strict_types=1);

namespace Tests\Feature\Documents;

use App\Models\Admin;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Handing documents in, reading them back, and asking for one.
 */
final class DocumentSubmissionTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private Employee $employee;

    private int $requiredId;

    private string $adminToken;

    private string $employeeToken;

    private FakePushSender $push;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('uploads');

        $firebase = new FakeFirebaseTokenVerifier;
        $this->push = new FakePushSender;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, $this->push);

        $this->employee = Employee::query()->where('status', 'active')->firstOrFail();
        $this->tenantId = $this->employee->tenant_id;

        $uid = 'uid-'.bin2hex(random_bytes(6));
        Admin::query()->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);
        $this->adminToken = $firebase->issue($uid);

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-a',
        ]);
        $this->employeeToken = $plain;

        $this->requiredId = (int) DB::table('required_documents')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Passport',
            'scope_type' => 'all',
            'is_required' => 1,
            'is_active' => 1,
        ]);
    }

    // ── Handing one in ───────────────────────────────────────────────────

    public function test_an_employee_can_submit_a_required_document(): void
    {
        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->post('/app/employees/submit_document.php', [
                'document_type_id' => $this->requiredId,
                'file' => UploadedFile::fake()->create('passport.pdf', 100, 'application/pdf'),
            ])
            ->assertOk()
            ->assertJsonPath('data.status', 'uploaded');

        $this->assertDatabaseHas('employee_documents', [
            'employee_id' => $this->employee->id,
            'required_document_id' => $this->requiredId,
            // The enum has no 'pending'; awaiting review is 'uploaded' with no
            // verified_at.
            'status' => 'uploaded',
        ]);
    }

    public function test_the_stored_name_is_generated_not_taken_from_the_upload(): void
    {
        // A filename chosen by the uploader is a path; the original is kept as
        // a label for the interface.
        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->post('/app/employees/submit_document.php', [
                'document_type_id' => $this->requiredId,
                'file' => UploadedFile::fake()->create('../../etc/passwd.pdf', 10, 'application/pdf'),
            ])->assertOk();

        $stored = Value::string(DB::table('employee_documents')
            ->where('employee_id', $this->employee->id)->orderByDesc('id')->value('file_path'));

        $this->assertStringStartsWith('documents/'.$this->tenantId.'/', $stored);
        $this->assertStringNotContainsString('..', $stored);
        $this->assertStringNotContainsString('passwd', $stored);
    }

    public function test_an_employee_cannot_file_against_a_requirement_that_is_not_theirs(): void
    {
        // Otherwise they could file against any requirement in the company,
        // including one scoped to somebody else entirely.
        $other = Employee::query()->whereKeyNot($this->employee->id)
            ->where('tenant_id', $this->tenantId)->firstOrFail();

        $scoped = (int) DB::table('required_documents')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Somebody else only',
            'scope_type' => 'employees',
            'is_required' => 1,
            'is_active' => 1,
        ]);
        DB::table('required_document_employees')->insert([
            'required_document_id' => $scoped,
            'employee_id' => $other->id,
            'tenant_id' => $this->tenantId,
        ]);

        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->post('/app/employees/submit_document.php', [
                'document_type_id' => $scoped,
                'file' => UploadedFile::fake()->create('x.pdf', 10, 'application/pdf'),
            ])->assertForbidden()->assertJsonPath('error_code', 'document_not_required');
    }

    public function test_a_disallowed_file_type_is_refused(): void
    {
        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->post('/app/employees/submit_document.php', [
                'document_type_id' => $this->requiredId,
                'file' => UploadedFile::fake()->create('payload.php', 10, 'application/x-php'),
            ])->assertStatus(400)->assertJsonPath('error_code', 'file_type_not_allowed');
    }

    public function test_an_oversized_file_is_refused(): void
    {
        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->post('/app/employees/submit_document.php', [
                'document_type_id' => $this->requiredId,
                'file' => UploadedFile::fake()->create('huge.pdf', 6000, 'application/pdf'),
            ])->assertStatus(400)->assertJsonPath('error_code', 'file_size_exceeds_limit');
    }

    public function test_no_file_is_refused(): void
    {
        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->post('/app/employees/submit_document.php', ['document_type_id' => $this->requiredId])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'no_file');
    }

    public function test_the_managers_are_told_a_document_is_waiting(): void
    {
        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->post('/app/employees/submit_document.php', [
                'document_type_id' => $this->requiredId,
                'file' => UploadedFile::fake()->create('passport.pdf', 10, 'application/pdf'),
            ])->assertOk();

        $this->assertDatabaseHas('notifications', [
            'tenant_id' => $this->tenantId,
            'type' => 'approval',
            'title_ar' => 'مستند بانتظار المراجعة',
        ]);

        $this->assertNotEmpty($this->push->sentToAdmins);
    }

    public function test_the_alert_carries_the_type_the_review_screen_opens_on(): void
    {
        // The management app opens the submissions screen for one document
        // *type*, so the uploaded row id alone is not enough.
        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->post('/app/employees/submit_document.php', [
                'document_type_id' => $this->requiredId,
                'file' => UploadedFile::fake()->create('passport.pdf', 10, 'application/pdf'),
            ])->assertOk();

        $last = end($this->push->sentToAdmins);
        $this->assertIsArray($last);
        $this->assertSame((string) $this->requiredId, $last['data']['required_document_id']);
    }

    public function test_an_administrator_can_file_on_somebodys_behalf(): void
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->post('/app/employees/upload_document.php', [
                'employee_id' => $this->employee->id,
                'document_type_id' => $this->requiredId,
                'file' => UploadedFile::fake()->create('scan.jpg', 10, 'image/jpeg'),
            ])->assertOk()->assertJsonStructure(['data' => ['document_id']]);
    }

    // ── Reading one back ─────────────────────────────────────────────────

    public function test_an_employee_reads_back_their_own_file(): void
    {
        Storage::disk('uploads')->put('documents/'.$this->tenantId.'/mine.pdf', 'the-file');

        $id = (int) DB::table('employee_documents')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'required_document_id' => $this->requiredId,
            'file_path' => 'documents/'.$this->tenantId.'/mine.pdf',
            'original_name' => 'mine.pdf',
            'mime_type' => 'application/pdf',
            'status' => 'uploaded',
        ]);

        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->get('/app/employees/my_document_view.php?id='.$id)
            ->assertOk()
            ->assertHeader('Content-Type', 'application/pdf')
            ->assertHeader('X-Content-Type-Options', 'nosniff');
    }

    public function test_an_employee_cannot_read_somebody_elses_file_by_counting(): void
    {
        // The id is a small integer; without the ownership check this hands out
        // the identity documents of everyone in the company.
        $other = Employee::query()->whereKeyNot($this->employee->id)
            ->where('tenant_id', $this->tenantId)->firstOrFail();

        Storage::disk('uploads')->put('documents/'.$this->tenantId.'/theirs.pdf', 'not-yours');

        $id = (int) DB::table('employee_documents')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $other->id,
            'required_document_id' => $this->requiredId,
            'file_path' => 'documents/'.$this->tenantId.'/theirs.pdf',
            'status' => 'uploaded',
        ]);

        $this->withHeader('X-Employee-Token', $this->employeeToken)
            ->get('/app/employees/my_document_view.php?id='.$id)
            ->assertNotFound();
    }

    // ── Asking for one ───────────────────────────────────────────────────

    public function test_a_custom_request_applies_to_that_person_only(): void
    {
        $response = $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->postJson('/app/employees/request_document.php', [
                'employee_id' => $this->employee->id,
                'name' => 'Driving licence',
            ])->assertOk()->assertJsonPath('data.custom', true);

        $id = Value::int($response->json('data.required_document_id'));

        $this->assertSame('employees', DB::table('required_documents')->where('id', $id)->value('scope_type'));
        $this->assertDatabaseHas('required_document_employees', [
            'required_document_id' => $id,
            'employee_id' => $this->employee->id,
        ]);
    }

    public function test_requesting_a_type_the_employee_already_has_is_idempotent(): void
    {
        // Saying so beats silently creating a second copy of a requirement they
        // already have.
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->postJson('/app/employees/request_document.php', [
                'employee_id' => $this->employee->id,
                'required_document_id' => $this->requiredId,
            ])->assertOk()->assertJsonPath('data.already_requested', true);
    }

    public function test_requesting_a_branch_scoped_type_copies_it_rather_than_widening_it(): void
    {
        // Asking one person for something must not quietly put it on
        // everybody's checklist.
        $branchScoped = (int) DB::table('required_documents')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Branch only',
            'scope_type' => 'branch',
            'scope_branch_id' => 999999,
            'is_required' => 1,
            'is_active' => 1,
        ]);

        $response = $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->postJson('/app/employees/request_document.php', [
                'employee_id' => $this->employee->id,
                'required_document_id' => $branchScoped,
            ])->assertOk()->assertJsonPath('data.already_requested', false);

        $newId = Value::int($response->json('data.required_document_id'));

        $this->assertNotSame($branchScoped, $newId);
        $this->assertSame('branch', DB::table('required_documents')->where('id', $branchScoped)->value('scope_type'));
        $this->assertSame('employees', DB::table('required_documents')->where('id', $newId)->value('scope_type'));
    }

    public function test_an_unknown_catalogue_type_is_not_found(): void
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->postJson('/app/employees/request_document.php', [
                'employee_id' => $this->employee->id,
                'required_document_id' => 999999,
            ])->assertNotFound();
    }
}
