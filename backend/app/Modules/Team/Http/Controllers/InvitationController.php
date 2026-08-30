<?php

declare(strict_types=1);

namespace App\Modules\Team\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Team\Domain\ManagerInvitation;
use App\Shared\Access\Permissions;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/managers/{invite,list_invitations,cancel_invitation,
 * resend_invitation}.php.
 *
 * Inviting somebody onto a company's team.
 *
 * An unregistered email is deliberately allowed: the invitation waits, and the
 * person is linked when they sign up with the same address. Only somebody who
 * already belongs to a company is refused, because an administrator cannot be
 * in two companies at once.
 */
final class InvitationController
{
    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $status = Value::string($request->query('status')) ?: null;

        return ApiResponse::success(['items' => ManagerInvitation::forTenant($tenantId, $status)]);
    }

    public function invite(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $caller = TeamController::admin($request);

        $email = trim(Value::string($request->input('email')));
        $name = trim(Value::string($request->input('name')));
        $role = Value::string($request->input('role'));

        if (! in_array($role, Permissions::MANAGEMENT_ROLES, true)) {
            throw new ApiFailure('الدور غير صالح', 422, 'invalid_role');
        }

        if ($email === '' || filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
            throw new ApiFailure('صيغة البريد الإلكتروني غير صحيحة', 422, 'invalid_email');
        }

        $permissions = $this->requestedPermissions($request);

        // Equal-or-lower, measured against what the invitee will actually
        // receive: their tailored set if one was chosen, otherwise everything
        // the role grants.
        TeamController::assertMayGrant(
            $role === 'general_manager' ? Permissions::ALL : ($permissions ?? Permissions::defaultsFor($role)),
            $caller,
            $tenantId,
        );

        $existingTenant = DB::table('admins')->where('email', $email)->value('tenant_id');

        if ($existingTenant !== null) {
            throw new ApiFailure('هذا المستخدم ينتمي لشركة بالفعل', 409, 'user_already_in_company');
        }

        $branchId = Value::int($request->input('branch_id')) ?: null;

        if ($branchId !== null) {
            TeamController::assertBranchExists($branchId, $tenantId);
        }

        if (ManagerInvitation::pendingFor($tenantId, $email)) {
            throw new ApiFailure('يوجد دعوة معلقة بالفعل لهذا البريد الإلكتروني', 409, 'invitation_already_pending');
        }

        $invitation = ManagerInvitation::create($tenantId, $caller->id, [
            'email' => $email,
            'name' => $name,
            'role' => $role,
            'branch_id' => $branchId,
            'permissions' => $permissions,
        ]);

        AuditLog::record($tenantId, $caller->id, 'manager.invite', 'invitation', $invitation['id']);

        ManagerInvitation::email($email, $invitation['code'], $role, self::companyName($tenantId));

        return ApiResponse::success([
            'invitation_id' => $invitation['id'],
            // Returned once, for in-person or QR sharing. It cannot be read
            // back out of the database afterwards.
            'invitation_code' => $invitation['code'],
            'expires_at' => $invitation['expires_at'],
            'expires_in_hours' => ManagerInvitation::VALIDITY_HOURS,
        ], 201);
    }

    public function cancel(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $caller = TeamController::admin($request);
        $invitationId = self::invitationId($request);

        $invitation = self::find($invitationId, $tenantId);

        if ($invitation['accepted_at'] !== null) {
            throw new ApiFailure('الدعوة مقبولة بالفعل', 409, 'invitation_already_accepted');
        }

        if ($invitation['cancelled_at'] !== null) {
            throw new ApiFailure('الدعوة ملغاة بالفعل', 409, 'invitation_already_cancelled');
        }

        ManagerInvitation::cancel($invitationId, $tenantId);

        AuditLog::record($tenantId, $caller->id, 'manager.cancel_invite', 'invitation', $invitationId);

        return ApiResponse::success(['message' => 'تم إلغاء الدعوة']);
    }

    /**
     * A fresh code and a fresh window on the same invitation.
     *
     * Works on a cancelled or expired one too — the row keeps its identity and
     * its trail rather than being deleted and made again.
     */
    public function resend(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $caller = TeamController::admin($request);
        $invitationId = self::invitationId($request);

        if (self::find($invitationId, $tenantId)['accepted_at'] !== null) {
            throw new ApiFailure('الدعوة مقبولة بالفعل', 409, 'invitation_already_accepted');
        }

        $result = ManagerInvitation::regenerate($invitationId, $tenantId);

        if ($result === null) {
            throw new ApiFailure('تعذّر إعادة إنشاء الدعوة', 500, 'resend_invitation_failed');
        }

        AuditLog::record($tenantId, $caller->id, 'manager.resend_invite', 'invitation', $invitationId);

        return ApiResponse::success([
            'invitation_id' => $invitationId,
            'invitation_code' => $result['code'],
            'expires_at' => $result['expires_at'],
            'expires_in_hours' => ManagerInvitation::VALIDITY_HOURS,
        ]);
    }

    /**
     * @return list<string>|null Null when the inviter did not tailor the set.
     */
    private function requestedPermissions(Request $request): ?array
    {
        $raw = $request->input('permissions');

        if ($raw === null) {
            return null;
        }

        if (! is_array($raw)) {
            throw new ApiFailure('permissions must be an array', 422, 'permissions_array');
        }

        $permissions = [];

        foreach ($raw as $permission) {
            $name = Value::string($permission);

            if (! in_array($name, Permissions::CATALOGUE, true)) {
                throw new ApiFailure("صلاحية غير معروفة: {$name}", 422, 'unknown_permission');
            }

            $permissions[] = $name;
        }

        return array_values(array_unique($permissions));
    }

    /**
     * @return array<string, mixed>
     */
    private static function find(int $invitationId, int $tenantId): array
    {
        $row = DB::table('manager_invitations')
            ->where('id', $invitationId)->where('tenant_id', $tenantId)
            ->first(['id', 'accepted_at', 'cancelled_at']);

        if ($row === null) {
            throw new ApiFailure('الدعوة غير موجودة', 404, 'not_found');
        }

        /** @var array<string, mixed> $invitation */
        $invitation = (array) $row;

        return $invitation;
    }

    private static function invitationId(Request $request): int
    {
        $id = Value::int($request->query('id')) ?: Value::int($request->input('id'));

        if ($id <= 0) {
            throw new ApiFailure('معرّف الدعوة مطلوب', 422, 'invitation_id_required');
        }

        return $id;
    }

    private static function companyName(int $tenantId): string
    {
        return Value::string(DB::table('tenants')->where('id', $tenantId)->value('name'));
    }
}
