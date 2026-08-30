<?php

declare(strict_types=1);

namespace App\Modules\SuperAdmin\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\SuperAdmin;
use App\Modules\SuperAdmin\Domain\SuperAdminAudit;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/admin/users/*.php and api/admin/audit/list.php.
 *
 * Two directories that are easy to confuse, and once were: the company
 * administrators we support, and the operators of the panel itself. The
 * original listed one table and created rows in the other, so a super admin you
 * created never appeared anywhere.
 */
final class DirectoryController
{
    private const DEFAULT_LIMIT = 20;

    private const MIN_LIMIT = 5;

    private const MAX_LIMIT = 100;

    private const AUDIT_DEFAULT_LIMIT = 50;

    private const AUDIT_MIN_LIMIT = 10;

    private const AUDIT_MAX_LIMIT = 200;

    private const OPERATOR_ROLES = ['readonly', 'admin', 'superadmin'];

    private const MIN_USERNAME_LENGTH = 3;

    private const MIN_PASSWORD_LENGTH = 6;

    /**
     * The client contact book: every company administrator on the platform.
     *
     * Not the panel's own team, and not a staff directory. It answers "who do I
     * call at this company", which is why it carries the company name, the
     * phone, the email, and the number that decides whether the call is worth
     * making at all — when they last signed in.
     */
    public function admins(Request $request): JsonResponse
    {
        [$page, $limit] = self::paging($request, self::DEFAULT_LIMIT, self::MIN_LIMIT, self::MAX_LIMIT);

        $search = trim(Value::string($request->query('q')));
        $tenantId = Value::int($request->query('tenant_id'));
        $role = trim(Value::string($request->query('role')));
        $status = Value::string($request->query('status'));

        $base = fn (): QueryBuilder => DB::table('admins as a')
            ->leftJoin('tenants as t', 't.id', '=', 'a.tenant_id')
            // 'employee' rows are staff accounts sharing the table; they are not
            // contacts. 'pending' stays — somebody mid-signup is exactly who
            // calls support.
            ->where('a.role', '!=', 'employee')
            ->when($tenantId > 0, fn (QueryBuilder $q): QueryBuilder => $q->where('a.tenant_id', $tenantId))
            ->when($role !== '', fn (QueryBuilder $q): QueryBuilder => $q->where('a.role', $role))
            ->when($status === 'active', fn (QueryBuilder $q): QueryBuilder => $q->where('a.is_active', 1))
            ->when($status === 'inactive', fn (QueryBuilder $q): QueryBuilder => $q->where('a.is_active', 0))
            ->when($search !== '', function (QueryBuilder $q) use ($search): void {
                $like = '%'.$search.'%';
                $q->where(function (QueryBuilder $inner) use ($like): void {
                    $inner->where('a.name', 'like', $like)
                        ->orWhere('a.email', 'like', $like)
                        ->orWhere('a.phone', 'like', $like)
                        ->orWhere('t.name', 'like', $like);
                });
            });

        $total = $base()->count();

        $rows = $base()
            // Never-signed-in last: the useful end of this list is the people
            // who have actually used the product.
            ->orderByRaw('a.last_login_at IS NULL')
            ->orderByDesc('a.last_login_at')
            ->orderByDesc('a.id')
            ->limit($limit)->offset(($page - 1) * $limit)
            ->get([
                'a.id', 'a.tenant_id', 'a.branch_id', 'a.name', 'a.phone', 'a.email', 'a.role',
                'a.auth_provider', 'a.is_active', 'a.last_login_at', 'a.created_at',
                't.name as tenant_name', 't.is_active as tenant_is_active',
            ])
            ->all();

        return ApiResponse::success(self::paged(
            array_values(array_map(static function (mixed $row): array {
                /** @var array<string, mixed> $admin */
                $admin = (array) $row;

                return [
                    'id' => Value::int($admin['id'] ?? null),
                    'tenant_id' => Value::nullableInt($admin['tenant_id'] ?? null),
                    'tenant_name' => $admin['tenant_name'] ?? null,
                    'tenant_is_active' => Value::nullableInt($admin['tenant_is_active'] ?? null),
                    'branch_id' => Value::nullableInt($admin['branch_id'] ?? null),
                    'name' => $admin['name'] ?? null,
                    'phone' => $admin['phone'] ?? null,
                    'email' => $admin['email'] ?? null,
                    'role' => $admin['role'] ?? null,
                    'auth_provider' => $admin['auth_provider'] ?? null,
                    'is_active' => Value::int($admin['is_active'] ?? null),
                    'last_login_at' => $admin['last_login_at'] ?? null,
                    'created_at' => $admin['created_at'] ?? null,
                ];
            }, $rows)),
            $total,
            $page,
            $limit,
        ));
    }

