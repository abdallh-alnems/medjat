<?php

declare(strict_types=1);

namespace Tests\Feature\Notifications;

use App\Models\EmployeeAuthToken;
use App\Modules\Notifications\Domain\Notifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * What the employee app shows in its bell.
 */
final class MyNotificationsTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $employeeId;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();

        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Notified employee',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
        ]);

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-bell',
        ]);
        $this->token = $plain;
    }

    private function notify(string $title = 'Something happened'): void
    {
        app(Notifier::class)->notifyEmployee(
            $this->tenantId, $this->employeeId, 'general',
            $title, $title, 'Body', 'Body',
        );
    }

    /**
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function bell(string $query = ''): TestResponse
    {
        return $this->withHeader('X-Employee-Token', $this->token)
            ->getJson('/app/notifications/list.php'.$query);
    }

    public function test_an_employee_with_no_linked_admin_account_still_sees_their_notifications(): void
    {
        // The original filtered on admin_id alone, which is null for nearly
        // every employee — so their bell was always empty however many
        // notifications had been written for them.
        $this->assertNull(DB::table('employees')->where('id', $this->employeeId)->value('admin_id'));

        $this->notify();

        $this->bell()
            ->assertOk()
            ->assertJsonCount(1, 'data.notifications')
            ->assertJsonPath('data.unread_count', 1);
    }

    public function test_notifications_addressed_to_the_linked_admin_account_also_arrive(): void
    {
        $adminId = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => 'uid-'.bin2hex(random_bytes(6)),
            'tenant_id' => $this->tenantId,
            'name' => 'Linked account',
            'role' => 'employee',
            'is_active' => 1,
        ]);
        DB::table('employees')->where('id', $this->employeeId)->update(['admin_id' => $adminId]);

        // Rows written the old way, before the port started addressing them by
        // employee.
        DB::table('notifications')->insert([
            'tenant_id' => $this->tenantId,
            'admin_id' => $adminId,
            'type' => 'general',
            'title' => 'Legacy row',
            'title_ar' => 'Legacy row',
            'body' => 'Body',
            'body_ar' => 'Body',
        ]);

        $this->bell()->assertOk()->assertJsonCount(1, 'data.notifications');
    }

    public function test_another_persons_notifications_are_not_visible(): void
    {
        $other = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Somebody else',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
        ]);

        app(Notifier::class)->notifyEmployee(
            $this->tenantId, $other, 'general', 'Theirs', 'Theirs', 'Body', 'Body',
        );

        $this->bell()->assertOk()->assertJsonCount(0, 'data.notifications');
    }

    public function test_the_list_can_be_narrowed_to_unread(): void
    {
        $this->notify('First');
        $this->notify('Second');

        DB::table('notifications')
            ->where('employee_id', $this->employeeId)->orderBy('id')->limit(1)
            ->update(['read_at' => DB::raw('NOW()')]);

        $this->bell('?unread_only=1')
            ->assertOk()
            ->assertJsonCount(1, 'data.notifications')
            ->assertJsonPath('data.unread_count', 1);
    }

    public function test_the_page_size_is_capped(): void
    {
        for ($i = 0; $i < 3; $i++) {
            $this->notify('Item '.$i);
        }

        $this->bell('?limit=2')->assertOk()->assertJsonCount(2, 'data.notifications');
        // Asking for more than the cap gets the cap, not an error.
        $this->bell('?limit=5000')->assertOk()->assertJsonCount(3, 'data.notifications');
    }

    public function test_one_can_be_marked_read(): void
    {
        $this->notify();
        $id = Value::int(DB::table('notifications')->where('employee_id', $this->employeeId)->value('id'));

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/app/notifications/read.php', ['id' => $id])
            ->assertOk();

        $this->bell()->assertOk()->assertJsonPath('data.unread_count', 0);
    }

    public function test_marking_one_twice_keeps_the_first_time(): void
    {
        $this->notify();
        $id = Value::int(DB::table('notifications')->where('employee_id', $this->employeeId)->value('id'));

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/app/notifications/read.php', ['id' => $id])->assertOk();

        $first = DB::table('notifications')->where('id', $id)->value('read_at');

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/app/notifications/read.php', ['id' => $id])->assertOk();

        // When it was seen, not when it was last clicked.
        $this->assertSame($first, DB::table('notifications')->where('id', $id)->value('read_at'));
    }

    public function test_somebody_elses_notification_cannot_be_marked_read(): void
    {
        $other = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Somebody else',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
        ]);

        app(Notifier::class)->notifyEmployee(
            $this->tenantId, $other, 'general', 'Theirs', 'Theirs', 'Body', 'Body',
        );

        $id = Value::int(DB::table('notifications')->where('employee_id', $other)->value('id'));

        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/app/notifications/read.php', ['id' => $id])
            ->assertStatus(404);

        $this->assertNull(DB::table('notifications')->where('id', $id)->value('read_at'));
    }

    public function test_a_missing_id_is_refused(): void
    {
        $this->withHeader('X-Employee-Token', $this->token)
            ->postJson('/app/notifications/read.php', [])
            ->assertStatus(400);
    }

    public function test_an_unauthenticated_request_is_refused(): void
    {
        $this->getJson('/app/notifications/list.php')->assertStatus(401);
    }
}
