<?php

declare(strict_types=1);

namespace App\Http\Controllers\Team;

use App\Domain\Access\Permissions;
use App\Domain\Audit\AuditLog;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/managers/{list_admins,update_admin,set_admin_active,remove_admin}.php.
 *
 * Who is on a company's management team, and what may be done to them.
 *
 * Every write here is guarded the same way: you cannot act on somebody who
 * holds a permission you do not, you cannot act on yourself, and a general
 * manager can only be touched by somebody with full access. The rule exists
 * because the alternative is an HR manager quietly removing the person who
 * hired them.
 */
final class TeamController
{
    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $caller = self::admin($request);
        $callerPermissions = self::permissionsOf($caller->id, $tenantId, $caller->role);

        $admins = DB::table('admins as a')
            ->leftJoin('branches as b', 'b.id', '=', 'a.branch_id')
            ->where('a.tenant_id', $tenantId)
            // Employees live in this table too and must never appear here.
            ->whereIn('a.role', Permissions::MANAGEMENT_ROLES)
            ->orderByDesc('a.created_at')
            ->get([
                'a.id', 'a.name', 'a.email', 'a.phone', 'a.role', 'a.branch_id',
                'a.is_active', 'a.last_login_at', 'a.created_at', 'b.name as branch_name',
            ]);

        $items = [];

        foreach ($admins as $row) {
            /** @var array<string, mixed> $columns */
            $columns = (array) $row;

            // Told per row, so the apps can hide actions rather than offer them
            // and then refuse. The write endpoints enforce it regardless.
            $columns['can_manage'] = Permissions::outranks(
                $callerPermissions,
                self::permissionsOf(Value::int($columns['id'] ?? null), $tenantId, Value::string($columns['role'] ?? null)),
            );

            $items[] = $columns;
        }

