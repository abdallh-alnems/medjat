<?php

declare(strict_types=1);

namespace App\Modules\Tenant\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Team\Domain\ManagerInvitation;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/tenant/{create,join,accept_invitation}.php.
 *
 * The three ways a signed-in person acquires a company: founding one, redeeming
 * an invitation code, or accepting an invitation that was addressed to their
 * email.
 *
 * All three run before there is a tenant to authenticate against, so they take
 * a Firebase token directly rather than going through the tenant middleware.
 * Each is guarded by the same rule: you cannot already belong somewhere. An
 * administrator belongs to exactly one company, and a second one would leave
 * every tenant-scoped query with two possible answers.
 */
final class OnboardingController
{
    public function __construct(private readonly FirebaseTokenVerifier $verifier) {}

    /**
     * Founding a company.
     *
     * The founder gets general_manager, the top role. Companies have no owner:
     * access is entirely roles and permissions, so the founder is a general
     * manager like any other and can be joined by more of them.
     */
    public function create(Request $request): JsonResponse
    {
        $admin = $this->unaffiliatedAdmin($request);

        $name = trim(Value::string($request->input('company_name')));

        if ($name === '') {
            throw new ApiFailure('Company name is required', 422, 'company_name_required');
        }

        // Only what was actually supplied is written, so an omitted setting
        // keeps its schema default rather than being overwritten with a guess.
        // Builds already in the stores send nothing but the name.
        $fields = ['name' => $name, 'is_active' => 1, 'email_verified_at' => DB::raw('NOW()')];

        if ($request->has('timezone')) {
            $timezone = trim(Value::string($request->input('timezone')));

            if (! in_array($timezone, timezone_identifiers_list(), true)) {
                throw new ApiFailure('Invalid timezone identifier', 422, 'invalid_timezone_identifier');
            }

            $fields['timezone'] = $timezone;
            // What later stops the settings screen re-suggesting a timezone
            // over a choice somebody made deliberately.
            $fields['timezone_is_explicit'] = 1;
        }

        if ($request->has('currency')) {
            $currency = strtoupper(trim(Value::string($request->input('currency'))));

            if (preg_match('/^[A-Z]{3}$/', $currency) !== 1) {
                throw new ApiFailure(
                    'currency must be a 3-letter ISO code (e.g. EGP)',
                    422,
                    'currency_3_letter_iso_code',
                );
            }

            $fields['currency'] = $currency;
        }

        if ($request->has('cycle_start_day')) {
            $fields['cycle_start_day'] = self::inRange(
                $request->input('cycle_start_day'), 1, 28,
                'cycle_start_day must be between 1 and 28', 'cycle_start_day_between_1',
            );
        }

        if ($request->has('week_start_day')) {
            $fields['week_start_day'] = self::inRange(
                $request->input('week_start_day'), 1, 7,
                'week_start_day must be between 1 (Mon) and 7 (Sun)', 'week_start_day_between_1',
            );
        }

        $tenantId = DB::transaction(function () use ($fields, $admin): int {
            $tenantId = (int) DB::table('tenants')->insertGetId($fields);

            DB::table('admins')->where('id', $admin->id)->update([
                'tenant_id' => $tenantId,
                'role' => 'general_manager',
            ]);

            return $tenantId;
        });

        AuditLog::record($tenantId, $admin->id, 'tenant.create', 'tenant', $tenantId);

        $tenant = DB::table('tenants')->where('id', $tenantId)->first([
            'id', 'name', 'currency', 'timezone', 'cycle_start_day', 'week_start_day',
        ]);

        return ApiResponse::success([
            'success' => true,
            'tenant' => [
                'id' => $tenantId,
                'name' => Value::string($tenant?->name),
                'currency' => $tenant?->currency,
                'timezone' => $tenant?->timezone,
                'cycle_start_day' => Value::int($tenant?->cycle_start_day),
                'week_start_day' => Value::int($tenant?->week_start_day),
            ],
            'user' => [
                'id' => $admin->id,
                'tenant_id' => $tenantId,
                'role' => 'general_manager',
                'role_key' => 'general_manager',
            ],
        ]);
    }

    /** Joining with an invitation code, typed in from an email or a message. */
    public function join(Request $request): JsonResponse
    {
        $admin = $this->unaffiliatedAdmin($request);

        $code = trim(Value::string($request->input('invite_code')));

        if ($code === '') {
            throw new ApiFailure('Invite code is required', 422, 'invite_code_required');
        }

        $invitation = ManagerInvitation::redeemable($code);

        if ($invitation === null) {
            throw new ApiFailure('Invite code is invalid', 404, 'invite_code_invalid');
        }

        if ($invitation['cancelled_at'] !== null) {
            throw new ApiFailure('This invitation was cancelled', 410, 'invitation_was_cancelled');
        }

        if ($invitation['accepted_at'] !== null) {
            throw new ApiFailure('This invitation was already used', 410, 'invitation_was_already_used');
        }

        if (Value::int($invitation['is_expired'] ?? null) === 1) {
            throw new ApiFailure('This invitation has expired', 410, 'invitation_expired');
        }

        $invitedEmail = Value::nullableString($invitation['email'] ?? null);
        $adminEmail = Value::nullableString($admin->getAttribute('email'));

        // Only checked when both sides have an email: some providers give none,
        // and refusing those would lock out people holding a valid code.
        if ($invitedEmail !== null && $adminEmail !== null
            && strcasecmp($invitedEmail, $adminEmail) !== 0) {
            throw new ApiFailure(
                'This invitation is for a different email address',
                403,
                'invitation_different_email_address',
            );
        }

        return $this->accept($invitation, $admin);
    }

