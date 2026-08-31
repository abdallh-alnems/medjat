<?php

declare(strict_types=1);

namespace App\Modules\SuperAdmin\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Mail\AuthActionMail;
use App\Models\SuperAdmin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Auth\Domain\AuthActionLink;
use App\Modules\Auth\Services\FirebaseAccountManager;
use App\Modules\Auth\Services\FirebaseCustomTokenMinter;
use App\Modules\SuperAdmin\Domain\SuperAdminAudit;
use App\Modules\Team\Domain\ManagerInvitation;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * Ports of api/admin/admins/*.php.
 *
 * The four things the desk can do to a company's administrator: invite one,
 * reset their password, suspend them, and — the last resort — sign in as them.
 *
 * Every one of these is written to *both* audit logs, ours and the company's
 * own, so a client can always see what we did inside their account.
 */
final class AdminAccountController
{
    private const ROLES = ['general_manager', 'hr', 'branch_manager', 'attendance', 'viewer'];

    /** Firebase custom tokens live an hour and cannot be renewed here. */
    private const IMPERSONATION_MINUTES = 60;

    public function __construct(
        private readonly FirebaseCustomTokenMinter $minter,
        private readonly FirebaseAccountManager $accounts,
    ) {}

    /**
     * Inviting a manager into an existing company.
     *
     * The rescue path: a client whose only general manager left the business,
     * or who deleted their own account, has nobody left holding add_managers
     * and cannot invite anybody. Without this the account is permanently locked
     * and the only fix is hand-written SQL on the server.
     *
     * It mirrors the company's own invite — same table, same code, same window
     * — except for the equal-or-lower permission check, which measures against
     * the inviter's own permissions. A super admin has none in that sense and
     * is trusted by definition.
     */
    public function invite(Request $request): JsonResponse
    {
        $caller = self::admin($request);

        $tenantId = Value::int($request->input('tenant_id'));
        $tenant = $tenantId > 0 ? DB::table('tenants')->where('id', $tenantId)->first(['id', 'name']) : null;

        if ($tenant === null) {
            throw new ApiFailure('Tenant not found', 404, 'not_found');
        }

        $email = trim(Value::string($request->input('email')));

        if ($email === '' || filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
            throw new ApiFailure('البريد الإلكتروني غير صالح', 422, 'invalid_email');
        }

        $role = Value::string($request->input('role'), 'general_manager') ?: 'general_manager';

        if (! in_array($role, self::ROLES, true)) {
            throw new ApiFailure('الدور غير صالح', 422, 'invalid_role');
        }

        $existing = DB::table('admins')->where('email', $email)->first(['id', 'tenant_id']);
        $existingTenant = Value::nullableInt($existing->tenant_id ?? null);

        if ($existingTenant !== null && $existingTenant !== $tenantId) {
            throw new ApiFailure('هذا البريد ينتمي لشركة أخرى بالفعل', 409, 'email_belongs_elsewhere');
        }

        if ($existingTenant === $tenantId && $existing !== null) {
            throw new ApiFailure('هذا الشخص عضو في الشركة بالفعل', 409, 'already_a_member');
        }

        $pendingId = Value::nullableInt(
            DB::table('manager_invitations')
                ->where('tenant_id', $tenantId)->where('email', $email)
                ->whereNull('cancelled_at')->whereNull('accepted_at')
                ->whereRaw('expires_at > NOW()')
                ->value('id')
        );

        // Rather than refuse a duplicate, hand back a fresh code: a support call
        // is nearly always "the code never arrived" or "it expired".
        $invitation = $pendingId !== null
            ? ManagerInvitation::regenerate($pendingId, $tenantId)
            : ManagerInvitation::create($tenantId, null, [
                'email' => $email,
                'name' => trim(Value::string($request->input('name'))),
                'role' => $role,
                'branch_id' => null,
                'permissions' => null,
            ]);

        if ($invitation === null) {
            throw new ApiFailure('تعذّر إعادة إنشاء الدعوة', 500, 'invitation_failed');
        }

        SuperAdminAudit::record($caller->id, 'admin.invite', 'tenant', $tenantId, [
            'email' => $email,
            'role' => $role,
        ]);

        // And in the company's own trail, so an invitation we sent is never a
        // mystery to them.
        AuditLog::record($tenantId, null, 'support.manager.invite', 'invitation', $pendingId, [
            'email' => $email,
            'role' => $role,
        ]);

        ManagerInvitation::email($email, $invitation['code'], $role, Value::string($tenant->name));

        return ApiResponse::success([
            'tenant_id' => $tenantId,
            'email' => $email,
            'role' => $role,
            'code' => $invitation['code'],
            'expires_at' => $invitation['expires_at'],
            'expires_in_hours' => ManagerInvitation::VALIDITY_HOURS,
            'join_url' => ManagerInvitation::joinUrl($invitation['code']),
        ]);
    }

