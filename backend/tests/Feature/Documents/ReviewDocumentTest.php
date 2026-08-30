<?php

declare(strict_types=1);

namespace Tests\Feature\Documents;

use App\Models\Admin;
use App\Models\CustomRole;
use App\Models\Employee;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Reviewing an employee's paperwork.
 */
final class ReviewDocumentTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private Employee $employee;

    private int $requiredId;

    private int $documentId;

    private string $token;

    private Admin $admin;

    private FakePushSender $push;

    private FakeFirebaseTokenVerifier $firebase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->push = new FakePushSender;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
        $this->app->instance(PushSender::class, $this->push);

        $this->employee = Employee::query()->where('status', 'active')->firstOrFail();
        $this->tenantId = $this->employee->tenant_id;

        [$this->admin, $this->token] = $this->admin();

        $this->requiredId = (int) DB::table('required_documents')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Passport',
            'scope_type' => 'all',
            'is_required' => 1,
            'is_active' => 1,
        ]);

        $this->documentId = (int) DB::table('employee_documents')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'required_document_id' => $this->requiredId,
            'file_path' => 'documents/passport.pdf',
            'original_name' => 'passport.pdf',
            // The enum has no 'pending': an upload awaiting review is
            // 'uploaded' with no verified_at.
            'status' => 'uploaded',
        ]);
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

    public function test_verifying_records_who_approved_it_and_when(): void
    {
        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/verify_document.php', ['document_id' => $this->documentId])
            ->assertOk();

        $row = DB::table('employee_documents')->where('id', $this->documentId)->first();
        $this->assertNotNull($row);
        $this->assertSame('uploaded', $row->status);
        $this->assertNotNull($row->verified_at);
        $this->assertSame($this->admin->id, Value::int($row->verified_by));
    }

    public function test_the_employee_is_told_their_document_was_approved(): void
    {
        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/verify_document.php', ['document_id' => $this->documentId])
            ->assertOk();

        $this->assertDatabaseHas('notifications', [
            'employee_id' => $this->employee->id,
            'type' => 'approval',
            'title_ar' => 'تم قبول مستندك',
        ]);

        $this->assertCount(1, $this->push->sent);
    }

    public function test_a_rejection_carries_the_reason_to_the_employee(): void
    {
        // "Rejected" on its own tells them nothing they can act on, and they
        // will upload the same file again.
        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/reject_document.php', [
                'document_id' => $this->documentId,
                'reason' => 'الصورة غير واضحة',
            ])->assertOk();

        $this->assertSame(
            'rejected',
            DB::table('employee_documents')->where('id', $this->documentId)->value('status')
        );

        $body = $this->push->lastBody();
        $this->assertIsString($body);
        $this->assertStringContainsString('الصورة غير واضحة', $body);
    }

    public function test_a_rejection_without_a_reason_is_refused(): void
    {
        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/reject_document.php', ['document_id' => $this->documentId])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'missing_fields');
    }

    public function test_a_rejection_clears_a_previous_approval(): void
    {
        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/verify_document.php', ['document_id' => $this->documentId])->assertOk();

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/reject_document.php', [
                'document_id' => $this->documentId, 'reason' => 'Expired',
            ])->assertOk();

        $row = DB::table('employee_documents')->where('id', $this->documentId)->first();
        $this->assertNotNull($row);
        $this->assertNull($row->verified_at);
        $this->assertNull($row->verified_by);
    }

    public function test_approving_clears_a_previous_rejection_reason(): void
    {
        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/reject_document.php', [
                'document_id' => $this->documentId, 'reason' => 'Blurred',
            ])->assertOk();

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/verify_document.php', ['document_id' => $this->documentId])->assertOk();

        $this->assertNull(
            DB::table('employee_documents')->where('id', $this->documentId)->value('rejected_reason')
        );
    }

    public function test_a_failed_push_does_not_fail_the_decision(): void
    {
        // An approved document stays approved whether or not the phone was
        // reachable.
        $this->push->fails = true;

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/verify_document.php', ['document_id' => $this->documentId])
            ->assertOk();

        $row = DB::table('employee_documents')->where('id', $this->documentId)->first();
        $this->assertNotNull($row);
        $this->assertNotNull($row->verified_at, 'approval is recorded by who and when');
    }

    public function test_managing_documents_carries_verifying_with_it(): void
    {
        // Verifying was split out of managing after the fact. Anyone who could
        // already manage documents keeps it, rather than losing access on the
        // day of the split.
        [$admin, $token] = $this->admin(['role' => 'hr']);
        CustomRole::query()->create([
            'tenant_id' => $this->tenantId,
            'admin_id' => $admin->id,
            'name' => 'Documents',
            'permissions' => ['manage_documents'],
        ]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/employees/verify_document.php', ['document_id' => $this->documentId])
            ->assertOk();
    }

    public function test_somebody_with_neither_permission_cannot_verify(): void
    {
        [$admin, $token] = $this->admin(['role' => 'attendance']);
        CustomRole::query()->create([
            'tenant_id' => $this->tenantId,
            'admin_id' => $admin->id,
            'name' => 'Attendance only',
            'permissions' => ['manage_attendance'],
        ]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/app/employees/verify_document.php', ['document_id' => $this->documentId])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'missing_permission');
    }

    public function test_a_document_from_another_company_is_not_found(): void
    {
        $other = DB::table('employee_documents')->where('tenant_id', '!=', $this->tenantId)->value('id');
        if ($other === null) {
            $this->markTestSkipped('needs a document in another company');
        }

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/verify_document.php', ['document_id' => Value::int($other)])
            ->assertNotFound();
    }

    public function test_an_expiry_can_be_set_and_cleared(): void
    {
        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/update_document.php', [
                'document_id' => $this->documentId, 'expires_at' => '2027-01-01',
            ])->assertOk();

        $this->assertSame(
            '2027-01-01',
            DB::table('employee_documents')->where('id', $this->documentId)->value('expires_at')
        );

        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/update_document.php', [
                'document_id' => $this->documentId, 'expires_at' => '',
            ])->assertOk();

        $this->assertNull(
            DB::table('employee_documents')->where('id', $this->documentId)->value('expires_at')
        );
    }

    public function test_a_malformed_expiry_is_refused(): void
    {
        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/update_document.php', [
                'document_id' => $this->documentId, 'expires_at' => 'next tuesday',
            ])->assertStatus(400)->assertJsonPath('error_code', 'invalid_date');
    }

    public function test_the_checklist_lists_requirements_with_nothing_uploaded(): void
    {
        // The employee sees what is expected of them rather than an empty
        // screen.
        DB::table('employee_documents')->where('id', $this->documentId)->delete();

        $documents = $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/app/employees/get_documents.php?employee_id='.$this->employee->id)
            ->assertOk()
            ->json('data.required_documents');

        $this->assertIsArray($documents);
        $this->assertContains('required', array_column($documents, 'status'));
    }

    public function test_a_rejected_document_still_counts_as_missing(): void
    {
        // The requirement is unmet whether nothing arrived or the wrong thing
        // did.
        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/reject_document.php', [
                'document_id' => $this->documentId, 'reason' => 'Wrong document',
            ])->assertOk();

        $missing = $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/app/employees/get_missing_documents.php?employee_id='.$this->employee->id)
            ->assertOk()
            ->json('data.missing_documents');

        $this->assertIsArray($missing);
        $this->assertContains($this->requiredId, array_column($missing, 'required_document_id'));
    }

    public function test_a_verified_document_is_not_missing(): void
    {
        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/verify_document.php', ['document_id' => $this->documentId])->assertOk();

        $missing = $this->withHeader('X-Firebase-Token', $this->token)
            ->getJson('/app/employees/get_missing_documents.php?employee_id='.$this->employee->id)
            ->assertOk()
            ->json('data.missing_documents');

        $this->assertIsArray($missing);
        $this->assertNotContains($this->requiredId, array_column($missing, 'required_document_id'));
    }

    public function test_deleting_removes_the_upload_but_leaves_the_requirement(): void
    {
        $this->withHeader('X-Firebase-Token', $this->token)
            ->postJson('/app/employees/delete_document.php', ['document_id' => $this->documentId])
            ->assertOk();

        $this->assertDatabaseMissing('employee_documents', ['id' => $this->documentId]);
        $this->assertDatabaseHas('required_documents', ['id' => $this->requiredId]);
    }
}
