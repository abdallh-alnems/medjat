<?php

declare(strict_types=1);

namespace Tests\Feature\Warnings;

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
 * Disciplinary warnings on an employee's record.
 */
final class WarningTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

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

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Warned employee',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
        ]);

        $this->adminToken = $this->admin('general_manager');
    }

    private function admin(string $role): string
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
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
    private function issue(array $overrides = [], ?string $token = null): TestResponse
    {
        return $this->send('/app/warnings/add.php', $overrides + [
            'employee_id' => $this->employeeId,
            'type' => 'verbal',
            'reason' => 'Repeated lateness',
        ], $token);
    }

    public function test_a_warning_is_recorded_against_the_employee(): void
    {
        $id = Value::int($this->issue()->assertOk()->json('data.id'));

        $this->assertDatabaseHas('warnings', [
            'id' => $id,
            'employee_id' => $this->employeeId,
            'type' => 'verbal',
            'reason' => 'Repeated lateness',
        ]);
    }

    public function test_a_warning_with_no_reason_is_refused(): void
    {
        // A mark on somebody's record that nobody can explain later, including
        // whoever left it.
        $this->issue(['reason' => '   '])->assertStatus(422);
    }

    public function test_an_unknown_severity_is_refused(): void
    {
        $this->issue(['type' => 'shouting'])->assertStatus(422);
    }

    public function test_a_system_warning_type_cannot_be_issued_by_hand(): void
    {
        // Those belong to the security trail, not to a manager's judgement.
        $this->issue(['type' => 'device_change'])->assertStatus(422);
        $this->issue(['type' => 'system'])->assertStatus(422);
    }

    public function test_a_warning_can_be_withdrawn(): void
    {
        $id = Value::int($this->issue()->assertOk()->json('data.id'));

        $this->send('/app/warnings/delete.php', ['id' => $id])->assertOk();

        $this->assertDatabaseMissing('warnings', ['id' => $id]);
    }

    public function test_a_system_generated_warning_cannot_be_deleted(): void
    {
        // Otherwise a manager could quietly remove the record of a device swap
        // they made themselves.
        $id = (int) DB::table('warnings')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'type' => 'device_change',
            'reason' => 'Signed in from a new device',
        ]);

        $this->send('/app/warnings/delete.php', ['id' => $id])->assertStatus(403);

        $this->assertDatabaseHas('warnings', ['id' => $id]);
    }

    public function test_another_companys_warning_is_out_of_reach(): void
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
        $foreign = (int) DB::table('warnings')->insertGetId([
            'tenant_id' => $otherTenant,
            'employee_id' => $stranger,
            'type' => 'verbal',
            'reason' => 'Theirs',
        ]);

        $this->issue(['employee_id' => $stranger])->assertStatus(404);
        $this->send('/app/warnings/delete.php', ['id' => $foreign])->assertStatus(404);
    }

    public function test_a_viewer_cannot_warn_anybody(): void
    {
        $this->issue([], $this->admin('viewer'))->assertStatus(403);
    }
}
