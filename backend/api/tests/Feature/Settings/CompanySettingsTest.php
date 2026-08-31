<?php

declare(strict_types=1);

namespace Tests\Feature\Settings;

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
 * How a company configures attendance, and the overrides beneath it.
 */
final class CompanySettingsTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private int $adminId;

    private FakeFirebaseTokenVerifier $firebase;

    private string $adminToken;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        DB::table('tenants')->where('id', $this->tenantId)->update([
            'attendance_methods' => json_encode(['qr_gps']),
            'manual_attendance_admin_ids' => null,
            'web_attendance_enabled' => 0,
            'web_attendance_photo_required' => 1,
            'timezone_is_explicit' => 0,
        ]);

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Settings branch',
            'is_active' => 1,
            'latitude' => 0,
            'longitude' => 0,
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
     * @param  array<string, mixed>  $payload
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function save(array $payload, ?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)
            ->postJson('/v1/settings/company', $payload);
    }

    /**
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function read(?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)
            ->getJson('/v1/settings/company');
    }

    public function test_the_screen_returns_the_whole_resolution_chain(): void
    {
        $this->read()
            ->assertOk()
            ->assertJsonStructure(['data' => [
                'attendance_methods', 'branches', 'categories', 'employee_overrides',
                'web_channel_limitations', 'branches_without_ip_networks',
            ]]);
    }

    public function test_the_browser_channel_limitations_are_served_from_here(): void
    {
        // Codes, not sentences, so each client localises them — and served from
        // one place so the disclosure cannot drift between clients.
        $this->read()
            ->assertOk()
            ->assertJsonPath('data.web_channel_limitations', ['wifi_bssid', 'mock_location', 'face_match']);
    }

    public function test_the_screen_warns_when_the_browser_channel_would_be_useless(): void
    {
        // A browser punch always resolves as gps_only; without it every
        // employee on the company default is refused the instant they press
        // the button, and the cause is two screens away.
        $this->read()->assertOk()->assertJsonPath('data.web_requires_gps_only', true);

        $this->save(['attendance_methods' => ['qr_gps', 'gps_only']])->assertOk();

        $this->read()->assertOk()->assertJsonPath('data.web_requires_gps_only', false);
    }

    public function test_a_branch_with_no_geofence_reports_null_rather_than_the_atlantic(): void
    {
        // The columns are NOT NULL, so 0,0 is how "unset" is stored — and it is
        // a real place in the ocean, not a branch.
        $response = $this->read()->assertOk();

        /** @var list<array<string, mixed>> $branches */
        $branches = (array) $response->json('data.branches');
        $branch = null;

        foreach ($branches as $candidate) {
            if (Value::int($candidate['id'] ?? null) === $this->branchId) {
                $branch = $candidate;
            }
        }

        $this->assertNotNull($branch);
        $this->assertNull($branch['lat']);
        $this->assertNull($branch['lng']);
    }

    public function test_a_branch_that_inherits_reports_null_methods_not_an_empty_list(): void
    {
        // An empty list would mean the override exists and permits nothing,
        // which would lock everybody at that branch out.
        $response = $this->read()->assertOk();

        /** @var list<array<string, mixed>> $branches */
        $branches = (array) $response->json('data.branches');

        foreach ($branches as $branch) {
            if (Value::int($branch['id'] ?? null) === $this->branchId) {
                $this->assertNull($branch['attendance_methods']);
            }
        }
    }

    public function test_the_methods_can_be_changed(): void
    {
        $this->save(['attendance_methods' => ['gps_only', 'face_selfie']])->assertOk();

        $this->read()->assertOk()->assertJsonPath('data.attendance_methods', ['gps_only', 'face_selfie']);
    }

    public function test_an_unknown_method_is_refused(): void
    {
        $this->save(['attendance_methods' => ['telepathy']])->assertStatus(422);

        $this->read()->assertJsonPath('data.attendance_methods', ['qr_gps']);
    }

    public function test_an_empty_method_list_is_refused(): void
    {
        // A company with no method has no way for anybody to record attendance.
        $this->save(['attendance_methods' => []])->assertStatus(422);
    }

    public function test_the_manual_admin_list_can_be_cleared_without_touching_the_methods(): void
    {
        $this->save([
            'attendance_methods' => ['qr_gps', 'manual'],
            'manual_attendance_admin_ids' => [$this->adminId],
        ])->assertOk();

        // Null is a real value — "no restriction" — and the original could not
        // see it, so clearing the list meant resending the whole method list.
        // That coupling is what let an unrelated save rewrite the methods.
        $this->save(['manual_attendance_admin_ids' => null])->assertOk();

        $this->read()
            ->assertOk()
            ->assertJsonPath('data.manual_attendance_admin_ids', null)
            ->assertJsonPath('data.attendance_methods', ['qr_gps', 'manual']);
    }

    public function test_an_admin_from_another_company_cannot_be_named(): void
    {
        $otherTenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Other company', 'timezone' => 'Africa/Cairo', 'is_active' => 1,
        ]);
        $stranger = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => 'uid-'.bin2hex(random_bytes(6)),
            'tenant_id' => $otherTenant,
            'name' => 'Stranger',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);

        $this->save([
            'attendance_methods' => ['qr_gps', 'manual'],
            'manual_attendance_admin_ids' => [$stranger],
        ])->assertStatus(422);
    }

    public function test_naming_manual_admins_while_the_method_is_off_is_refused(): void
    {
        $this->save(['manual_attendance_admin_ids' => [$this->adminId]])->assertStatus(422);
    }

    public function test_turning_manual_off_drops_its_restriction(): void
    {
        $this->save([
            'attendance_methods' => ['qr_gps', 'manual'],
            'manual_attendance_admin_ids' => [$this->adminId],
        ])->assertOk();

        // A restriction on a method nobody can use is noise.
        $this->save(['attendance_methods' => ['qr_gps']])->assertOk();

        $this->read()->assertJsonPath('data.manual_attendance_admin_ids', null);
    }

    public function test_saving_a_timezone_marks_it_deliberate(): void
    {
        $this->save(['timezone' => 'Asia/Riyadh'])->assertOk();

        $this->read()
            ->assertOk()
            ->assertJsonPath('data.timezone', 'Asia/Riyadh')
            ->assertJsonPath('data.timezone_is_explicit', true);
    }

    public function test_the_face_threshold_is_kept_inside_a_useful_band(): void
    {
        // Below 0.3 the match means nothing; above 0.95 nobody ever passes.
        $this->save(['face_match_threshold' => 0.2])->assertStatus(422);
        $this->save(['face_match_threshold' => 0.99])->assertStatus(422);
        $this->save(['face_match_threshold' => 0.5])->assertOk();

        $this->read()->assertJsonPath('data.face_match_threshold', 0.5);
    }

    public function test_an_unknown_enforce_mode_is_refused(): void
    {
        $this->save(['face_enforce_mode' => 'maybe'])->assertStatus(422);
    }

    public function test_the_face_settings_move_together_without_clobbering_each_other(): void
    {
        $this->save([
            'face_match_threshold' => 0.6,
            'face_liveness_required' => false,
            'face_enforce_mode' => 'enforce',
        ])->assertOk();

        // Sending only one of the three keeps the other two.
        $this->save(['face_enforce_mode' => 'log_only'])->assertOk();

        $this->read()
            ->assertJsonPath('data.face_match_threshold', 0.6)
            ->assertJsonPath('data.face_liveness_required', false)
            ->assertJsonPath('data.face_enforce_mode', 'log_only');
    }

    public function test_the_geofence_moves_as_one_and_clears_as_one(): void
    {
        $this->save([
            'gps_latitude' => 30.0444,
            'gps_longitude' => 31.2357,
            'gps_radius_meters' => 150,
        ])->assertOk();

        $this->read()->assertJsonPath('data.gps_radius_meters', 150);

        $this->save(['gps_latitude' => null, 'gps_longitude' => null])->assertOk();

        $this->read()
            ->assertJsonPath('data.gps_latitude', null)
            ->assertJsonPath('data.gps_radius_meters', null);
    }

    public function test_an_absurd_geofence_radius_is_refused(): void
    {
        $this->save([
            'gps_latitude' => 30.0, 'gps_longitude' => 31.0, 'gps_radius_meters' => 50000,
        ])->assertStatus(422);
    }

    public function test_opening_the_browser_channel_is_audited_on_its_own(): void
    {
        $this->save(['web_attendance_enabled' => true])->assertOk();

        // "Who turned it on, and when" is the first question anyone asks about
        // a disputed browser punch.
        $this->assertDatabaseHas('audit_log', [
            'tenant_id' => $this->tenantId,
            'admin_id' => $this->adminId,
            'action' => 'tenant.web_attendance_settings',
        ]);

        $this->read()->assertJsonPath('data.web_attendance_enabled', true);
    }

    public function test_the_photo_requirement_defaults_on(): void
    {
        // Enabling the weakest channel keeps the one control that says anything
        // about who pressed the button.
        $this->read()->assertJsonPath('data.web_attendance_photo_required', true);
    }

    public function test_a_non_boolean_toggle_is_refused(): void
    {
        $this->save(['reject_mock_location' => 'sometimes'])->assertStatus(422);
    }

    public function test_the_cycle_and_week_start_are_bounded(): void
    {
        $this->save(['cycle_start_day' => 0])->assertStatus(422);
        $this->save(['cycle_start_day' => 29])->assertStatus(422);
        $this->save(['week_start_day' => 8])->assertStatus(422);
        $this->save(['cycle_start_day' => 26, 'week_start_day' => 1])->assertOk();

        $this->read()
            ->assertJsonPath('data.cycle_start_day', 26)
            ->assertJsonPath('data.week_start_day', 1);
    }

    public function test_anybody_signed_in_may_read_the_settings(): void
    {
        // Half the other screens render themselves against these; gating the
        // read would break screens their own permission already allows.
        [, $token] = $this->admin('viewer');

        $this->read($token)->assertOk();
    }

    public function test_only_a_settings_manager_may_change_them(): void
    {
        [, $token] = $this->admin('viewer');

        $this->save(['name' => 'Renamed by a viewer'], $token)->assertStatus(403);
    }
}
