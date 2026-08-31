<?php

declare(strict_types=1);

namespace Tests\Feature\Security;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The shared secret every published app build sends.
 */
final class AppSecretGateTest extends TestCase
{
    use DatabaseTransactions;

    private const USER = 'medjat-app';

    private const KEY = 'the-shared-secret';

    private const CRON_SECRET = 'cron-secret';

    protected function setUp(): void
    {
        parent::setUp();

        $this->app->instance(FirebaseTokenVerifier::class, new FakeFirebaseTokenVerifier);
        $this->app->instance(PushSender::class, new FakePushSender);

        Config::set('medjat.app_secret.user', self::USER);
        Config::set('medjat.app_secret.key', self::KEY);
        Config::set('medjat.cron.secret', self::CRON_SECRET);
    }

    public function test_a_request_without_the_secret_is_refused(): void
    {
        // The API must not be callable with curl by anybody who reads a URL out
        // of an app bundle.
        $this->getJson('/v1/settings/company')
            ->assertStatus(401)
            ->assertJsonPath('message', 'Unauthorized');
    }

    public function test_a_wrong_secret_is_refused(): void
    {
        $this->withBasicAuth(self::USER, 'not-the-key')
            ->getJson('/v1/settings/company')
            ->assertStatus(401);
    }

    public function test_the_right_secret_passes_the_gate_and_reaches_the_real_guard(): void
    {
        // 400 for a missing token, not 401 for a missing secret: the request
        // got past this gate and was refused by the one that authenticates.
        $this->withBasicAuth(self::USER, self::KEY)
            ->getJson('/v1/settings/company')
            ->assertStatus(400);
    }

    public function test_the_raw_authorization_header_is_read_when_the_server_does_not_split_it(): void
    {
        // PHP_AUTH_* needs CGIPassAuth or a rewrite to reach PHP, and one of
        // the two is missing often enough to be worth handling.
        $this->withHeader('Authorization', 'Basic '.base64_encode(self::USER.':'.self::KEY))
            ->getJson('/v1/settings/company')
            ->assertStatus(400);
    }

    public function test_an_unset_secret_disables_the_gate(): void
    {
        // How local development runs: the alternative makes a fresh checkout
        // answer 401 to everything with no clue why.
        Config::set('medjat.app_secret.user', '');
        Config::set('medjat.app_secret.key', '');

        $this->getJson('/v1/settings/company')->assertStatus(400);
    }

    public function test_the_scheduled_jobs_present_their_own_secret_instead(): void
    {
        // They are called by curl from the crontab, which has no app bundle to
        // take a secret from.
        $this->getJson('/v1/cron/run-alerts?key='.self::CRON_SECRET)->assertOk();
    }

    public function test_a_cron_url_without_either_secret_is_still_refused(): void
    {
        $this->getJson('/v1/cron/run-alerts')->assertStatus(401);
    }

    public function test_a_terminal_is_exempt_because_the_firmware_cannot_send_one(): void
    {
        $serial = 'ZKGATE'.bin2hex(random_bytes(3));

        // Its serial number is the whole authorisation model.
        $this->call('GET', '/iclock/cdata?SN='.$serial)
            ->assertOk()
            ->assertHeader('Content-Type', 'text/plain; charset=utf-8');

        $this->assertDatabaseHas('attendance_devices', [
            'serial_number' => strtoupper($serial), 'status' => 'unclaimed',
        ]);
    }

    public function test_the_terminal_is_reachable_on_its_path_routed_form_too(): void
    {
        $serial = 'ZKGATE'.bin2hex(random_bytes(3));

        $this->call('GET', '/iclock/cdata?SN='.$serial)->assertOk();
    }

    public function test_the_gate_sits_in_front_of_the_admin_panel_as_well(): void
    {
        $id = (int) DB::table('super_admins')->insertGetId([
            'username' => 'gate-'.bin2hex(random_bytes(4)),
            'password_hash' => password_hash('x', PASSWORD_BCRYPT, ['cost' => 4]),
            'display_name' => 'Gate operator',
            'role' => 'superadmin',
            'is_active' => 1,
        ]);

        $this->assertGreaterThan(0, $id);

        $this->getJson('/v1/admin/tenants')->assertStatus(401);
    }

    public function test_the_secret_is_compared_in_full(): void
    {
        // A prefix must not pass.
        $this->withBasicAuth(self::USER, Value::string(substr(self::KEY, 0, 5)))
            ->getJson('/v1/settings/company')
            ->assertStatus(401);
    }
}
