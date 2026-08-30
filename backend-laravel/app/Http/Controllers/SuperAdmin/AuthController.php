<?php

declare(strict_types=1);

namespace App\Http\Controllers\SuperAdmin;

use App\Domain\SuperAdmin\SuperAdminAudit;
use App\Domain\SuperAdmin\SuperAdminSession;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\SuperAdmin;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/admin/auth/*.php.
 *
 * Signing in to the support desk. Two ways, because the panel was built around
 * a username and password and later gained Google sign-in: a Firebase token if
 * one is sent, otherwise credentials.
 */
final class AuthController
{
    private const MIN_PASSWORD_LENGTH = 8;

    public function __construct(private readonly FirebaseTokenVerifier $verifier) {}

    public function login(Request $request): JsonResponse
    {
        $firebaseToken = Value::string($request->input('token'));

        return $firebaseToken !== ''
            ? $this->withFirebase($request, $firebaseToken)
            : $this->withPassword($request);
    }

    public function logout(Request $request): JsonResponse
    {
        $admin = self::admin($request);

        SuperAdminSession::close(Value::string($request->bearerToken()));

        SuperAdminAudit::record($admin->id, 'auth.logout', 'super_admin', $admin->id);

        return ApiResponse::success(['message' => 'Logged out']);
    }

    /**
     * The signed-in operator, and what the account screen shows about the
     * session itself.
     */
    public function me(Request $request): JsonResponse
    {
        $admin = self::admin($request);

        return ApiResponse::success([
            'id' => $admin->id,
            'username' => $admin->username,
            'display_name' => $admin->display_name,
            'role' => $admin->role,
            'email' => $admin->email,
            'last_login_at' => $admin->getAttribute('last_login_at'),
            'last_login_ip' => $admin->getAttribute('last_login_ip'),
            'created_at' => $admin->getAttribute('created_at'),
            // How many other devices still hold a live token — the only way to
            // notice one you did not sign in from.
            'active_sessions' => SuperAdminSession::activeCount($admin->id),
        ]);
    }

    /**
     * The one piece of account management a single-operator panel genuinely
     * needs: without it, a forgotten password means hand-written SQL on the
     * production server, which the project rules forbid outright.
     */
    public function changePassword(Request $request): JsonResponse
    {
        $admin = self::admin($request);

        $current = Value::string($request->input('current_password'));
        $new = Value::string($request->input('new_password'));

        if ($current === '' || $new === '') {
            throw new ApiFailure('كلمة المرور الحالية والجديدة مطلوبتان', 422, 'passwords_required');
        }

        if (mb_strlen($new) < self::MIN_PASSWORD_LENGTH) {
            throw new ApiFailure(
                'كلمة المرور الجديدة قصيرة جدًا (8 أحرف على الأقل)',
                422,
                'password_too_short',
            );
        }

        if ($new === $current) {
            throw new ApiFailure('كلمة المرور الجديدة مطابقة للحالية', 422, 'password_unchanged');
        }

        if (! password_verify($current, $admin->password_hash)) {
            // Logged, because a run of these is somebody guessing.
            SuperAdminAudit::record($admin->id, 'auth.change_password_failed', 'super_admin', $admin->id);

            throw new ApiFailure('كلمة المرور الحالية غير صحيحة', 401, 'wrong_password');
        }

        DB::table('super_admins')->where('id', $admin->id)->update([
            'password_hash' => password_hash($new, PASSWORD_DEFAULT),
        ]);

        // Every other device is signed out: a password change that leaves the
        // old sessions alive protects nothing, because whoever prompted it
        // still holds a working token.
        SuperAdminSession::closeOthers($admin->id, Value::string($request->bearerToken()));

        SuperAdminAudit::record($admin->id, 'auth.change_password', 'super_admin', $admin->id);

        return ApiResponse::success(['changed' => true]);
    }

    private function withFirebase(Request $request, string $firebaseToken): JsonResponse
    {
        $identity = $this->verifier->verify($firebaseToken);

        // Matched on either, so an account created with a username can start
        // signing in with Google without anybody editing a row by hand.
        $admin = SuperAdmin::query()
            ->where('firebase_uid', $identity->uid)
            ->when($identity->email !== null, fn ($q) => $q->orWhere('email', $identity->email))
            ->first();

        if ($admin === null) {
            throw new ApiFailure('Admin account not found', 404, 'not_found');
        }

        if ($admin->is_active !== 1) {
            throw new ApiFailure('Admin account disabled', 403, 'admin_disabled');
        }

        // First Google sign-in on an account that was matched by email: the uid
        // is bound so later sign-ins match on it directly.
        if (Value::string($admin->getAttribute('firebase_uid')) === '') {
            DB::table('super_admins')->where('id', $admin->id)->update(['firebase_uid' => $identity->uid]);
        }

        $session = $this->start($admin, $request);

        SuperAdminAudit::record($admin->id, 'auth.firebase_login', 'super_admin', $admin->id);

        return ApiResponse::success($session + [
            'user' => [
                'id' => $admin->id,
                'name' => $admin->display_name ?? $admin->username,
                'email' => $identity->email,
                'role_key' => $admin->role,
            ],
        ]);
    }

    private function withPassword(Request $request): JsonResponse
    {
        $username = Value::string($request->input('username'));
        $password = Value::string($request->input('password'));

        if ($username === '' || $password === '') {
            throw new ApiFailure('username and password are required', 422, 'credentials_required');
        }

        $admin = SuperAdmin::query()->where('username', $username)->first();

        // One message for every failure — a wrong username and a wrong password
        // must not be distinguishable, or the panel becomes a way to enumerate
        // operator accounts. password_verify runs against a dummy hash when
        // there is no account, so the timing does not distinguish them either.
        $verified = $admin !== null
            && $admin->is_active === 1
            && password_verify($password, $admin->password_hash);

        if ($admin === null) {
            password_verify($password, '$2y$10$usesomesillystringfoeXCPeSjEnaCJ2j0eGb0FLVoftaHtIu');
        }

        if (! $verified || $admin === null) {
            throw new ApiFailure('Invalid credentials', 401, 'invalid_credentials');
        }

        $session = $this->start($admin, $request);

        SuperAdminAudit::record($admin->id, 'auth.login', 'super_admin', $admin->id);

        return ApiResponse::success($session + [
            'admin' => [
                'id' => $admin->id,
                'username' => $admin->username,
                'display_name' => $admin->display_name,
                'role' => $admin->role,
            ],
        ]);
    }

    /**
     * @return array{token: string, expires_at: string}
     */
    private function start(SuperAdmin $admin, Request $request): array
    {
        return SuperAdminSession::open(
            $admin->id,
            $request->ip() ?? '',
            (string) $request->userAgent(),
        );
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
