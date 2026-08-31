<?php

declare(strict_types=1);

namespace App\Modules\Auth\Services;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Models\Employee;
use App\Shared\Access\Permissions;
use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/auth/login.php.
 *
 * Signs an administrator in with a Firebase ID token, creating the account on
 * first sight. The response is what the management app builds its whole session
 * from: the person, their company, their employee record if they have one, and
 * the permission set the client gates its navigation on.
 *
 * @phpstan-type LoginPayload array{
 *     success: bool,
 *     has_tenant: bool,
 *     user: array<string, mixed>,
 *     tenant: array<string, mixed>|null,
 *     employee: array<string, mixed>|null,
 *     pending_invitation: array<string, mixed>|null,
 * }
 */
final class AdminLoginAction
{
    public function __construct(private readonly FirebaseTokenVerifier $verifier) {}

    /**
     * @return array{payload: LoginPayload, admin: Admin, is_new: bool}
     *
     * @throws ApiFailure
     */
    public function execute(string $idToken, ?string $deviceId, string $ip, string $userAgent): array
    {
        $identity = $this->verifier->verify($idToken);

        $admin = $this->findExisting($identity);
        $isNew = $admin === null;

        $admin = $isNew
            ? $this->createAdmin($identity)
            : $this->reconcileExisting($admin, $identity, $ip);

        $this->claimDevice($admin, $deviceId);

        $tenant = $admin->tenant_id === null ? null : DB::table('tenants')
            ->select('id', 'name', 'currency', 'timezone')
            ->where('id', $admin->tenant_id)
            ->first();

        $employee = $admin->tenant_id === null ? null : Employee::query()
            ->forTenant($admin->tenant_id)
            ->where('admin_id', $admin->id)
            ->first();

        $pendingInvitation = $admin->tenant_id === null
            ? $this->pendingInvitationFor($admin->getAttribute('email'))
            : null;

        $this->recordLoginAttempt($admin, $ip, $userAgent);

        $permissions = Permissions::effectiveFor(
            $admin->id,
            $admin->tenant_id ?? 0,
            $admin->role,
        );

        return [
            'admin' => $admin,
            'is_new' => $isNew,
            'payload' => [
                'success' => true,
                'has_tenant' => $admin->tenant_id !== null,
                'user' => [
                    'id' => $admin->id,
                    'name' => $admin->name,
                    'phone' => $admin->phone,
                    'email' => $admin->getAttribute('email'),
                    'role' => $admin->role,
                    'role_key' => $admin->role,
                    'branch_id' => $admin->branch_id,
                    'branch_name' => null,
                    'job_title' => $employee?->getAttribute('job_title'),
                    'tenant_id' => $admin->tenant_id,
                    // A general manager holds everything; the client already
                    // recognises that from role_key, so an empty list here means
                    // "not permission-gated" rather than "no access".
                    'permissions' => $permissions === Permissions::ALL ? [] : array_values($permissions),
                ],
                'tenant' => $tenant === null ? null : [
                    'id' => Value::int($tenant->id),
                    'name' => $tenant->name,
                    'currency' => $tenant->currency,
                    'timezone' => $tenant->timezone,
                ],
                'employee' => $employee === null ? null : [
                    'id' => $employee->id,
                    'job_title' => $employee->getAttribute('job_title'),
                    'base_salary' => Value::float($employee->getAttribute('base_salary')),
                    'hire_date' => $employee->getAttribute('hire_date'),
                    'status' => $employee->status,
                ],
                'pending_invitation' => $pendingInvitation,
            ],
        ];
    }

    /**
     * Matched on uid, or on email for an account created by invitation before
     * the person ever signed in — that row exists with no firebase_uid yet.
     */
    private function findExisting(VerifiedFirebaseUser $identity): ?Admin
    {
        return Admin::query()
            ->where(function ($query) use ($identity): void {
                $query->where('firebase_uid', $identity->uid);
                if ($identity->email !== null) {
                    $query->orWhere('email', $identity->email);
                }
            })
            ->first();
    }