    /**
     * Sending a company administrator a password-reset email on their behalf.
     *
     * They authenticate through Firebase — there is no password hash of ours to
     * overwrite — so this asks Firebase for a reset link.
     *
     * Unlike the self-service endpoint, failures are reported honestly. There
     * the caller is anonymous and hiding whether an account exists is
     * enumeration protection; here the caller is an authenticated operator
     * looking at one named account, and "the email never arrived" is itself the
     * support call.
     */
    public function resetPassword(Request $request): JsonResponse
    {
        $caller = self::admin($request);
        $target = $this->target($request);

        $email = trim(Value::string($target['email'] ?? null));

        if ($email === '') {
            throw new ApiFailure(
                'هذا الحساب بلا بريد إلكتروني — لا يمكن إرسال رابط إعادة تعيين',
                422,
                'no_email',
            );
        }

        $provider = Value::string($target['auth_provider'] ?? null);

        if ($provider !== 'email') {
            // A Google or Apple account has no password with us to reset.
            throw new ApiFailure(
                'هذا الحساب يسجّل الدخول عبر '.$provider.' وليس بكلمة مرور',
                422,
                'not_a_password_account',
            );
        }

        try {
            $link = $this->accounts->passwordResetLink($email);
        } catch (Throwable $e) {
            Log::error('Admin-initiated password reset failed', ['email' => $email, 'exception' => $e]);

            throw new ApiFailure(
                'تعذّر إرسال رابط إعادة التعيين — راجع سجل الأخطاء',
                500,
                'reset_link_failed',
            );
        }

        if ($link === null) {
            throw new ApiFailure(
                'تعذّر إرسال رابط إعادة التعيين — راجع سجل الأخطاء',
                500,
                'reset_link_failed',
            );
        }

        $adminId = Value::int($target['id'] ?? null);
        $tenantId = Value::nullableInt($target['tenant_id'] ?? null);

        SuperAdminAudit::record($caller->id, 'admin.password_reset', 'admin', $adminId, [
            'tenant_id' => $tenantId,
            'email' => $email,
        ]);

        if ($tenantId !== null) {
            AuditLog::record($tenantId, null, 'support.admin.password_reset', 'admin', $adminId);
        }

        $branded = AuthActionLink::rebase($link);

        try {
            Mail::to($email)->send(new AuthActionMail(AuthActionMail::RESET, 'ar', '', $branded));
        } catch (Throwable $e) {
            Log::error('Admin-initiated reset email failed', ['email' => $email, 'exception' => $e]);

            // Reported honestly, unlike the self-service endpoint. There the
            // caller is anonymous and hiding failure is enumeration protection;
            // here an operator is looking at one named account, and "the email
            // never arrived" is the support call itself.
            throw new ApiFailure(
                'تعذّر إرسال رابط إعادة التعيين — راجع سجل الأخطاء',
                500,
                'reset_link_failed',
            );
        }

        return ApiResponse::success([
            'admin_id' => $adminId,
            'email' => $email,
            'sent' => true,
        ]);
    }

    /**
     * Suspending or restoring a company administrator.
     *
     * A suspension, not a removal: the account keeps its company and its role
     * and simply stops authenticating.
     */
    public function setActive(Request $request): JsonResponse
    {
        $caller = self::admin($request);
        $target = $this->target($request);

        if (! $request->has('is_active')) {
            throw new ApiFailure('is_active مطلوب', 422, 'is_active_required');
        }

        $active = $request->boolean('is_active');
        $adminId = Value::int($target['id'] ?? null);
        $tenantId = Value::nullableInt($target['tenant_id'] ?? null);

        DB::table('admins')->where('id', $adminId)->update(['is_active' => $active ? 1 : 0]);

        SuperAdminAudit::record(
            $caller->id, $active ? 'admin.activate' : 'admin.deactivate', 'admin', $adminId,
            ['tenant_id' => $tenantId, 'email' => $target['email'] ?? null],
        );

        if ($tenantId !== null) {
            // Visible to the company too, so a suspension we applied is never a
            // mystery in their own trail.
            AuditLog::record(
                $tenantId, null,
                $active ? 'support.admin.activate' : 'support.admin.deactivate',
                'admin', $adminId,
            );
        }

        return ApiResponse::success(['admin_id' => $adminId, 'is_active' => $active ? 1 : 0]);
    }

