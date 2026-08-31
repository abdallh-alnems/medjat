<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Admin;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * Profile, notification preferences and the push token.
 */
final class AccountSettingsTest extends TestCase
{
    use DatabaseTransactions;

    private FakeFirebaseTokenVerifier $firebase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
    }

    private function tenantId(): int
    {
        return Value::int(DB::table('tenants')->where('is_active', 1)->orderBy('id')->value('id'));
    }

    /** @return array{Admin, string} */
    private function admin(): array
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        $id = Admin::query()->insertGetId([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId(),
            'name' => 'Test Admin',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);

        return [Admin::query()->findOrFail($id), $this->firebase->issue($uid)];
    }

    /** @return array{Employee, string} */
    private function employee(): array
    {
        $employee = Employee::query()
            ->where('status', '!=', 'terminated')
            ->whereNotNull('admin_id')
            ->firstOrFail();

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $employee->tenant_id,
            'employee_id' => $employee->id,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-a',
        ]);

        return [$employee, $plain];
    }

    // ── Profile ──────────────────────────────────────────────────────────

    public function test_a_name_and_phone_can_be_updated(): void
    {
        [$admin, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/auth/profile', ['name' => 'New Name', 'phone' => '+201234567890'])
            ->assertOk();

        $row = DB::table('admins')->where('id', $admin->id)->first();
        $this->assertNotNull($row);
        $this->assertSame('New Name', $row->name);
        $this->assertSame('+201234567890', $row->phone);
    }

    public function test_a_locally_written_number_is_refused_because_it_has_no_country_code(): void
    {
        // Storing an ambiguous national number makes every later phone-matched
        // lookup unreliable, and the write path is the last place it can still
        // be resolved by asking.
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/auth/profile', ['phone' => '01023809407'])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'invalid_phone_number');
    }

    public function test_arabic_digits_and_the_double_zero_prefix_are_accepted(): void
    {
        // Both are what the keyboards and the region actually produce.
        [$admin, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/auth/profile', ['phone' => '00٢٠١٢٣٤٥٦٧٨٩٠'])
            ->assertOk();

        $this->assertSame('+201234567890', DB::table('admins')->where('id', $admin->id)->value('phone'));
    }

    public function test_an_empty_phone_clears_it(): void
    {
        [$admin, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/auth/profile', ['phone' => ''])
            ->assertOk();

        $this->assertNull(DB::table('admins')->where('id', $admin->id)->value('phone'));
    }

    public function test_an_omitted_field_is_left_alone(): void
    {
        // The difference between "phone was omitted" and "phone was sent empty"
        // is the difference between leaving it and clearing it.
        [$admin, $token] = $this->admin();
        Admin::query()->whereKey($admin->id)->update(['phone' => '+201111111111']);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/auth/profile', ['name' => 'Only The Name'])
            ->assertOk();

        $this->assertSame('+201111111111', DB::table('admins')->where('id', $admin->id)->value('phone'));
    }

    public function test_an_empty_name_is_refused(): void
    {
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/auth/profile', ['name' => '   '])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'name_cannot_empty');
    }

    public function test_a_request_that_changes_nothing_is_refused(): void
    {
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/auth/profile', [])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'nothing_update');
    }

    public function test_the_change_is_recorded_in_the_audit_log(): void
    {
        [$admin, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/auth/profile', ['name' => 'Audited'])
            ->assertOk();

        $this->assertDatabaseHas('audit_log', [
            'admin_id' => $admin->id,
            'action' => 'profile.update',
            'target_type' => 'admin',
        ]);
    }

    // ── Notification preferences ─────────────────────────────────────────

    public function test_preferences_default_to_everything_on(): void
    {
        // Someone who has never opened the screen should still hear about a
        // missing check-out.
        [$employee, $token] = $this->employee();
        DB::table('admin_notification_prefs')->where('admin_id', $employee->admin_id)->delete();

        $this->withHeader('X-Employee-Token', $token)
            ->getJson('/v1/auth/notification-prefs')
            ->assertOk()
            ->assertJsonPath('data.prefs.late_absence', true)
            ->assertJsonPath('data.prefs.payroll_events', true);
    }

    public function test_preferences_round_trip(): void
    {
        [, $token] = $this->employee();

        $this->withHeader('X-Employee-Token', $token)
            ->postJson('/v1/auth/notification-prefs', ['prefs' => [
                'late_absence' => false,
                'missing_checkout' => true,
            ]])
            ->assertOk()
            ->assertJsonPath('data.prefs.late_absence', false)
            // Omitted keys default to on rather than becoming a partial set.
            ->assertJsonPath('data.prefs.document_expiry', true);

        $this->withHeader('X-Employee-Token', $token)
            ->getJson('/v1/auth/notification-prefs')
            ->assertOk()
            ->assertJsonPath('data.prefs.late_absence', false);
    }

    public function test_unknown_preference_keys_are_dropped(): void
    {
        [, $token] = $this->employee();

        $this->withHeader('X-Employee-Token', $token)
            ->postJson('/v1/auth/notification-prefs', ['prefs' => ['made_up_switch' => true]])
            ->assertOk()
            ->assertJsonMissingPath('data.prefs.made_up_switch');
    }

    public function test_a_non_object_prefs_payload_is_refused(): void
    {
        [, $token] = $this->employee();

        $this->withHeader('X-Employee-Token', $token)
            ->postJson('/v1/auth/notification-prefs', ['prefs' => 'nope'])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'prefs_object');
    }

    // ── Push token ───────────────────────────────────────────────────────

    public function test_an_employee_token_registers_the_push_token(): void
    {
        [$employee, $token] = $this->employee();

        $this->withHeader('X-Employee-Token', $token)
            ->postJson('/v1/auth/fcm-token', ['fcm_token' => 'fcm-abc', 'platform' => 'ios'])
            ->assertOk();

        $this->assertDatabaseHas('admin_devices', [
            'admin_id' => $employee->admin_id,
            'fcm_token' => 'fcm-abc',
            'platform' => 'ios',
            'is_active' => 1,
        ]);
    }

    public function test_a_firebase_token_registers_the_push_token(): void
    {
        [$admin, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/auth/fcm-token', ['fcm_token' => 'fcm-mgmt'])
            ->assertOk();

        $this->assertDatabaseHas('admin_devices', ['admin_id' => $admin->id, 'fcm_token' => 'fcm-mgmt']);
    }

    public function test_registering_a_new_token_deactivates_the_previous_one(): void
    {
        // A stale token left active means the same handset receives every push
        // more than once.
        [$admin, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/auth/fcm-token', ['fcm_token' => 'fcm-old'])->assertOk();
        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/auth/fcm-token', ['fcm_token' => 'fcm-new'])->assertOk();

        $this->assertDatabaseHas('admin_devices', ['admin_id' => $admin->id, 'fcm_token' => 'fcm-old', 'is_active' => 0]);
        $this->assertDatabaseHas('admin_devices', ['admin_id' => $admin->id, 'fcm_token' => 'fcm-new', 'is_active' => 1]);
    }

    public function test_a_missing_fcm_token_is_refused(): void
    {
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/auth/fcm-token', [])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'fcm_token_required');
    }
}
