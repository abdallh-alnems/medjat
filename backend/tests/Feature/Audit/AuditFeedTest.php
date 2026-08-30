<?php

declare(strict_types=1);

namespace Tests\Feature\Audit;

use App\Modules\Audit\Domain\AuditFeed;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The company's activity log, as a person reads it.
 */
final class AuditFeedTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $adminId;

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
        DB::table('audit_log')->where('tenant_id', $this->tenantId)->delete();

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Audited employee',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
        ]);

        [$this->adminId, $this->adminToken] = $this->admin('general_manager');
    }

    /**
     * @return array{0: int, 1: string}
     */
    private function admin(string $role): array
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        $id = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Admin '.$role,
            'role' => $role,
            'is_active' => 1,
        ]);

        return [$id, $this->firebase->issue($uid)];
    }

    /**
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function feed(string $query = '', ?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)
            ->getJson('/v1/audit'.$query);
    }

    public function test_the_feed_names_the_subject_rather_than_an_id(): void
    {
        // "employee.update on employee 412" is not an answer to anybody's
        // question.
        AuditLog::record($this->tenantId, $this->adminId, 'employee.update', 'employee', $this->employeeId);

        $this->feed()
            ->assertOk()
            ->assertJsonPath('data.items.0.action', 'employee.update')
            ->assertJsonPath('data.items.0.subject', 'Audited employee')
            ->assertJsonPath('data.items.0.admin_name', 'Admin general_manager');
    }

    public function test_a_target_that_is_not_a_number_resolves_to_no_subject(): void
    {
        // target_id is a varchar; some actions point at a code, not a row.
        AuditLog::record($this->tenantId, $this->adminId, 'tenant.update_settings', 'tenant', 'settings-hub');

        $this->feed()->assertOk()->assertJsonPath('data.items.0.subject', null);
    }

    public function test_system_written_rows_are_left_out(): void
    {
        // They belong to the cron logs, not to a feed of what people did.
        AuditLog::record($this->tenantId, null, 'leave.auto_rollover', 'tenant', $this->tenantId);
        AuditLog::record($this->tenantId, $this->adminId, 'employee.update', 'employee', $this->employeeId);

        $this->feed()->assertOk()->assertJsonCount(1, 'data.items');
    }

    public function test_the_feed_can_be_filtered_by_who_did_it(): void
    {
        [$other] = $this->admin('hr');

        AuditLog::record($this->tenantId, $this->adminId, 'employee.update', 'employee', $this->employeeId);
        AuditLog::record($this->tenantId, $other, 'employee.create', 'employee', $this->employeeId);

        $this->feed('?admin_id='.$other)
            ->assertOk()
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.action', 'employee.create');
    }

    public function test_the_feed_can_be_filtered_by_category(): void
    {
        AuditLog::record($this->tenantId, $this->adminId, 'payroll.approve', 'employee', $this->employeeId);
        AuditLog::record($this->tenantId, $this->adminId, 'employee.update', 'employee', $this->employeeId);

        $this->feed('?category=finance')
            ->assertOk()
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.action', 'payroll.approve');
    }

    public function test_an_unknown_category_is_ignored_rather_than_emptying_the_feed(): void
    {
        AuditLog::record($this->tenantId, $this->adminId, 'employee.update', 'employee', $this->employeeId);

        $this->feed('?category=astrology')->assertOk()->assertJsonCount(1, 'data.items');
    }

    public function test_the_actor_list_rides_along_with_the_first_page_only(): void
    {
        AuditLog::record($this->tenantId, $this->adminId, 'employee.update', 'employee', $this->employeeId);

        // The dropdown costs no extra round trip, and no repeat on every page.
        $this->feed()->assertOk()->assertJsonPath('data.actors.0.id', $this->adminId);
        $this->feed('?page=2')->assertOk()->assertJsonMissingPath('data.actors');
    }

    public function test_the_feed_pages_and_says_whether_there_is_more(): void
    {
        for ($i = 0; $i <= AuditFeed::PAGE_SIZE; $i++) {
            AuditLog::record($this->tenantId, $this->adminId, 'employee.update', 'employee', $this->employeeId);
        }

        $this->feed()
            ->assertOk()
            ->assertJsonCount(AuditFeed::PAGE_SIZE, 'data.items')
            ->assertJsonPath('data.has_more', true);

        $this->feed('?page=2')
            ->assertOk()
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.has_more', false);
    }

    public function test_another_companys_actions_are_not_visible(): void
    {
        $otherTenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Other company', 'timezone' => 'Africa/Cairo', 'is_active' => 1,
        ]);
        AuditLog::record($otherTenant, $this->adminId, 'employee.delete', 'employee', 1);

        $this->feed()->assertOk()->assertJsonCount(0, 'data.items');
    }

    public function test_the_log_is_gated_like_the_settings_hub(): void
    {
        // Reading it tells you what everybody in the company has been doing.
        [, $token] = $this->admin('viewer');

        $this->feed('', $token)->assertStatus(403);
    }
}