    private function createAdmin(VerifiedFirebaseUser $identity): Admin
    {
        // 'pending' rather than a working role: a stranger signing in with
        // Google gets an account and nothing else until a company adds them.
        $id = Admin::query()->insertGetId([
            'firebase_uid' => $identity->uid,
            'name' => $identity->displayName(),
            'email' => $identity->email,
            'auth_provider' => 'google',
            'role' => 'pending',
            'is_active' => 1,
            'email_verified_at' => DB::raw('NOW()'),
            'last_login_at' => DB::raw('NOW()'),
        ]);

        return Admin::query()->findOrFail($id);
    }

    private function reconcileExisting(Admin $admin, VerifiedFirebaseUser $identity, string $ip): Admin
    {
        // Matched by email: an invited account signing in for the first time.
        // Bind the uid so every later request matches on it directly.
        if ((string) $admin->firebase_uid === '') {
            Admin::query()->whereKey($admin->id)->update(['firebase_uid' => $identity->uid]);
            $admin->firebase_uid = $identity->uid;
        }

        if (! $admin->is_active) {
            // Being removed from a company detaches the account rather than
            // suspending it, so the two cases need different messages: one is
            // "you were taken off this company", the other is "you are barred".
            throw $admin->tenant_id === null
                ? new ApiFailure('تمت إزالتك من الشركة من قِبل المسؤول', 403, 'account_removed')
                : new ApiFailure('تم إيقاف حسابك من قِبل المسؤول', 403, 'account_deactivated');
        }

        Admin::query()->whereKey($admin->id)->update([
            'last_login_at' => DB::raw('NOW()'),
            'last_login_ip' => $ip,
        ]);

        return $admin;
    }

    /**
     * One active session per administrator: whoever just signed in becomes the
     * only active device, and any other handset is signed out on its next
     * request.
     */
    private function claimDevice(Admin $admin, ?string $deviceId): void
    {
        if ($deviceId === null || $deviceId === '') {
            return;
        }

        $deviceId = mb_substr($deviceId, 0, 100);
        Admin::query()->whereKey($admin->id)->update(['active_device_id' => $deviceId]);
        $admin->active_device_id = $deviceId;
    }

    /**
     * No company yet: if someone invited this address, surface it so onboarding
     * can offer a one-tap "join {company}" instead of asking for a code.
     *
     * @return array<string, mixed>|null
     */
    private function pendingInvitationFor(mixed $email): ?array
    {
        if (! is_string($email) || $email === '') {
            return null;
        }

        $invitation = DB::table('manager_invitations as mi')
            ->join('tenants as t', 't.id', '=', 'mi.tenant_id')
            ->leftJoin('branches as b', 'b.id', '=', 'mi.branch_id')
            ->where('mi.email', $email)
            ->whereNull('mi.cancelled_at')
            ->whereNull('mi.accepted_at')
            ->where('mi.expires_at', '>', DB::raw('NOW()'))
            ->where('t.is_active', 1)
            ->orderByDesc('mi.created_at')
            ->select('mi.id', 'mi.role', 'mi.expires_at', 't.name as company_name', 'b.name as branch_name')
            ->first();

        if ($invitation === null) {
            return null;
        }

        return [
            'invitation_id' => Value::int($invitation->id),
            'company_name' => $invitation->company_name,
            'role' => $invitation->role,
            'role_key' => $invitation->role,
            'branch_name' => $invitation->branch_name,
            'expires_at' => $invitation->expires_at,
        ];
    }

    private function recordLoginAttempt(Admin $admin, string $ip, string $userAgent): void
    {
        DB::table('login_attempts')->insert([
            'identifier' => Value::string($admin->getAttribute('email')),
            'identifier_type' => 'email',
            'tenant_id' => $admin->tenant_id,
            'admin_id' => $admin->id,
            'success' => 1,
            'ip' => $ip,
            'user_agent' => mb_substr($userAgent, 0, 255),
        ]);
    }
}
