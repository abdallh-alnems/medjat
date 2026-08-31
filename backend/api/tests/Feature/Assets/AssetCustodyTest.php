<?php

declare(strict_types=1);

namespace Tests\Feature\Assets;

use App\Models\EmployeeAuthToken;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Custody: what a company hands out, and the two-step exchange that ends it.
 */
final class AssetCustodyTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $employeeId;

    private string $employeeToken;

    private string $adminToken;

    private string $viewerToken;

    private FakePushSender $push;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->push = new FakePushSender;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, $this->push);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Custodian',
            'status' => 'active',
            'base_salary' => 3000,
        ]);

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-asset',
        ]);
        $this->employeeToken = $plain;

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

    private function asEmployee(): self
    {
        $this->withHeader('X-Employee-Token', $this->employeeToken);

        return $this;
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function assigned(array $overrides = []): int
    {
        $response = $this->asAdmin()->postJson('/v1/assets', $overrides + [
            'employee_id' => $this->employeeId,
            'type' => 'device',
            'name' => 'Laptop',
            'value' => 25000,
            'serial_no' => 'SN-1',
        ])->assertOk();

        return Value::int($response->json('data.id'));
    }

    // ── Handing something out ────────────────────────────────────────────

    public function test_an_item_is_assigned_and_the_employee_is_told(): void
    {
        $id = $this->assigned();

        $this->assertDatabaseHas('asset_custody', [
            'id' => $id,
            'employee_id' => $this->employeeId,
            'name' => 'Laptop',
            'status' => 'assigned',
        ]);
        $this->assertDatabaseHas('notifications', [
            'employee_id' => $this->employeeId,
            'title_ar' => 'تم تسليمك عهدة',
        ]);
    }

    public function test_an_unnamed_item_is_refused(): void
    {
        $this->asAdmin()->postJson('/v1/assets', [
            'employee_id' => $this->employeeId,
            'name' => '   ',
        ])->assertStatus(422)->assertJsonPath('error_code', 'name_required');
    }

    public function test_an_unknown_type_is_refused(): void
    {
        $this->asAdmin()->postJson('/v1/assets', [
            'employee_id' => $this->employeeId,
            'name' => 'Thing',
            'type' => 'spaceship',
        ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_type');
    }

    public function test_a_quantity_below_one_becomes_one(): void
    {
        // Custody is at least one of something.
        $id = $this->assigned(['quantity' => 0]);

        $this->assertDatabaseHas('asset_custody', ['id' => $id, 'quantity' => 1]);
    }

    public function test_assigning_to_an_unknown_employee_is_refused(): void
    {
        $this->asAdmin()->postJson('/v1/assets', [
            'employee_id' => 9999999,
            'name' => 'Laptop',
        ])->assertNotFound();
    }

    // ── Editing ──────────────────────────────────────────────────────────

    public function test_an_edit_that_says_nothing_about_worth_does_not_erase_it(): void
    {
        $id = $this->assigned();

        $this->asAdmin()->postJson('/v1/assets/update', [
            'id' => $id,
            'name' => 'Laptop (renamed)',
        ])->assertOk();

        $this->assertDatabaseHas('asset_custody', [
            'id' => $id,
            'name' => 'Laptop (renamed)',
            'value' => '25000.00',
        ]);
    }

    public function test_an_empty_value_clears_it(): void
    {
        $id = $this->assigned();

        $this->asAdmin()->postJson('/v1/assets/update', ['id' => $id, 'value' => ''])->assertOk();

        $this->assertNull(DB::table('asset_custody')->where('id', $id)->value('value'));
    }

    public function test_a_returned_item_is_a_historical_record(): void
    {
        // Editing it would rewrite what was handed back, after the fact.
        $id = $this->assigned();
        $this->asAdmin()->postJson('/v1/assets/approve-return', ['id' => $id])->assertOk();

        $this->asAdmin()->postJson('/v1/assets/update', ['id' => $id, 'name' => 'Changed'])
            ->assertStatus(409)->assertJsonPath('error_code', 'asset_returned_locked');
    }

    public function test_an_item_can_be_deleted(): void
    {
        $id = $this->assigned();

        $this->asAdmin()->postJson('/v1/assets/delete', ['id' => $id])->assertOk();

        $this->assertDatabaseMissing('asset_custody', ['id' => $id]);
    }

    // ── Handing it back ──────────────────────────────────────────────────

    public function test_an_employee_says_they_are_handing_it_back(): void
    {
        $id = $this->assigned();

        $this->asEmployee()->postJson('/v1/assets/request-return', [
            'id' => $id,
            'return_note' => 'Left it at reception',
        ])->assertOk();

        $this->assertDatabaseHas('asset_custody', [
            'id' => $id,
            'status' => 'return_requested',
            'return_note' => 'Left it at reception',
        ]);
        // It is not returned until somebody with the item confirms it.
        $this->assertNotEmpty($this->push->sentToAdmins);
    }

    public function test_a_request_alone_does_not_clear_the_custody(): void
    {
        // A one-sided return would let anybody clear their own list without the
        // laptop ever reaching a desk.
        $id = $this->assigned();
        $this->asEmployee()->postJson('/v1/assets/request-return', ['id' => $id])->assertOk();

        $this->assertDatabaseMissing('asset_custody', ['id' => $id, 'status' => 'returned']);
    }

    public function test_a_manager_confirms_the_return(): void
    {
        $id = $this->assigned();
        $this->asEmployee()->postJson('/v1/assets/request-return', ['id' => $id])->assertOk();

        $this->asAdmin()->postJson('/v1/assets/approve-return', ['id' => $id])->assertOk();

        $this->assertDatabaseHas('asset_custody', ['id' => $id, 'status' => 'returned']);
        $this->assertDatabaseHas('notifications', [
            'employee_id' => $this->employeeId,
            'title_ar' => 'تم تأكيد إرجاع العهدة',
        ]);
    }

    public function test_a_return_can_be_confirmed_without_a_request_first(): void
    {
        // An administrator being handed a laptop in person is common enough
        // that requiring a request would just mean nobody records it.
        $id = $this->assigned();

        $this->asAdmin()->postJson('/v1/assets/approve-return', ['id' => $id])->assertOk();

        $this->assertDatabaseHas('asset_custody', ['id' => $id, 'status' => 'returned']);
    }

    public function test_confirming_twice_is_refused(): void
    {
        $id = $this->assigned();
        $this->asAdmin()->postJson('/v1/assets/approve-return', ['id' => $id])->assertOk();

        $this->asAdmin()->postJson('/v1/assets/approve-return', ['id' => $id])
            ->assertStatus(409)->assertJsonPath('error_code', 'custody_item_already_returned');
    }

    public function test_a_refused_return_goes_back_to_assigned_with_a_reason(): void
    {
        $id = $this->assigned();
        $this->asEmployee()->postJson('/v1/assets/request-return', ['id' => $id])->assertOk();

        $this->asAdmin()->postJson('/v1/assets/reject-return', [
            'id' => $id,
            'rejection_reason' => 'The charger is missing',
        ])->assertOk();

        $this->assertDatabaseHas('asset_custody', [
            'id' => $id,
            'status' => 'assigned',
            'rejection_reason' => 'The charger is missing',
            'return_requested_at' => null,
        ]);
    }

    public function test_only_a_pending_request_can_be_refused(): void
    {
        $id = $this->assigned();

        $this->asAdmin()->postJson('/v1/assets/reject-return', ['id' => $id])
            ->assertStatus(409)->assertJsonPath('error_code', 'only_pending_return_request_can');
    }

    public function test_a_fresh_request_clears_the_last_refusal(): void
    {
        // It is a new attempt, not a continuation of the one turned down.
        $id = $this->assigned();
        $this->asEmployee()->postJson('/v1/assets/request-return', ['id' => $id])->assertOk();
        $this->asAdmin()->postJson('/v1/assets/reject-return', [
            'id' => $id,
            'rejection_reason' => 'Charger missing',
        ])->assertOk();

        $this->asEmployee()->postJson('/v1/assets/request-return', ['id' => $id])->assertOk();

        $this->assertDatabaseHas('asset_custody', [
            'id' => $id,
            'status' => 'return_requested',
            'rejection_reason' => null,
        ]);
    }

    public function test_an_employee_cannot_return_somebody_elses_custody(): void
    {
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Someone else',
            'status' => 'active',
            'base_salary' => 1000,
        ]);
        $id = $this->assigned(['employee_id' => $stranger]);

        $this->asEmployee()->postJson('/v1/assets/request-return', ['id' => $id])->assertNotFound();
    }

    // ── Reading ──────────────────────────────────────────────────────────

    public function test_an_employee_sees_only_their_own(): void
    {
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Someone else',
            'status' => 'active',
            'base_salary' => 1000,
        ]);
        $this->assigned();
        $this->assigned(['employee_id' => $stranger, 'name' => 'Not yours']);

        $items = $this->asEmployee()->getJson('/v1/assets/mine')->assertOk()->json('data.items');

        $this->assertIsArray($items);
        $this->assertCount(1, $items);
        $this->assertIsArray($items[0]);
        $this->assertSame('Laptop', $items[0]['name']);
    }

    public function test_the_list_can_be_narrowed_by_state(): void
    {
        $returned = $this->assigned(['name' => 'Old phone']);
        $this->assigned(['name' => 'Current laptop']);
        $this->asAdmin()->postJson('/v1/assets/approve-return', ['id' => $returned])->assertOk();

        $items = $this->asAdmin()->getJson('/v1/assets?status=assigned&employee_id='.$this->employeeId)
            ->assertOk()->json('data.items');

        $this->assertIsArray($items);
        $this->assertCount(1, $items);
        $this->assertIsArray($items[0]);
        $this->assertSame('Current laptop', $items[0]['name']);
    }

    public function test_custody_is_closed_without_the_assets_permission(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/v1/assets')->assertForbidden();
    }
}
