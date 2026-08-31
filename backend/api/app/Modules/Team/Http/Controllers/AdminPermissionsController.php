<?php

declare(strict_types=1);

namespace App\Modules\Team\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Modules\Audit\Domain\AuditLog;
use App\Shared\Access\Permissions;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/managers/{get_admin_permissions,update_admin_permissions,
 * reset_admin_permissions}.php and api/app/roles/list_permissions.php.
 *
 * Tailoring what one administrator can do, beyond what their role grants.
 *
 * A general manager is deliberately untouchable here. Their access is the
 * definition of full access, so narrowing it would leave a company whose top
 * role means something different from every other company's.
 */
final class AdminPermissionsController
{
    public function show(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = Value::int($request->query('admin_id'));
        $role = self::roleOf($adminId, $tenantId);

        $defaults = Permissions::defaultsFor($role);
        $defaults = $defaults === Permissions::ALL ? Permissions::CATALOGUE : $defaults;

        $custom = self::customPermissions($adminId, $tenantId);

        return ApiResponse::success([
            'admin_id' => $adminId,
            'role' => $role,
            'role_defaults' => $defaults,
            'effective_permissions' => $custom ?? $defaults,
            'is_customized' => $custom !== null,
            'all_permissions' => Permissions::CATALOGUE,
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $caller = TeamController::admin($request);
        $adminId = Value::int($request->input('admin_id'));
        $role = self::roleOf($adminId, $tenantId);

        if ($role === 'general_manager') {
            throw new ApiFailure(__('messages.gm_permissions_immutable'), 403, 'forbidden');
        }

        $permissions = self::submitted($request);

        TeamController::assertMayGrant($permissions, $caller, $tenantId);

        DB::table('custom_roles')->upsert(
            [[
                'tenant_id' => $tenantId,
                'admin_id' => $adminId,
                'name' => 'custom',
                'permissions' => json_encode($permissions),
            ]],
            ['tenant_id', 'admin_id'],
            ['permissions', 'updated_at'],
        );

        AuditLog::record($tenantId, $caller->id, 'admin.permissions_updated', 'admin', $adminId, [
            'permissions' => $permissions,
        ]);

        return ApiResponse::success(['message' => 'Permissions updated']);
    }

    /** Drops the custom set, so the role's defaults apply again. */
    public function reset(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $caller = TeamController::admin($request);
        $adminId = Value::int($request->input('admin_id'));

        if (self::roleOf($adminId, $tenantId) === 'general_manager') {
            throw new ApiFailure(__('messages.gm_permissions_immutable'), 403, 'forbidden');
        }

        DB::table('custom_roles')->where('tenant_id', $tenantId)->where('admin_id', $adminId)->delete();

        AuditLog::record($tenantId, $caller->id, 'admin.permissions_reset', 'admin', $adminId);

        return ApiResponse::success(['message' => 'Permissions reset to defaults']);
    }

    /** The catalogue, plus whoever has been given a tailored set. */
    public function catalogue(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $roles = DB::table('custom_roles as cr')
            ->join('admins as a', 'a.id', '=', 'cr.admin_id')
            ->where('cr.tenant_id', $tenantId)
            ->orderByDesc('cr.created_at')
            ->get(['cr.*', 'a.name as admin_name']);

        return ApiResponse::success([
            'custom_roles' => $roles->map(static function (object $row): array {
                /** @var array<string, mixed> $columns */
                $columns = (array) $row;

                return $columns;
            })->all(),
            'available_permissions' => Permissions::CATALOGUE,
        ]);
    }

    /**
     * @return list<string>
     */
    private static function submitted(Request $request): array
    {
        $raw = $request->input('permissions', []);

        if (! is_array($raw)) {
            throw new ApiFailure('permissions must be an array', 400, 'permissions_array');
        }

        $permissions = [];

        foreach ($raw as $permission) {
            $name = Value::string($permission);

            if (! in_array($name, Permissions::CATALOGUE, true)) {
                throw new ApiFailure("Unknown permission: {$name}", 400, 'unknown_permission');
            }

            $permissions[] = $name;
        }

        return array_values(array_unique($permissions));
    }

    /**
     * @return list<string>|null
     */
    private static function customPermissions(int $adminId, int $tenantId): ?array
    {
        $raw = DB::table('custom_roles')
            ->where('admin_id', $adminId)->where('tenant_id', $tenantId)
            ->value('permissions');

        if (! is_string($raw)) {
            return null;
        }

        $decoded = json_decode($raw, true);

        if (! is_array($decoded)) {
            return null;
        }

        return array_values(array_map(static fn (mixed $p): string => Value::string($p), $decoded));
    }

    private static function roleOf(int $adminId, int $tenantId): string
    {
        $role = DB::table('admins')->where('id', $adminId)->where('tenant_id', $tenantId)->value('role');

        if ($role === null) {
            throw new ApiFailure(__('messages.admin_not_found'), 404, 'not_found');
        }

        return Value::string($role);
    }
}
