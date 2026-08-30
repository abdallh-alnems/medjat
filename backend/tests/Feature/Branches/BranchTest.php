<?php

declare(strict_types=1);

namespace Tests\Feature\Branches;

use App\Domain\Notifications\PushSender;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Branches, their attendance settings, and the networks that mean "here".
 */
final class BranchTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private string $adminToken;

    private string $viewerToken;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        DB::table('tenants')->where('id', $this->tenantId)
            ->update(['attendance_methods' => json_encode(['qr_gps'])]);

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Head office',
            'latitude' => 30.0444,
            'longitude' => 31.2357,
            'gps_radius_meters' => 100,
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

    // ── The list ─────────────────────────────────────────────────────────

    public function test_a_branch_is_created_with_a_qr_payload_ready(): void
    {
        // So a poster can be printed the moment the branch exists, rather than
        // after somebody remembers to ask for one.
        $response = $this->asAdmin()->postJson('/app/branches/create.php', [
            'name' => 'New site',
            'latitude' => 30.1,
            'longitude' => 31.3,
        ])->assertStatus(201);

        $id = Value::int($response->json('data.branch_id'));
        $qr = Value::string(DB::table('branches')->where('id', $id)->value('qr_code'));

        $this->assertStringStartsWith('MED-', $qr);
    }

    public function test_the_list_counts_who_works_there_now(): void
    {
        // Not who ever did: a branch's headcount is a present-tense question.
        DB::table('employees')->insert([
            ['tenant_id' => $this->tenantId, 'name' => 'Here', 'status' => 'active',
                'base_salary' => 1000, 'branch_id' => $this->branchId],
            ['tenant_id' => $this->tenantId, 'name' => 'Gone', 'status' => 'terminated',
                'base_salary' => 1000, 'branch_id' => $this->branchId],
        ]);

        $branches = $this->asAdmin()->getJson('/app/branches/list.php')->assertOk()->json('data.branches');
        $this->assertIsArray($branches);

        foreach ($branches as $branch) {
            if (is_array($branch) && Value::int($branch['id']) === $this->branchId) {
                $this->assertSame(1, Value::int($branch['employee_count']));
            }
        }
    }

    public function test_the_list_is_open_to_anybody_signed_in(): void
    {
        // Every screen with a branch picker needs it; gating it would break
        // navigation for roles that can legitimately reach those screens.
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/app/branches/list.php')->assertOk();
    }

    public function test_changing_a_branch_needs_the_settings_permission(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->postJson('/app/branches/update.php', ['branch_id' => $this->branchId, 'name' => 'Nope'])
            ->assertForbidden();
    }

    // ── Settings ─────────────────────────────────────────────────────────

    public function test_a_branch_can_override_the_pay_cycle_or_inherit_it(): void
    {
        $this->asAdmin()->postJson('/app/branches/update.php', [
            'branch_id' => $this->branchId,
            'cycle_start_day' => 26,
        ])->assertOk();

        $this->assertDatabaseHas('branches', ['id' => $this->branchId, 'cycle_start_day' => 26]);

        // Null means inherit the company's, which is different from choosing
        // the first of the month.
        $this->asAdmin()->postJson('/app/branches/update.php', [
            'branch_id' => $this->branchId,
            'cycle_start_day' => null,
        ])->assertOk();

        $this->assertNull(DB::table('branches')->where('id', $this->branchId)->value('cycle_start_day'));
    }

    public function test_a_cycle_day_past_the_end_of_february_is_refused(): void
    {
        $this->asAdmin()->postJson('/app/branches/update.php', [
            'branch_id' => $this->branchId,
            'cycle_start_day' => 30,
        ])->assertStatus(422)->assertJsonPath('error_code', 'cycle_start_day_between_1');
    }

    public function test_an_absurd_geofence_radius_is_refused(): void
    {
        $this->asAdmin()->postJson('/app/branches/update.php', [
            'branch_id' => $this->branchId,
            'gps_radius_meters' => 99999,
        ])->assertStatus(422)->assertJsonPath('error_code', 'gps_radius_meters_between_5');
    }

    public function test_a_qr_payload_is_kept_unless_regeneration_is_asked_for(): void
    {
        $first = Value::string(
            $this->asAdmin()->postJson('/app/branches/generate_qr.php', ['branch_id' => $this->branchId])
                ->assertOk()->json('data.qr_code')
        );

        $again = Value::string(
            $this->asAdmin()->postJson('/app/branches/generate_qr.php', ['branch_id' => $this->branchId])
                ->assertOk()->json('data.qr_code')
        );

        $this->assertSame($first, $again);

        $forced = Value::string(
            $this->asAdmin()->postJson('/app/branches/generate_qr.php', [
                'branch_id' => $this->branchId,
                'force' => 1,
            ])->assertOk()->json('data.qr_code')
        );

        $this->assertNotSame($first, $forced);
    }

    // ── Attendance methods ───────────────────────────────────────────────

    public function test_a_branch_can_set_its_own_methods(): void
    {
        $this->asAdmin()->postJson('/app/branches/update_attendance_method.php', [
            'branch_id' => $this->branchId,
            'attendance_methods' => ['gps_only', 'face_selfie'],
            'gps_radius_meters' => 150,
        ])->assertOk();

        $stored = Value::string(DB::table('branches')->where('id', $this->branchId)->value('attendance_methods'));

        $this->assertSame(['gps_only', 'face_selfie'], json_decode($stored, true));
    }

    public function test_an_empty_method_list_is_refused(): void
    {
        // It would mean nobody can record attendance at all, which is never
        // what somebody meant to say.
        $this->asAdmin()->postJson('/app/branches/update_attendance_method.php', [
            'branch_id' => $this->branchId,
            'attendance_methods' => [],
        ])->assertStatus(400)->assertJsonPath('error_code', 'attendance_methods_cannot_empty_null');
    }

    public function test_an_unknown_method_is_refused(): void
    {
        $this->asAdmin()->postJson('/app/branches/update_attendance_method.php', [
            'branch_id' => $this->branchId,
            'attendance_methods' => ['telepathy'],
        ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_attendance_method');
    }

    public function test_rotating_qr_is_refused_where_it_would_do_nothing(): void
    {
        // A switch that silently does nothing is worse than one that explains
        // itself.
        $this->asAdmin()->postJson('/app/branches/update_attendance_method.php', [
            'branch_id' => $this->branchId,
            'attendance_methods' => ['gps_only'],
            'rotating_qr_enabled' => true,
        ])->assertStatus(422)->assertJsonPath('error_code', 'rotating_qr_requires_qr_gps');
    }

    public function test_rotating_qr_is_allowed_on_a_branch_that_uses_qr(): void
    {
        $this->asAdmin()->postJson('/app/branches/update_attendance_method.php', [
            'branch_id' => $this->branchId,
            'attendance_methods' => ['qr_gps'],
            'rotating_qr_enabled' => true,
        ])->assertOk();

        $this->assertDatabaseHas('branches', ['id' => $this->branchId, 'rotating_qr_enabled' => 1]);
    }

    public function test_a_branch_inheriting_the_company_methods_may_still_enable_rotating_qr(): void
    {
        // Null methods means inherit, and the company is on qr_gps.
        $this->asAdmin()->postJson('/app/branches/update_attendance_method.php', [
            'branch_id' => $this->branchId,
            'attendance_methods' => null,
            'rotating_qr_enabled' => true,
        ])->assertOk();
    }

    public function test_a_face_threshold_outside_the_usable_band_is_refused(): void
    {
        $this->asAdmin()->postJson('/app/branches/update_attendance_method.php', [
            'branch_id' => $this->branchId,
            'face_match_threshold' => 0.99,
        ])->assertStatus(422)->assertJsonPath('error_code', 'face_match_threshold_range');
    }

    // ── Networks ─────────────────────────────────────────────────────────

    public function test_capturing_a_network_from_inside_the_branch_approves_it(): void
    {
        $this->asAdmin()->postJson('/app/branches/capture_network.php', [
            'branch_id' => $this->branchId,
            'bssid' => 'AA:BB:CC:DD:EE:01',
            'ssid' => 'Office',
            'latitude' => 30.0444,
            'longitude' => 31.2357,
        ])->assertOk()->assertJsonPath('data.bssid', 'aa:bb:cc:dd:ee:01');

        $this->assertDatabaseHas('branch_networks', [
            'branch_id' => $this->branchId,
            'kind' => 'bssid',
            'value' => 'aa:bb:cc:dd:ee:01',
            'is_active' => 1,
        ]);
    }

    public function test_capturing_from_somewhere_else_is_refused(): void
    {
        // If an administrator captured their home router, that home would
        // become the branch's valid location and the office would be locked out.
        $this->asAdmin()->postJson('/app/branches/capture_network.php', [
            'branch_id' => $this->branchId,
            'bssid' => 'AA:BB:CC:DD:EE:02',
            'latitude' => 31.5,
            'longitude' => 30.0,
        ])->assertForbidden()->assertJsonPath('error_code', 'CAPTURE_OUTSIDE_BRANCH');

        $this->assertDatabaseMissing('branch_networks', ['value' => 'aa:bb:cc:dd:ee:02']);
    }

    public function test_the_first_capture_starts_the_branch_learning(): void
    {
        // The remaining access points still need discovering before enforcement
        // makes sense.
        $this->asAdmin()->postJson('/app/branches/capture_network.php', [
            'branch_id' => $this->branchId,
            'bssid' => 'AA:BB:CC:DD:EE:03',
            'latitude' => 30.0444,
            'longitude' => 31.2357,
        ])->assertOk();

        $this->assertDatabaseHas('branches', ['id' => $this->branchId, 'wifi_mode' => 'learning']);
    }

    public function test_capturing_without_a_network_says_so(): void
    {
        $this->asAdmin()->postJson('/app/branches/capture_network.php', [
            'branch_id' => $this->branchId,
            'latitude' => 30.0444,
            'longitude' => 31.2357,
        ])->assertStatus(422)->assertJsonPath('error_code', 'WIFI_NOT_CONNECTED');
    }

    public function test_a_batch_of_networks_is_approved(): void
    {
        $this->asAdmin()->postJson('/app/branches/approve_networks.php', [
            'branch_id' => $this->branchId,
            'approve' => [
                ['kind' => 'bssid', 'value' => 'AA:BB:CC:DD:EE:04', 'label' => '2.4 GHz'],
                ['kind' => 'bssid', 'value' => 'AA:BB:CC:DD:EE:05', 'label' => '5 GHz'],
            ],
        ])->assertOk()->assertJsonPath('data.approved', 2);

        // One router is several networks; approving only some locks out
        // whoever's phone prefers the other.
        $this->assertSame(2, DB::table('branch_networks')->where('branch_id', $this->branchId)->count());
    }

    public function test_an_invalid_address_is_refused(): void
    {
        $this->asAdmin()->postJson('/app/branches/approve_networks.php', [
            'branch_id' => $this->branchId,
            'approve' => [['kind' => 'bssid', 'value' => 'not-a-bssid']],
        ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_bssid');
    }

    public function test_an_invalid_subnet_is_refused(): void
    {
        $this->asAdmin()->postJson('/app/branches/approve_networks.php', [
            'branch_id' => $this->branchId,
            'approve' => [['kind' => 'ip_cidr', 'value' => '10.0.0.0/64']],
        ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_cidr');
    }

    public function test_re_approving_revives_a_network_that_was_switched_off(): void
    {
        $this->asAdmin()->postJson('/app/branches/approve_networks.php', [
            'branch_id' => $this->branchId,
            'approve' => [['kind' => 'bssid', 'value' => 'AA:BB:CC:DD:EE:06']],
        ])->assertOk();

        $id = Value::int(DB::table('branch_networks')->where('value', 'aa:bb:cc:dd:ee:06')->value('id'));

        $this->asAdmin()->postJson('/app/branches/approve_networks.php', [
            'branch_id' => $this->branchId,
            'deactivate' => [$id],
        ])->assertOk()->assertJsonPath('data.deactivated', 1);

        $this->assertDatabaseHas('branch_networks', ['id' => $id, 'is_active' => 0]);

        $this->asAdmin()->postJson('/app/branches/approve_networks.php', [
            'branch_id' => $this->branchId,
            'approve' => [['kind' => 'bssid', 'value' => 'AA:BB:CC:DD:EE:06']],
        ])->assertOk();

        // Switched off rather than deleted, so the same row comes back.
        $this->assertDatabaseHas('branch_networks', ['id' => $id, 'is_active' => 1]);
    }

    public function test_enforcement_cannot_be_switched_on_with_nothing_approved(): void
    {
        // It would lock every employee out of the branch on the next shift.
        $this->asAdmin()->postJson('/app/branches/approve_networks.php', [
            'branch_id' => $this->branchId,
            'wifi_mode' => 'enforcing',
        ])->assertStatus(422)->assertJsonPath('error_code', 'no_approved_networks');
    }

    public function test_enforcement_is_allowed_once_something_is_approved(): void
    {
        $this->asAdmin()->postJson('/app/branches/approve_networks.php', [
            'branch_id' => $this->branchId,
            'approve' => [['kind' => 'bssid', 'value' => 'AA:BB:CC:DD:EE:07']],
            'wifi_mode' => 'enforcing',
        ])->assertOk();

        $this->assertDatabaseHas('branches', ['id' => $this->branchId, 'wifi_mode' => 'enforcing']);
    }

    public function test_the_sightings_screen_reports_coverage_before_the_switch_is_flipped(): void
    {
        // It answers "if I approve exactly these and enforce, what share of
        // last week's check-ins would still pass?".
        $employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Seen here',
            'status' => 'active',
            'base_salary' => 1000,
            'branch_id' => $this->branchId,
        ]);

        foreach ([['aa:bb:cc:dd:ee:10', 1, 8], ['aa:bb:cc:dd:ee:11', 0, 2]] as [$bssid, $inside, $times]) {
            for ($i = 0; $i < $times; $i++) {
                DB::table('branch_network_sightings')->insert([
                    'tenant_id' => $this->tenantId,
                    'branch_id' => $this->branchId,
                    'employee_id' => $employeeId,
                    'bssid' => $bssid,
                    'inside_geofence' => $inside,
                ]);
            }
        }

        $this->asAdmin()->postJson('/app/branches/approve_networks.php', [
            'branch_id' => $this->branchId,
            'approve' => [['kind' => 'bssid', 'value' => 'aa:bb:cc:dd:ee:10']],
        ])->assertOk();

        $this->asAdmin()->postJson('/app/branches/network_sightings.php', ['branch_id' => $this->branchId])
            ->assertOk()
            ->assertJsonPath('data.total_sightings', 10)
            ->assertJsonPath('data.coverage_percent', 80)
            // A network only ever seen from outside is almost always somebody's
            // home router, caught during the learning week.
            ->assertJsonPath('data.networks.0.all_inside', true)
            ->assertJsonPath('data.networks.1.all_outside', true);
    }
}