    /** Adds an operator of the panel itself. */
    public function createOperator(Request $request): JsonResponse
    {
        $caller = self::admin($request);

        $username = trim(Value::string($request->input('username')));
        $password = Value::string($request->input('password'));
        $role = Value::string($request->input('role'), 'admin') ?: 'admin';

        if (mb_strlen($username) < self::MIN_USERNAME_LENGTH) {
            throw new ApiFailure('اسم المستخدم قصير جداً (3 أحرف على الأقل)', 422, 'username_too_short');
        }

        if (mb_strlen($password) < self::MIN_PASSWORD_LENGTH) {
            throw new ApiFailure('كلمة المرور قصيرة جداً (6 أحرف على الأقل)', 422, 'password_too_short');
        }

        if (! in_array($role, self::OPERATOR_ROLES, true)) {
            throw new ApiFailure('الدور غير صالح', 422, 'invalid_role');
        }

        $email = trim(Value::string($request->input('email'))) ?: null;

        if ($email !== null && filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
            throw new ApiFailure('البريد الإلكتروني غير صالح', 422, 'invalid_email');
        }

        if (DB::table('super_admins')->where('username', $username)->exists()) {
            throw new ApiFailure('اسم المستخدم مستخدم بالفعل', 422, 'username_taken');
        }

        if ($email !== null && DB::table('super_admins')->where('email', $email)->exists()) {
            throw new ApiFailure('البريد الإلكتروني مستخدم بالفعل', 422, 'email_taken');
        }

        $displayName = trim(Value::string($request->input('display_name'))) ?: null;

        $id = (int) DB::table('super_admins')->insertGetId([
            'username' => $username,
            'email' => $email,
            'password_hash' => password_hash($password, PASSWORD_DEFAULT),
            'display_name' => $displayName,
            'role' => $role,
            'is_active' => 1,
        ]);

        SuperAdminAudit::record($caller->id, 'super_admin.create', 'super_admin', $id, ['role' => $role]);

        return ApiResponse::success([
            'id' => $id,
            'username' => $username,
            'display_name' => $displayName ?? $username,
            'email' => $email,
            'role' => $role,
        ]);
    }

    /**
     * The panel's own audit trail, made readable.
     *
     * The original returned raw rows: an action string, a target id, an IP. Not
     * who did it — the admin id was never resolved to a name — not what changed,
     * since `payload` was selected and then ignored, and with no filters and no
     * page control, which meant only the newest fifty events existed as far as
     * the panel was concerned.
     */
    public function audit(Request $request): JsonResponse
    {
        [$page, $limit] = self::paging(
            $request, self::AUDIT_DEFAULT_LIMIT, self::AUDIT_MIN_LIMIT, self::AUDIT_MAX_LIMIT,
        );

        $action = trim(Value::string($request->query('action')));
        $adminId = Value::int($request->query('admin_id'));
        $targetType = trim(Value::string($request->query('target_type')));
        $from = trim(Value::string($request->query('from')));
        $to = trim(Value::string($request->query('to')));
        $search = trim(Value::string($request->query('q')));

        $base = fn (): QueryBuilder => DB::table('super_admin_audit_log as l')
            // Prefix match, so 'tenant' finds tenant.create and tenant.update.
            ->when($action !== '', fn (QueryBuilder $q): QueryBuilder => $q->where('l.action', 'like', $action.'%'))
            ->when($adminId > 0, fn (QueryBuilder $q): QueryBuilder => $q->where('l.admin_id', $adminId))
            ->when($targetType !== '', fn (QueryBuilder $q): QueryBuilder => $q->where('l.target_type', $targetType))
            ->when($from !== '', fn (QueryBuilder $q): QueryBuilder => $q->where('l.created_at', '>=', $from.' 00:00:00'))
            ->when($to !== '', fn (QueryBuilder $q): QueryBuilder => $q->where('l.created_at', '<=', $to.' 23:59:59'))
            ->when($search !== '', function (QueryBuilder $q) use ($search): void {
                $like = '%'.$search.'%';
                $q->where(function (QueryBuilder $inner) use ($like): void {
                    $inner->where('l.action', 'like', $like)
                        ->orWhere('l.payload', 'like', $like)
                        ->orWhere('l.target_id', 'like', $like);
                });
            });

        $total = $base()->count();

        $rows = $base()
            ->leftJoin('super_admins as s', 's.id', '=', 'l.admin_id')
            ->orderByDesc('l.created_at')->orderByDesc('l.id')
            ->limit($limit)->offset(($page - 1) * $limit)
            ->get([
                'l.id', 'l.admin_id', 'l.action', 'l.target_type', 'l.target_id',
                'l.payload', 'l.ip', 'l.created_at', 's.username', 's.display_name',
            ])
            ->all();

        return ApiResponse::success(self::paged(
            array_values(array_map(static function (mixed $row): array {
                /** @var array<string, mixed> $entry */
                $entry = (array) $row;

                return [
                    'id' => Value::int($entry['id'] ?? null),
                    'admin_id' => Value::nullableInt($entry['admin_id'] ?? null),
                    'admin_name' => Value::nullableString($entry['display_name'] ?? null)
                        ?? Value::nullableString($entry['username'] ?? null),
                    'action' => $entry['action'] ?? null,
                    'target_type' => $entry['target_type'] ?? null,
                    'target_id' => $entry['target_id'] ?? null,
                    'payload' => self::payload($entry['payload'] ?? null),
                    'ip' => $entry['ip'] ?? null,
                    'created_at' => $entry['created_at'] ?? null,
                ];
            }, $rows)),
            $total,
            $page,
            $limit,
        ));
    }

    /**
     * @return array<array-key, mixed>|null
     */
    private static function payload(mixed $stored): ?array
    {
        $raw = Value::string($stored);

        if ($raw === '') {
            return null;
        }

        $decoded = json_decode($raw, true);

        // Kept as a string when it is not valid JSON, rather than dropping the
        // only record of what happened.
        return is_array($decoded) ? $decoded : ['raw' => $raw];
    }

    /**
     * @param  list<array<string, mixed>>  $items
     * @return array<string, mixed>
     */
    private static function paged(array $items, int $total, int $page, int $limit): array
    {
        return [
            'items' => $items,
            'total' => $total,
            'page' => $page,
            'limit' => $limit,
            'total_pages' => (int) ceil($total / $limit),
        ];
    }

    /**
     * @return array{0: int, 1: int}
     */
    private static function paging(Request $request, int $default, int $min, int $max): array
    {
        return [
            max(1, Value::int($request->query('page'), 1)),
            min($max, max($min, Value::int($request->query('limit'), $default))),
        ];
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
