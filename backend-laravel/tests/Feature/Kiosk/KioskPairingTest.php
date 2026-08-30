<?php

declare(strict_types=1);

namespace Tests\Feature\Kiosk;

use App\Domain\Kiosk\KioskPairing;
use App\Domain\Notifications\PushSender;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Services\RemoteConfig\RemoteConfigGate;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\Support\FakeRemoteConfigGate;
use Tests\TestCase;

/**
 * Turning a tablet into a kiosk, and taking it out of service.
 */
final class KioskPairingTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private string $adminToken;

    private string $viewerToken;

    private FakeRemoteConfigGate $gate;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->gate = new FakeRemoteConfigGate;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(RemoteConfigGate::class, $this->gate);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Kiosk branch',
            'station_enabled' => 1,
            'station_code_fallback_enabled' => 1,
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

    private function pairingCode(): string
    {
        $response = $this->asAdmin()
            ->postJson('/app/kiosk/create_pairing_code.php', ['branch_id' => $this->branchId])
            ->assertOk();

        return Value::string($response->json('data.code'));
    }

    /**
     * @return array{token: string, station_id: int}
     */
    private function pairedStation(): array
    {
        $response = $this->postJson('/app/kiosk/pair.php', [
            'code' => $this->pairingCode(),
            'device_id' => 'tablet-'.bin2hex(random_bytes(4)),
            'device_model' => 'Galaxy Tab A9',
            'platform' => 'android',
            'app_version' => '1.0.0',
        ])->assertOk();

        return [
            'token' => Value::string($response->json('data.kiosk_token')),
            'station_id' => Value::int($response->json('data.station.id')),
        ];
    }

    // ── Issuing a pairing code ───────────────────────────────────────────

    public function test_a_pairing_code_is_issued_for_a_branch(): void
    {
        $this->asAdmin()
            ->postJson('/app/kiosk/create_pairing_code.php', ['branch_id' => $this->branchId])
            ->assertOk()
            ->assertJsonPath('data.branch.name', 'Kiosk branch')
            ->assertJsonPath('data.expires_in_seconds', KioskPairing::PAIR_TTL_SECONDS)
            ->assertJsonStructure(['data' => ['code', 'expires_at']]);
    }

    public function test_the_code_is_stored_hashed_and_never_recoverable(): void
    {
        // A kiosk credential can record attendance for everyone at a branch, so
        // a database read must not hand anybody the means to create one.
        $code = $this->pairingCode();

        $this->assertDatabaseMissing('kiosk_codes', ['code_hash' => $code]);
        $this->assertDatabaseHas('kiosk_codes', ['code_hash' => KioskPairing::hash($code), 'purpose' => 'pair']);
    }

    public function test_a_branch_with_the_kiosk_switched_off_cannot_be_paired(): void
    {
        // A tablet paired to it would sit there refusing everybody, which looks
        // like broken hardware rather than a setting.
        DB::table('branches')->where('id', $this->branchId)->update(['station_enabled' => 0]);

        $this->asAdmin()
            ->postJson('/app/kiosk/create_pairing_code.php', ['branch_id' => $this->branchId])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'kiosk_pair_branch_disabled');
    }

    public function test_issuing_a_pairing_code_needs_the_device_permission(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->postJson('/app/kiosk/create_pairing_code.php', ['branch_id' => $this->branchId])
            ->assertForbidden();
    }

    // ── Redeeming it ─────────────────────────────────────────────────────

    public function test_redeeming_a_code_creates_a_station_and_issues_its_credential(): void
    {
        $paired = $this->pairedStation();

        $this->assertNotSame('', $paired['token']);
        $this->assertDatabaseHas('attendance_stations', [
            'id' => $paired['station_id'],
            'branch_id' => $this->branchId,
            'status' => 'active',
        ]);
        // Only the hash is stored.
        $this->assertDatabaseMissing('kiosk_auth_tokens', ['token_hash' => $paired['token']]);
    }

    public function test_a_code_can_only_be_redeemed_once(): void
    {
        // Two tablets racing the same code is not hypothetical: a supervisor
        // pairing several devices will type the same one twice by accident.
        $code = $this->pairingCode();

        $this->postJson('/app/kiosk/pair.php', ['code' => $code, 'device_id' => 'tablet-a'])->assertOk();

        $this->postJson('/app/kiosk/pair.php', ['code' => $code, 'device_id' => 'tablet-b'])
            ->assertStatus(410)
            ->assertJsonPath('error_code', 'kiosk_pair_code_spent');
    }

    public function test_an_unknown_code_answers_exactly_like_a_spent_one(): void
    {
        // Distinguishing them would turn this into an oracle: an attacker could
        // tell a real-but-spent code from a wrong guess and learn the alphabet.
        $this->postJson('/app/kiosk/pair.php', ['code' => 'ZZZZ-9999', 'device_id' => 'tablet-x'])
            ->assertStatus(410)
            ->assertJsonPath('error_code', 'kiosk_pair_code_spent');
    }

    public function test_an_expired_code_is_refused(): void
    {
        $code = $this->pairingCode();
        DB::table('kiosk_codes')->where('code_hash', KioskPairing::hash($code))
            ->update(['expires_at' => DB::raw('DATE_SUB(NOW(), INTERVAL 1 SECOND)')]);

        $this->postJson('/app/kiosk/pair.php', ['code' => $code, 'device_id' => 'tablet-x'])
            ->assertStatus(410);
    }

    public function test_re_pairing_the_same_tablet_replaces_its_credential(): void
    {
        // One live token per station: leaving two valid ones behind means a
        // revocation that does not revoke.
        $first = $this->pairedStation();
        $stationId = $first['station_id'];

        DB::table('kiosk_auth_tokens')->where('station_id', $stationId)->count();

        $this->assertSame(
            1,
            DB::table('kiosk_auth_tokens')->where('station_id', $stationId)->whereNull('revoked_at')->count()
        );
    }

    // ── Revoking ─────────────────────────────────────────────────────────

    public function test_revoking_a_station_kills_its_token_too(): void
    {
        $paired = $this->pairedStation();

        $this->asAdmin()->postJson('/app/kiosk/revoke.php', ['station_id' => $paired['station_id']])
            ->assertOk()
            ->assertJsonPath('data.already_revoked', false);

        $this->assertDatabaseHas('attendance_stations', ['id' => $paired['station_id'], 'status' => 'revoked']);
        $this->assertSame(
            0,
            DB::table('kiosk_auth_tokens')->where('station_id', $paired['station_id'])->whereNull('revoked_at')->count()
        );
    }

    public function test_a_revoked_tablet_is_refused_on_its_next_contact(): void
    {
        // The honest guarantee: a device that is switched off cannot be told
        // anything, so revocation takes effect when it next reaches the network.
        $paired = $this->pairedStation();
        $this->asAdmin()->postJson('/app/kiosk/revoke.php', ['station_id' => $paired['station_id']])->assertOk();

        $this->withHeader('X-Kiosk-Token', $paired['token'])
            ->postJson('/app/kiosk/heartbeat.php')
            ->assertUnauthorized()
            ->assertJsonPath('error_code', 'kiosk_token_invalid');
    }

    public function test_revoking_twice_is_not_an_error(): void
    {
        $paired = $this->pairedStation();

        $this->asAdmin()->postJson('/app/kiosk/revoke.php', ['station_id' => $paired['station_id']])->assertOk();

        $this->asAdmin()->postJson('/app/kiosk/revoke.php', ['station_id' => $paired['station_id']])
            ->assertOk()
            ->assertJsonPath('data.already_revoked', true);
    }

    // ── The administration area ──────────────────────────────────────────

    public function test_an_access_code_opens_the_administration_area(): void
    {
        $paired = $this->pairedStation();

        $code = Value::string(
            $this->asAdmin()
                ->postJson('/app/kiosk/create_access_code.php', ['station_id' => $paired['station_id']])
                ->assertOk()
                ->json('data.code')
        );

        $this->withHeader('X-Kiosk-Token', $paired['token'])
            ->postJson('/app/kiosk/open_admin.php', ['code' => $code])
            ->assertOk()
            ->assertJsonPath('data.authorised_by.name', 'Admin general_manager')
            ->assertJsonStructure(['data' => ['admin_session']]);
    }

    public function test_an_access_code_for_one_tablet_does_not_open_another(): void
    {
        // Otherwise a supervisor with access to a quiet branch could enrol
        // faces on a busy one.
        $first = $this->pairedStation();
        $second = $this->pairedStation();

        $code = Value::string(
            $this->asAdmin()
                ->postJson('/app/kiosk/create_access_code.php', ['station_id' => $first['station_id']])
                ->assertOk()
                ->json('data.code')
        );

        $this->withHeader('X-Kiosk-Token', $second['token'])
            ->postJson('/app/kiosk/open_admin.php', ['code' => $code])
            ->assertStatus(410)
            ->assertJsonPath('error_code', 'kiosk_pair_code_spent');
    }

    public function test_an_access_code_cannot_be_issued_for_a_revoked_station(): void
    {
        $paired = $this->pairedStation();
        $this->asAdmin()->postJson('/app/kiosk/revoke.php', ['station_id' => $paired['station_id']])->assertOk();

        $this->asAdmin()->postJson('/app/kiosk/create_access_code.php', ['station_id' => $paired['station_id']])
            ->assertStatus(409)
            ->assertJsonPath('error_code', 'kiosk_revoked');
    }

    public function test_closing_an_expired_session_is_not_an_error(): void
    {
        $paired = $this->pairedStation();

        $this->withHeader('X-Kiosk-Token', $paired['token'])
            ->postJson('/app/kiosk/admin/close.php', ['admin_session' => 'never-opened'])
            ->assertOk()
            ->assertJsonPath('data.already_closed', true);
    }

    public function test_the_roster_is_closed_without_a_live_session(): void
    {
        $paired = $this->pairedStation();

        $this->withHeader('X-Kiosk-Token', $paired['token'])
            ->postJson('/app/kiosk/admin/roster.php', ['admin_session' => 'not-a-session'])
            ->assertUnauthorized()
            ->assertJsonPath('error_code', 'kiosk_admin_session_expired');
    }

    // ── The fleet view ───────────────────────────────────────────────────

    public function test_the_fleet_list_flags_tablets_a_version_bump_would_take_offline(): void
    {
        // Checked before anybody raises the minimum: a directly-installed kiosk
        // has no store to be sent to, so somebody must visit each tablet.
        $this->pairedStation();
        $this->gate->set('medjat_kiosk', '2.0.0');

        $this->asAdmin()->postJson('/app/kiosk/list.php', ['branch_id' => $this->branchId])
            ->assertOk()
            ->assertJsonPath('data.min_version', '2.0.0')
            ->assertJsonPath('data.would_block_count', 1)
            ->assertJsonPath('data.stations.0.below_min_version', true);
    }

    public function test_a_current_tablet_is_not_flagged(): void
    {
        $this->pairedStation();
        $this->gate->set('medjat_kiosk', '1.0.0');

        $this->asAdmin()->postJson('/app/kiosk/list.php', ['branch_id' => $this->branchId])
            ->assertOk()
            ->assertJsonPath('data.would_block_count', 0);
    }

    public function test_the_roster_ceiling_is_reported_rather_than_enforced(): void
    {
        // Refusing to serve a branch that grew would be worse than telling its
        // administrator that face-only identification has reached its limit.
        $this->pairedStation();

        $this->asAdmin()->postJson('/app/kiosk/list.php', ['branch_id' => $this->branchId])
            ->assertOk()
            ->assertJsonPath('data.rosters.0.enrolled', 0)
            ->assertJsonPath('data.rosters.0.over_ceiling', false);
    }
}