    /**
     * Opening a client's own dashboard, as them, to see what they are seeing.
     *
     * The last resort of a support desk: the client says the payroll tab is
     * empty, their data looks fine from here, and the difference is something
     * only their session can show — their role, their permissions, their branch
     * scope.
     *
     * Company administrators authenticate with Firebase, so this asks Firebase
     * for a custom token bound to that person's uid and hands it to the web app
     * to exchange for a real session. No password is involved or revealed, and
     * nothing about our own authentication is bypassed.
     *
     * The guard rails, because it is the most powerful thing the panel can do:
     * superadmin only; the reason is required and stored; it is written to both
     * audit logs so the client can always see that we entered their account and
     * why; and the token expires in an hour and cannot be renewed here.
     */
    public function impersonate(Request $request): JsonResponse
    {
        $caller = self::admin($request);

        $reason = trim(Value::string($request->input('reason')));

        if ($reason === '') {
            throw new ApiFailure(
                'سبب الدخول التشخيصي مطلوب (يُسجَّل للشركة)',
                422,
                'reason_required',
            );
        }

        $target = $this->impersonationTarget($request);

        $uid = Value::string($target['firebase_uid'] ?? null);

        if ($uid === '') {
            throw new ApiFailure(
                'هذا الحساب لم يسجّل الدخول من قبل — لا يوجد حساب Firebase لانتحاله',
                422,
                'never_signed_in',
            );
        }

        if (Value::int($target['is_active'] ?? null) !== 1) {
            throw new ApiFailure(
                'الحساب موقوف — فعّله أولًا إن أردت الدخول به',
                422,
                'account_suspended',
            );
        }

        $adminId = Value::int($target['id'] ?? null);
        $tenantId = Value::nullableInt($target['tenant_id'] ?? null);

        try {
            $token = $this->minter->mint($uid, [
                // Rides along inside the ID token, so anything that later wants
                // to refuse an impersonated session can see that it is one.
                'impersonated' => true,
                'impersonated_by' => $caller->id,
            ]);
        } catch (Throwable $e) {
            Log::error('Impersonation token failed', ['admin_id' => $adminId, 'exception' => $e]);

            throw new ApiFailure('تعذّر إنشاء رمز الدخول التشخيصي', 500, 'token_failed');
        }

        SuperAdminAudit::record($caller->id, 'admin.impersonate', 'admin', $adminId, [
            'tenant_id' => $tenantId,
            'email' => $target['email'] ?? null,
            'reason' => $reason,
        ]);

        if ($tenantId !== null) {
            AuditLog::record($tenantId, $adminId, 'support.impersonate', 'admin', $adminId, [
                'reason' => $reason,
            ]);
        }

        $webBase = rtrim(Config::string('medjat.web.base_url'), '/');

        return ApiResponse::success([
            'admin' => [
                'id' => $adminId,
                'name' => $target['name'] ?? null,
                'email' => $target['email'] ?? null,
                'role' => $target['role'] ?? null,
                'tenant_id' => $tenantId,
            ],
            'token' => $token,
            'url' => $webBase.'/impersonate?token='.rawurlencode($token),
            'expires_in_minutes' => self::IMPERSONATION_MINUTES,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function target(Request $request): array
    {
        $adminId = Value::int($request->input('admin_id'));

        if ($adminId <= 0) {
            throw new ApiFailure('معرّف المدير مطلوب', 422, 'admin_id_required');
        }

        $row = DB::table('admins')->where('id', $adminId)->first();

        if ($row === null) {
            throw new ApiFailure('Admin not found', 404, 'not_found');
        }

        /** @var array<string, mixed> $admin */
        $admin = (array) $row;

        return $admin;
    }

    /**
     * The person to sign in as: the one named, or the company's general manager
     * when only a company was given.
     *
     * @return array<string, mixed>
     */
    private function impersonationTarget(Request $request): array
    {
        $adminId = Value::int($request->input('admin_id'));

        if ($adminId > 0) {
            return $this->target($request);
        }

        $tenantId = Value::int($request->input('tenant_id'));

        if ($tenantId <= 0) {
            throw new ApiFailure('حدّد المدير أو الشركة', 422, 'admin_or_tenant_required');
        }

        $row = DB::table('admins')
            ->where('tenant_id', $tenantId)
            ->where('role', 'general_manager')
            ->whereNotNull('firebase_uid')
            // Preferring somebody who has actually signed in before: an account
            // that never has cannot be impersonated at all.
            ->orderByDesc('is_active')
            ->orderByRaw('last_login_at IS NULL')
            ->orderByDesc('last_login_at')
            ->first();

        if ($row === null) {
            throw new ApiFailure('Admin not found', 404, 'not_found');
        }

        /** @var array<string, mixed> $admin */
        $admin = (array) $row;

        return $admin;
    }

    private static function admin(Request $request): SuperAdmin
    {
        $admin = $request->attributes->get('super_admin');

        if (! $admin instanceof SuperAdmin) {
            throw new ApiFailure('Admin token required', 401, 'admin_token_required');
        }

        return $admin;
    }
}