        return ApiResponse::success(['items' => $items]);
    }

    /**
     * Change somebody's role or branch.
     *
     * A role change drops any custom permission set: that set was built against
     * the old role, and carrying it across would leave somebody holding
     * permissions their new role never granted.
     */
    public function update(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $caller = self::admin($request);
        $targetId = Value::int($request->input('admin_id'));

        $target = self::target($request, $caller, $tenantId, 'لا يمكنك تعديل دورك أو فرعك بنفسك', 'لا يمكنك تعديل مدير عام', 'لا يمكنك تعديل مدير يعلوك في الصلاحيات الإدارية');

        $newRole = $request->has('role') ? trim(Value::string($request->input('role'))) : null;
        $hasBranch = $request->has('branch_id');
        $newBranchId = $hasBranch ? (Value::int($request->input('branch_id')) ?: null) : null;

        if ($newRole === null && ! $hasBranch) {
            throw new ApiFailure('لا يوجد تغييرات', 422, 'no_changes');
        }

        $changes = [];
        $roleChanged = $newRole !== null && $newRole !== Value::string($target['role'] ?? null);

        if ($roleChanged) {
            if (! in_array($newRole, Permissions::MANAGEMENT_ROLES, true)) {
                throw new ApiFailure('الدور غير صالح', 422, 'invalid_role');
            }

            self::assertMayGrant(Permissions::defaultsFor((string) $newRole), $caller, $tenantId);
            $changes['role'] = $newRole;
        }

        if ($hasBranch) {
            if ($newBranchId !== null) {
                self::assertBranchExists($newBranchId, $tenantId);
            }

            $changes['branch_id'] = $newBranchId;
        }

        if ($changes !== []) {
            DB::table('admins')->where('id', $targetId)->where('tenant_id', $tenantId)->update($changes);
        }

        if ($roleChanged) {
            DB::table('custom_roles')->where('admin_id', $targetId)->where('tenant_id', $tenantId)->delete();
        }

        AuditLog::record($tenantId, $caller->id, 'admin.updated', 'admin', $targetId, [
            'role' => $roleChanged ? $newRole : null,
            'branch_id' => $hasBranch ? $newBranchId : null,
        ]);

        return ApiResponse::success(['message' => 'تم تحديث بيانات المدير']);
    }

    /** Reversible: keeps their role, their data, and their history. */
    public function setActive(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $caller = self::admin($request);
        $targetId = Value::int($request->input('admin_id'));

        $raw = $request->input('is_active');
        $isActive = filter_var($raw, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);

        if ($isActive === null) {
            throw new ApiFailure('is_active مطلوب', 422, 'is_active_required');
        }

        self::target($request, $caller, $tenantId, 'لا يمكنك تعطيل حسابك بنفسك', 'لا يمكنك تعطيل مدير عام', 'لا يمكنك تعطيل مدير يعلوك في الصلاحيات الإدارية');

        DB::table('admins')->where('id', $targetId)->where('tenant_id', $tenantId)
            ->update(['is_active' => $isActive ? 1 : 0]);

        AuditLog::record(
            $tenantId, $caller->id,
            $isActive ? 'admin.activated' : 'admin.deactivated',
            'admin', $targetId,
        );

        return ApiResponse::success([
            'message' => $isActive ? 'تم تفعيل المدير' : 'تم تعطيل المدير',
            'is_active' => $isActive,
        ]);
    }

    /**
     * Detaches somebody from the company without deleting their account.
     *
     * They keep the ability to sign in and land on onboarding, and their email
     * is freed to join another company. Deleting the row instead would orphan
     * every audit entry and approval that names them.
     */
    public function remove(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $caller = self::admin($request);
        $targetId = Value::int($request->input('admin_id'));

        $target = self::target($request, $caller, $tenantId, 'لا يمكنك إزالة نفسك من الفريق', 'لا يمكنك إزالة مدير عام', 'لا يمكنك إزالة مدير يعلوك في الصلاحيات الإدارية');

        // A company with no general manager has nobody who can appoint one.
        if (Value::string($target['role'] ?? null) === 'general_manager') {
            $remaining = DB::table('admins')
                ->where('tenant_id', $tenantId)->where('role', 'general_manager')->where('is_active', 1)
                ->count();

            if ($remaining <= 1) {
                throw new ApiFailure('لا يمكن إزالة آخر مدير عام للشركة', 409, 'cannot_remove_last_owner');
            }
        }

        DB::transaction(function () use ($targetId, $tenantId): void {
            DB::table('admins')->where('id', $targetId)->where('tenant_id', $tenantId)->update([
                'tenant_id' => null,
                'branch_id' => null,
                'role' => 'pending',
                'is_active' => 1,
                'active_device_id' => null,
            ]);

            DB::table('custom_roles')->where('admin_id', $targetId)->where('tenant_id', $tenantId)->delete();
        });

        AuditLog::record($tenantId, $caller->id, 'admin.removed', 'admin', $targetId);

        return ApiResponse::success(['message' => 'تمت إزالة المدير من الفريق']);
    }

    /**
     * The three guards every write here shares, in the order they must run.
     *
     * @return array<string, mixed>
     */
    private static function target(
        Request $request,
        Admin $caller,
        int $tenantId,
        string $selfMessage,
        string $generalManagerMessage,
        string $outrankMessage,
    ): array {
        $targetId = Value::int($request->input('admin_id'));

        if ($targetId <= 0) {
            throw new ApiFailure('admin_id مطلوب', 422, 'admin_id_required');
        }

        if ($targetId === $caller->id) {
            throw new ApiFailure($selfMessage, 403, 'forbidden');
        }

        $row = DB::table('admins')->where('id', $targetId)->where('tenant_id', $tenantId)->first(['id', 'name', 'email', 'role']);

        if ($row === null) {
            throw new ApiFailure('المدير غير موجود', 404, 'not_found');
        }

        /** @var array<string, mixed> $target */
        $target = (array) $row;

        $callerPermissions = self::permissionsOf($caller->id, $tenantId, $caller->role);
        $targetRole = Value::string($target['role'] ?? null);

        if ($targetRole === 'general_manager' && $callerPermissions !== Permissions::ALL) {
            throw new ApiFailure($generalManagerMessage, 403, 'forbidden');
        }

        if (! Permissions::outranks($callerPermissions, self::permissionsOf($targetId, $tenantId, $targetRole))) {
            throw new ApiFailure($outrankMessage, 403, 'forbidden');
        }

        return $target;
    }

    /**
     * Equal-or-lower: nobody hands out access they do not hold themselves.
     *
     * @param  list<string>|Permissions::ALL  $granted
     */
    public static function assertMayGrant(array|string $granted, Admin $caller, int $tenantId): void
    {
        $callerPermissions = self::permissionsOf($caller->id, $tenantId, $caller->role);

        if ($granted === Permissions::ALL) {
            if ($callerPermissions !== Permissions::ALL) {
                throw new ApiFailure('لا يمكنك منح صلاحيات أعلى من صلاحياتك', 403, 'forbidden');
            }

            return;
        }

        if (! Permissions::isWithin($granted, $callerPermissions)) {
            throw new ApiFailure('لا يمكنك منح صلاحيات لا تملكها', 403, 'forbidden');
        }
    }

    public static function assertBranchExists(int $branchId, int $tenantId): void
    {
        if (! DB::table('branches')->where('id', $branchId)->where('tenant_id', $tenantId)->exists()) {
            throw new ApiFailure('الفرع غير موجود', 404, 'branch_not_found');
        }
    }

    /**
     * @return list<string>|Permissions::ALL
     */
    private static function permissionsOf(int $adminId, int $tenantId, string $role): array|string
    {
        return Permissions::effectiveFor($adminId, $tenantId, $role);
    }

    public static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $admin;
    }
}