    /**
     * Accepting an invitation addressed to the signed-in email.
     *
     * No code needed: the email match plus an authenticated session is the same
     * proof the code would have been. This is the one-tap "Join {company}" the
     * onboarding screen offers when it already knows there is an invitation
     * waiting.
     */
    public function acceptInvitation(Request $request): JsonResponse
    {
        $admin = $this->unaffiliatedAdmin($request);

        $email = Value::nullableString($admin->getAttribute('email'));

        if ($email === null || $email === '') {
            throw new ApiFailure('No invitation found', 404, 'no_pending_invitation');
        }

        $pinned = Value::int($request->input('invitation_id'));

        $invitation = ManagerInvitation::pendingForEmail($email, $pinned > 0 ? $pinned : null);

        if ($invitation === null) {
            throw new ApiFailure('لا توجد دعوة صالحة لهذا الحساب', 404, 'no_pending_invitation');
        }

        return $this->accept($invitation, $admin);
    }

    /**
     * @param  array<string, mixed>  $invitation
     */
    private function accept(array $invitation, Admin $admin): JsonResponse
    {
        $invitationId = Value::int($invitation['id'] ?? null);
        $tenantId = Value::int($invitation['tenant_id'] ?? null);
        $role = Value::string($invitation['role'] ?? null);
        $branchId = Value::nullableInt($invitation['branch_id'] ?? null);
        $permissions = Value::nullableString($invitation['permissions'] ?? null);
        $name = Value::string($invitation['name'] ?? null);

        // Claimed first, with the guard inside the UPDATE: two people racing
        // the same code must not both be let into the company.
        if (! ManagerInvitation::claim($invitationId, $admin->id)) {
            throw new ApiFailure('This invitation was already used', 410, 'invitation_was_already_used');
        }

        DB::transaction(function () use ($admin, $tenantId, $branchId, $role, $name, $permissions): void {
            DB::table('admins')->where('id', $admin->id)->update([
                'tenant_id' => $tenantId,
                'branch_id' => $branchId,
                'role' => $role,
                // The invitation may name them; if it does not, whatever they
                // signed up as stands.
                'name' => $name === '' ? $admin->name : $name,
            ]);

            if ($permissions !== null && $permissions !== '') {
                DB::table('custom_roles')->upsert(
                    [[
                        'tenant_id' => $tenantId,
                        'admin_id' => $admin->id,
                        'branch_id' => $branchId,
                        'name' => $role,
                        'permissions' => $permissions,
                    ]],
                    ['tenant_id', 'admin_id'],
                    ['permissions', 'branch_id'],
                );
            }
        });

        AuditLog::record($tenantId, $admin->id, 'invitation.accepted', 'invitation', $invitationId);

        $tenant = DB::table('tenants')->where('id', $tenantId)->first(['id', 'name', 'currency', 'timezone']);

        return ApiResponse::success([
            'success' => true,
            'tenant' => $tenant === null ? null : [
                'id' => $tenantId,
                'name' => $tenant->name,
                'currency' => $tenant->currency,
                'timezone' => $tenant->timezone,
            ],
            'user' => [
                'id' => $admin->id,
                'tenant_id' => $tenantId,
                'role' => $role,
                'role_key' => $role,
                'branch_id' => $branchId,
            ],
        ]);
    }

    /**
     * The signed-in administrator, provided they have no company yet.
     */
    private function unaffiliatedAdmin(Request $request): Admin
    {
        // The body carries it for the mobile apps, the header for the web
        // client; both are how those surfaces already send it.
        $token = Value::string($request->input('token'))
            ?: Value::string($request->header('X-Firebase-Token'))
            ?: Value::string($request->query('token'));

        if ($token === '') {
            throw new ApiFailure('Token is required', 400, 'token_required');
        }

        $identity = $this->verifier->verify($token);

        $admin = Admin::query()->where('firebase_uid', $identity->uid)->first();

        if ($admin === null) {
            throw new ApiFailure('Sign in first', 401, 'sign_first');
        }

        if ($admin->tenant_id !== null) {
            throw new ApiFailure('You already belong to a company', 409, 'you_already_belong_company');
        }

        return $admin;
    }

    private static function inRange(mixed $raw, int $min, int $max, string $message, string $code): int
    {
        $value = Value::int($raw);

        if ($value < $min || $value > $max) {
            throw new ApiFailure($message, 422, $code);
        }

        return $value;
    }
}
