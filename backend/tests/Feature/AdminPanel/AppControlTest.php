<?php

declare(strict_types=1);

namespace Tests\Feature\AdminPanel;

use App\Domain\Notifications\PushSender;
use App\Domain\SuperAdmin\SuperAdminSession;
use App\Services\RemoteConfig\RemoteConfigAdmin;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakePushSender;
use Tests\Support\FakeRemoteConfigAdmin;
use Tests\TestCase;

/**
 * The minimum build each app may run, and whether it is in maintenance.
 */
final class AppControlTest extends TestCase
{
    use DatabaseTransactions;

    private FakeRemoteConfigAdmin $config;

    private FakePushSender $push;

    private int $adminId;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();

        $this->config = new FakeRemoteConfigAdmin;
        $this->push = new FakePushSender;
        $this->app->instance(RemoteConfigAdmin::class, $this->config);
        $this->app->instance(PushSender::class, $this->push);

        [$this->adminId, $this->token] = $this->operator('superadmin');
    }

    /**
     * @return array{0: int, 1: string}
     */
    private function operator(string $role): array
    {
        $id = (int) DB::table('super_admins')->insertGetId([
            'username' => 'op-'.bin2hex(random_bytes(5)),
            // Cheapest cost the algorithm allows: nothing here verifies it,
            // and the default cost adds seconds across a suite this size.
            'password_hash' => password_hash('irrelevant', PASSWORD_BCRYPT, ['cost' => 4]),
            'display_name' => 'Operator '.$role,
            'role' => $role,
            'is_active' => 1,
        ]);

        $session = SuperAdminSession::open($id, '127.0.0.1', 'phpunit');

        return [$id, $session['token']];
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function save(array $payload, ?string $token = null): TestResponse
    {
        return $this->withHeader('Authorization', 'Bearer '.($token ?? $this->token))
            ->postJson('/app/admin_app_control/set.php', $payload);
    }

    public function test_the_panel_lists_every_app_it_can_operate(): void
    {
        $this->withHeader('Authorization', 'Bearer '.$this->token)
            ->getJson('/app/admin_app_control/get.php')
            ->assertOk()
            ->assertJsonCount(3, 'data.apps')
            ->assertJsonPath('data.apps.0.key', 'medjat_app');
    }

    public function test_the_kiosk_is_listed_and_settable_like_the_others(): void
    {
        // Its card is rendered from the same list, so leaving it out of the
        // save path made the card answer 422 on every press.
        $this->save(['app' => 'medjat_kiosk', 'maintenance' => true])->assertOk();

        $this->assertTrue($this->config->state['medjat_kiosk']['maintenance']);
    }

    public function test_raising_the_minimum_version_records_what_it_was(): void
    {
        $this->save(['app' => 'medjat_app', 'min_version' => '2.4.0'])
            ->assertOk()
            ->assertJsonPath('data.min_version', '2.4.0');

        $this->assertDatabaseHas('super_admin_audit_log', [
            'admin_id' => $this->adminId,
            'action' => 'app_control.set_version',
        ]);

        $payload = json_decode(Value::string(DB::table('super_admin_audit_log')
            ->where('action', 'app_control.set_version')->orderByDesc('id')->value('payload')), true);
        $this->assertIsArray($payload);
        // The previous value, so somebody can undo a lock-out without guessing.
        $this->assertSame('1.0.0', $payload['from'] ?? null);
    }

    public function test_maintenance_is_pushed_to_the_apps_topic_immediately(): void
    {
        // Remote Config's realtime stream only reaches a foregrounded app, so
        // without this the switch takes effect whenever each device next
        // happens to look.
        $this->save(['app' => 'medjat_central', 'maintenance' => true])->assertOk();

        $this->assertCount(1, $this->push->sentToTopics);
        $this->assertSame('maintenance_medjat_central', $this->push->sentToTopics[0]['topic']);
        $this->assertSame('1', $this->push->sentToTopics[0]['data']['enabled']);
    }

    public function test_turning_maintenance_off_pushes_too(): void
    {
        $this->config->state['medjat_app']['maintenance'] = true;

        $this->save(['app' => 'medjat_app', 'maintenance' => false])->assertOk();

        $this->assertSame('0', $this->push->sentToTopics[0]['data']['enabled']);
    }

    public function test_both_can_be_changed_in_one_call(): void
    {
        $this->save(['app' => 'medjat_app', 'min_version' => '3.0.0', 'maintenance' => true])
            ->assertOk()
            ->assertJsonPath('data.min_version', '3.0.0')
            ->assertJsonPath('data.maintenance', true);
    }

    public function test_an_unknown_app_is_refused(): void
    {
        $this->save(['app' => 'medjat_watch', 'maintenance' => true])->assertStatus(422);
    }

    public function test_a_malformed_version_is_refused(): void
    {
        $this->save(['app' => 'medjat_app', 'min_version' => 'v2'])->assertStatus(422);
        $this->save(['app' => 'medjat_app', 'min_version' => '2.4.0-beta'])->assertStatus(422);

        $this->assertSame('1.0.0', $this->config->state['medjat_app']['min_version']);
    }

    public function test_a_non_boolean_maintenance_flag_is_refused(): void
    {
        $this->save(['app' => 'medjat_app', 'maintenance' => 'yes'])->assertStatus(422);
    }

    public function test_a_call_that_changes_nothing_is_refused(): void
    {
        $this->save(['app' => 'medjat_app'])->assertStatus(422);
    }

    public function test_only_a_superadmin_may_operate_the_gate(): void
    {
        // Raising a minimum locks out every installed build below it, and for
        // the kiosk somebody must physically visit each branch.
        [, $token] = $this->operator('admin');

        $this->save(['app' => 'medjat_app', 'maintenance' => true], $token)->assertStatus(403);

        $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/app/admin_app_control/get.php')
            ->assertStatus(403);
    }

    public function test_a_request_with_no_session_is_refused(): void
    {
        $this->getJson('/app/admin_app_control/get.php')->assertStatus(401);
        $this->withHeader('Authorization', 'Bearer not-a-token')
            ->getJson('/app/admin_app_control/get.php')
            ->assertStatus(401);
    }

    public function test_a_disabled_operator_is_refused(): void
    {
        DB::table('super_admins')->where('id', $this->adminId)->update(['is_active' => 0]);

        $this->withHeader('Authorization', 'Bearer '.$this->token)
            ->getJson('/app/admin_app_control/get.php')
            ->assertStatus(403);
    }

    public function test_an_expired_session_is_refused_and_cleaned_up(): void
    {
        DB::table('super_admin_sessions')
            ->where('token_hash', SuperAdminSession::hash($this->token))
            ->update(['expires_at' => DB::raw('DATE_SUB(NOW(), INTERVAL 1 HOUR)')]);

        $this->withHeader('Authorization', 'Bearer '.$this->token)
            ->getJson('/app/admin_app_control/get.php')
            ->assertStatus(401);

        // A stale hash is exactly the thing worth not keeping.
        $this->assertDatabaseMissing('super_admin_sessions', [
            'token_hash' => SuperAdminSession::hash($this->token),
        ]);
    }
}
