<?php

declare(strict_types=1);

namespace App\Modules\Assets\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Assets\Domain\AssetCustody;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Notifications\Domain\Notifier;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/assets/{list,create,update,delete,approve_return,
 * reject_return}.php.
 *
 * Custody: what a company has handed out and expects back.
 */
final class AssetController
{
    public function __construct(private readonly Notifier $notifier) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        return ApiResponse::success([
            'items' => AssetCustody::forTenant(
                $tenantId,
                self::status($request->query('status')),
                Value::int($request->query('employee_id')) ?: null,
            ),
        ]);
    }

    public function create(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $employeeId = Value::int($request->input('employee_id'));

        $exists = DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)->exists();

        if (! $exists) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        $fields = $this->fields($request, $tenantId);
        $fields['assign_photo_url'] = Value::nullableString($request->input('assign_photo_url'));

        $id = AssetCustody::create($tenantId, $employeeId, $fields, $adminId);
        $name = Value::string($fields['name'] ?? null);

        AuditLog::record($tenantId, $adminId, 'asset.create', 'asset', $id, [
            'name' => $name,
            'type' => $fields['type'] ?? null,
        ]);

        $this->notifier->notifyEmployee(
            $tenantId, $employeeId, 'general',
            'Custody Assigned', 'تم تسليمك عهدة',
            "A new custody item has been assigned to you: {$name}.",
            "تم تسليمك عهدة جديدة: {$name}.",
            ['type' => 'asset', 'asset_id' => (string) $id, 'action' => 'assign'],
        );

        return ApiResponse::success(['id' => $id, 'message' => 'Custody assigned']);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $asset] = $this->target($id, $tenantId);

        // A returned item is a historical record: editing it would rewrite what
        // was handed back, after the fact.
        if (Value::string($asset['status'] ?? null) === 'returned') {
            throw new ApiFailure('A returned custody item cannot be edited', 409, 'asset_returned_locked');
        }

        AssetCustody::update($id, $tenantId, $this->fields($request, $tenantId, $asset));

        AuditLog::record($tenantId, $adminId, 'asset.update', 'asset', $id, [
            'name' => Value::string($request->input('name') ?? $asset['name'] ?? null),
        ]);

        return ApiResponse::success(['message' => 'Custody updated']);
    }

    public function delete(Request $request, int $id): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $asset] = $this->target($id, $tenantId);

        AssetCustody::delete($id, $tenantId);

        AuditLog::record($tenantId, $adminId, 'asset.delete', 'asset', $id, [
            'name' => Value::string($asset['name'] ?? null),
        ]);

        return ApiResponse::success(['message' => 'Custody deleted']);
    }

    /**
     * Somebody with the item in front of them confirming it came back.
     *
     * Accepted straight from "assigned" too, because an administrator being
     * handed a laptop in person is common enough that requiring the employee to
     * raise a request first would just mean nobody records it.
     */
    public function approveReturn(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $asset] = $this->target(Value::int($request->input('id')) ?: Value::int($request->query('id')), $tenantId);

        if (! in_array(Value::string($asset['status'] ?? null), ['assigned', 'return_requested'], true)) {
            throw new ApiFailure('This custody item is already returned', 409, 'custody_item_already_returned');
        }

        AssetCustody::approveReturn($id, $tenantId, $adminId);

        AuditLog::record($tenantId, $adminId, 'asset.return_approve', 'asset', $id);

        $name = Value::string($asset['name'] ?? null);

        $this->notifier->notifyEmployee(
            $tenantId, Value::int($asset['employee_id'] ?? null), 'approval',
            'Custody Return Confirmed', 'تم تأكيد إرجاع العهدة',
            "Your return of \"{$name}\" has been confirmed.",
            "تم تأكيد إرجاع العهدة: {$name}.",
            ['type' => 'asset', 'asset_id' => (string) $id, 'action' => 'return_approve'],
        );

        return ApiResponse::success(['message' => 'Custody return confirmed']);
    }

    public function rejectReturn(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $asset] = $this->target(Value::int($request->input('id')) ?: Value::int($request->query('id')), $tenantId);

        if (Value::string($asset['status'] ?? null) !== 'return_requested') {
            throw new ApiFailure(
                'Only a pending return request can be rejected',
                409,
                'only_pending_return_request_can',
            );
        }

        $reason = trim(Value::string($request->input('rejection_reason'))) ?: null;

        AssetCustody::rejectReturn($id, $tenantId, $adminId, $reason);

        AuditLog::record($tenantId, $adminId, 'asset.return_reject', 'asset', $id);

        $name = Value::string($asset['name'] ?? null);

        $this->notifier->notifyEmployee(
            $tenantId, Value::int($asset['employee_id'] ?? null), 'approval',
            'Custody Return Rejected', 'تم رفض إرجاع العهدة',
            "Your request to return \"{$name}\" was rejected.".($reason !== null ? " Reason: {$reason}" : ''),
            "تم رفض طلب إرجاع العهدة: {$name}.".($reason !== null ? " السبب: {$reason}" : ''),
            ['type' => 'asset', 'asset_id' => (string) $id, 'action' => 'return_reject'],
        );

        return ApiResponse::success(['message' => 'Custody return rejected']);
    }

    /**
     * The item's own fields, falling back to what is already recorded when this
     * is an edit rather than a new assignment.
     *
     * @param  array<string, mixed>  $existing
     * @return array<string, mixed>
     */
    private function fields(Request $request, int $tenantId, array $existing = []): array
    {
        $name = trim(Value::string($request->input('name') ?? $existing['name'] ?? null));

        if ($name === '') {
            throw new ApiFailure('name is required', 422, 'name_required');
        }

        $type = Value::string($request->input('type') ?? $existing['type'] ?? null, 'equipment');

        if (! in_array($type, AssetCustody::TYPES, true)) {
            throw new ApiFailure('Invalid type', 422, 'invalid_type');
        }

        $assignedAt = Value::string($request->input('assigned_at') ?? $existing['assigned_at'] ?? null)
            ?: TenantClock::date($tenantId);
        $assignedAt = substr($assignedAt, 0, 10);

        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $assignedAt) !== 1) {
            throw new ApiFailure('assigned_at must be YYYY-MM-DD', 422, 'invalid_date');
        }

        // An empty string clears the value; an absent field leaves whatever is
        // already recorded, so an edit that says nothing about worth does not
        // erase it.
        $value = $request->has('value')
            ? (Value::string($request->input('value')) === '' ? null : Value::float($request->input('value')))
            : Value::nullableFloat($existing['value'] ?? null);

        if ($value !== null && $value < 0) {
            throw new ApiFailure('value must be zero or positive', 422, 'invalid_value');
        }

        return [
            'type' => $type,
            'name' => $name,
            'description' => Value::nullableString($request->input('description') ?? $existing['description'] ?? null),
            'value' => $value,
            'currency' => Value::string($request->input('currency') ?? $existing['currency'] ?? null, 'SAR'),
            'serial_no' => Value::nullableString($request->input('serial_no') ?? $existing['serial_no'] ?? null),
            // A custody item is at least one of something.
            'quantity' => max(1, Value::int($request->input('quantity') ?? $existing['quantity'] ?? null, 1)),
            'assigned_at' => $assignedAt,
            'notes' => Value::nullableString($request->input('notes') ?? $existing['notes'] ?? null),
        ];
    }

    /**
     * @return array{0: int, 1: array<string, mixed>}
     */
    private function target(int $id, int $tenantId): array
    {
        $asset = $id > 0 ? AssetCustody::find($id, $tenantId) : null;

        if ($asset === null) {
            throw new ApiFailure('Custody not found', 404, 'not_found');
        }

        return [$id, $asset];
    }

    public static function status(mixed $raw): ?string
    {
        $status = Value::string($raw);

        return in_array($status, AssetCustody::STATUSES, true) ? $status : null;
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $admin;
    }
}
