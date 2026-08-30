<?php

declare(strict_types=1);

namespace App\Modules\SuperAdmin\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\SuperAdmin;
use App\Modules\Attendance\Domain\AttendanceMethod;
use App\Modules\SuperAdmin\Domain\SuperAdminAudit;
use App\Modules\Team\Domain\ManagerInvitation;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/admin/tenants/*.php.
 *
 * The client list and the one company screen behind it.
 */
final class TenantController
{
    private const DEFAULT_LIMIT = 20;

    private const MIN_LIMIT = 5;

    private const MAX_LIMIT = 100;

    /**
     * The client list, searchable and paged.
     *
     * Each row carries the numbers you want before deciding to open a company
     * at all: who to call, how big they are, and whether anybody has used the
     * system lately.
     */
    public function index(Request $request): JsonResponse
    {
        $page = max(1, Value::int($request->query('page'), 1));
        $limit = min(self::MAX_LIMIT, max(self::MIN_LIMIT, Value::int($request->query('limit'), self::DEFAULT_LIMIT)));

        $search = trim(Value::string($request->query('q')));
        $status = Value::string($request->query('status'));

        $base = fn (): QueryBuilder => DB::table('tenants as t')
            ->when($search !== '', function (QueryBuilder $q) use ($search): void {
                $like = '%'.$search.'%';
                $q->where(function (QueryBuilder $inner) use ($like): void {
                    $inner->where('t.name', 'like', $like)
                        ->orWhere('t.contact_name', 'like', $like)
                        ->orWhere('t.contact_phone', 'like', $like)
                        ->orWhere('t.contact_email', 'like', $like);
                });
            })
            ->when($status === 'active', fn (QueryBuilder $q): QueryBuilder => $q->where('t.is_active', 1))
            ->when($status === 'inactive', fn (QueryBuilder $q): QueryBuilder => $q->where('t.is_active', 0));

        $total = $base()->count();

        // Correlated subqueries rather than joins and a GROUP BY: the page is
        // tens of rows, and it keeps each number independent — a company with
        // no branches still reports its employees correctly.
        $rows = $base()
            ->orderByDesc('t.created_at')
            ->limit($limit)->offset(($page - 1) * $limit)
            ->get([
                't.id', 't.name', 't.is_active', 't.timezone', 't.currency', 't.created_at',
                't.contact_name', 't.contact_email', 't.contact_phone',
                DB::raw("(SELECT COUNT(*) FROM employees e WHERE e.tenant_id = t.id AND e.status = 'active')"
                    .' AS employee_count'),
                DB::raw('(SELECT COUNT(*) FROM branches b WHERE b.tenant_id = t.id) AS branch_count'),
                DB::raw('(SELECT COUNT(*) FROM admins a WHERE a.tenant_id = t.id'
                    ." AND a.role NOT IN ('employee','pending')) AS admin_count"),
                DB::raw('(SELECT MAX(a.last_login_at) FROM admins a WHERE a.tenant_id = t.id)'
                    .' AS last_admin_login_at'),
                DB::raw('(SELECT MAX(at.date) FROM attendance at WHERE at.tenant_id = t.id'
                    .' AND at.check_in_time IS NOT NULL) AS last_attendance_date'),
            ])
            ->all();

        return ApiResponse::success([
            'items' => array_values(array_map(static function (mixed $row): array {
                /** @var array<string, mixed> $tenant */
                $tenant = (array) $row;

                return [
                    'id' => Value::int($tenant['id'] ?? null),
                    'name' => $tenant['name'] ?? null,
                    'is_active' => Value::int($tenant['is_active'] ?? null),
                    'timezone' => $tenant['timezone'] ?? null,
                    'currency' => $tenant['currency'] ?? null,
                    'created_at' => $tenant['created_at'] ?? null,
                    'contact_name' => $tenant['contact_name'] ?? null,
                    'contact_email' => $tenant['contact_email'] ?? null,
                    'contact_phone' => $tenant['contact_phone'] ?? null,
                    'employee_count' => Value::int($tenant['employee_count'] ?? null),
                    'branch_count' => Value::int($tenant['branch_count'] ?? null),
                    'admin_count' => Value::int($tenant['admin_count'] ?? null),
                    'last_admin_login_at' => $tenant['last_admin_login_at'] ?? null,
                    'last_attendance_date' => $tenant['last_attendance_date'] ?? null,
                ];
            }, $rows)),
            'total' => $total,
            'page' => $page,
            'limit' => $limit,
            'total_pages' => (int) ceil($total / $limit),
        ]);
    }

    /**
     * Everything we know about one company, on one screen.
     *
     * Read-only by construction: it selects and never writes, which is why
     * `readonly` may call it. Before it existed, every question the desk had —
     * how many employees, which attendance method, has anybody used it this
     * week — meant an SSH session and hand-written SQL, which the project rules
     * forbid outright.
     */
    public function show(Request $request): JsonResponse
    {
        $tenantId = self::existing($request);

        $row = DB::table('tenants')->where('id', $tenantId)->first();

        if ($row === null) {
            throw new ApiFailure('Tenant not found', 404, 'not_found');
        }

        /** @var array<string, mixed> $tenant */
        $tenant = (array) $row;

        // The company's own clock: "today" for a Gulf client is not our today,
        // and these counts are what the desk compares against what the customer
        // says on the phone.
        $today = TenantClock::date($tenantId);

        $employees = self::counts(
            DB::table('employees')->where('tenant_id', $tenantId)->selectRaw(
                'COUNT(*) AS total,'
                ." COALESCE(SUM(status = 'active'), 0) AS active,"
                ." COALESCE(SUM(status = 'pending_activation'), 0) AS pending,"
                ." COALESCE(SUM(biometric_enrollment_status <> 'not_enrolled'), 0) AS enrolled_biometric"
            )
        );

        $admins = self::counts(
            DB::table('admins')->where('tenant_id', $tenantId)->selectRaw(
                'COUNT(*) AS total, COALESCE(SUM(is_active = 1), 0) AS active'
            )
        );

        $methods = AttendanceMethod::decode($tenant['attendance_methods'] ?? null) ?: ['qr_gps'];

        return ApiResponse::success([
            'tenant' => [
                'id' => $tenantId,
                'name' => $tenant['name'] ?? null,
                'is_active' => Value::int($tenant['is_active'] ?? null),
                'timezone' => $tenant['timezone'] ?? null,
                'timezone_is_explicit' => Value::int($tenant['timezone_is_explicit'] ?? null),
                'currency' => $tenant['currency'] ?? null,
                'country_code' => $tenant['country_code'] ?? null,
                'cycle_start_day' => Value::int($tenant['cycle_start_day'] ?? null),
                'week_start_day' => Value::int($tenant['week_start_day'] ?? null),
                'created_at' => $tenant['created_at'] ?? null,
                'contact_name' => $tenant['contact_name'] ?? null,
                'contact_email' => $tenant['contact_email'] ?? null,
                'contact_phone' => $tenant['contact_phone'] ?? null,
                'ops_notes' => $tenant['ops_notes'] ?? null,
                'company_phone' => $tenant['company_phone'] ?? null,
                'company_address' => $tenant['company_address'] ?? null,
                'commercial_register' => $tenant['commercial_register'] ?? null,
            ],
            'settings' => [
                'attendance_methods' => $methods,
                'allow_offline_attendance' => Value::int($tenant['allow_offline_attendance'] ?? null),
                'reject_mock_location' => Value::int($tenant['reject_mock_location'] ?? null),
                'require_local_biometric' => Value::int($tenant['require_local_biometric'] ?? null),
                'web_attendance_enabled' => Value::int($tenant['web_attendance_enabled'] ?? null),
                'face_match_threshold' => Value::float($tenant['face_match_threshold'] ?? null),
                'face_liveness_required' => Value::int($tenant['face_liveness_required'] ?? null),
                'face_enforce_mode' => $tenant['face_enforce_mode'] ?? null,
                'default_annual_leave_days' => Value::int($tenant['default_annual_leave_days'] ?? null),
            ],
            'stats' => [
                'employees' => Value::int($employees['total'] ?? null),
                'employees_active' => Value::int($employees['active'] ?? null),
                'employees_pending' => Value::int($employees['pending'] ?? null),
                'employees_biometric' => Value::int($employees['enrolled_biometric'] ?? null),
                'branches' => DB::table('branches')->where('tenant_id', $tenantId)->count(),
                'admins' => Value::int($admins['total'] ?? null),
                'admins_active' => Value::int($admins['active'] ?? null),
                'pending_invitations' => DB::table('manager_invitations')
                    ->where('tenant_id', $tenantId)
                    ->whereNull('accepted_at')->whereNull('cancelled_at')
                    ->whereRaw('expires_at > NOW()')
                    ->count(),
                'attendance_today' => DB::table('attendance')
                    ->where('tenant_id', $tenantId)->where('date', $today)
                    ->whereNotNull('check_in_time')->count(),
                'attendance_last_7_days' => DB::table('attendance')
                    ->where('tenant_id', $tenantId)
                    ->whereRaw('date >= DATE_SUB(?, INTERVAL 7 DAY)', [$today])
                    ->whereNotNull('check_in_time')->count(),
            ],
            'activity' => [
                'today' => $today,
                'last_attendance_date' => DB::table('attendance')
                    ->where('tenant_id', $tenantId)->whereNotNull('check_in_time')->max('date'),
                'last_admin_login_at' => DB::table('admins')
                    ->where('tenant_id', $tenantId)->max('last_login_at'),
                'last_absence_run' => $tenant['last_absence_date'] ?? null,
            ],
            'managers' => $this->managers($tenantId),
        ]);
    }

    /**
     * The people we can actually call, the general manager first.
     *
     * Doubles as the contact list while tenants.contact_* is still empty, which
     * for an older company it usually is.
     *
     * @return list<array<string, mixed>>
     */
    private function managers(int $tenantId): array
    {
        $rows = DB::table('admins')
            ->where('tenant_id', $tenantId)
            ->whereNotIn('role', ['employee', 'pending'])
            ->orderByRaw("(role = 'general_manager') DESC")
            ->orderByRaw('last_login_at IS NULL')
            ->orderByDesc('last_login_at')
            ->limit(20)
            ->get(['id', 'name', 'phone', 'email', 'role', 'is_active', 'last_login_at', 'created_at'])
            ->all();

        return array_values(array_map(static function (mixed $row): array {
            /** @var array<string, mixed> $manager */
            $manager = (array) $row;

            return [
                'id' => Value::int($manager['id'] ?? null),
                'name' => $manager['name'] ?? null,
                'phone' => $manager['phone'] ?? null,
                'email' => $manager['email'] ?? null,
                'role' => $manager['role'] ?? null,
                'is_active' => Value::int($manager['is_active'] ?? null),
                'last_login_at' => $manager['last_login_at'] ?? null,
                'created_at' => $manager['created_at'] ?? null,
            ];
        }, $rows));
    }

    /**
     * @return array<string, mixed>
     */
    private static function counts(QueryBuilder $query): array
    {
        /** @var array<string, mixed> $row */
        $row = (array) $query->first();

        return $row;
    }

    /**
     * Onboarding a company from the desk.
     *
     * The one path where we create a company rather than a customer signing
     * themselves up, and the difference matters: a self-signup is performed by
     * a signed-in person who becomes the general manager, while a super admin
     * has no row in `admins` at all. Creating only the tenant would leave a
     * company nobody can log into — which is exactly what the original did
     * before it grew the invitation, collecting the owner's details and
     * dropping them on the floor.
     *
     * So it is two things in one transaction: the company, and a pending
     * general-manager invitation for the owner's email, redeemed through the
     * same flow and the same window as a colleague-to-colleague invite.
     */
    public function create(Request $request): JsonResponse
    {
        $admin = self::admin($request);

        $name = trim(Value::string($request->input('name')));

        if ($name === '') {
            throw new ApiFailure('اسم الشركة مطلوب', 422, 'name_required');
        }

        $fields = ['name' => $name, 'is_active' => 1, 'email_verified_at' => DB::raw('NOW()')]
            + $this->localeFields($request)
            + $this->contactFields($request);

        $ownerEmail = self::trimmed($request->input('owner_email'));

        if ($ownerEmail !== null) {
            if (filter_var($ownerEmail, FILTER_VALIDATE_EMAIL) === false) {
                throw new ApiFailure('بريد المالك غير صالح', 422, 'invalid_owner_email');
            }

            // Somebody already inside another company cannot be handed a
            // second one — the same guard as a colleague invitation.
            $taken = DB::table('admins')
                ->where('email', $ownerEmail)->whereNotNull('tenant_id')->exists();

            if ($taken) {
                throw new ApiFailure('هذا البريد ينتمي لشركة أخرى بالفعل', 409, 'email_belongs_elsewhere');
            }
        }

        $ownerName = self::trimmed($request->input('owner_name'))
            ?? Value::nullableString($fields['contact_name'] ?? null)
            ?? '';

        /** @var array{tenant_id: int, invitation: array{id: int, code: string, expires_at: string}|null} $created */
        $created = DB::transaction(function () use ($fields, $ownerEmail, $ownerName): array {
            $tenantId = (int) DB::table('tenants')->insertGetId($fields);

            return [
                'tenant_id' => $tenantId,
                // invited_by stays null: a super admin is not an `admins` row.
                'invitation' => $ownerEmail === null ? null : ManagerInvitation::create($tenantId, null, [
                    'email' => $ownerEmail,
                    'name' => $ownerName,
                    'role' => 'general_manager',
                    'branch_id' => null,
                    'permissions' => null,
                ]),
            ];
        });

        SuperAdminAudit::record($admin->id, 'tenant.create', 'tenant', $created['tenant_id'], [
            'name' => $name,
            'owner_email' => $ownerEmail,
            'invited' => $created['invitation'] !== null,
        ]);

        if ($created['invitation'] !== null && $ownerEmail !== null) {
            ManagerInvitation::email($ownerEmail, $created['invitation']['code'], 'general_manager', $name);
        }

        // The code and join URL come back as well, which is how the panel
        // shares an invite when somebody is on the phone.
        return ApiResponse::success([
            'tenant_id' => $created['tenant_id'],
            'name' => $name,
            'invitation' => $created['invitation'] === null ? null : [
                'code' => $created['invitation']['code'],
                'email' => $ownerEmail,
                'expires_at' => $created['invitation']['expires_at'],
                'expires_in_hours' => ManagerInvitation::VALIDITY_HOURS,
                'join_url' => ManagerInvitation::joinUrl($created['invitation']['code']),
            ],
        ]);
    }

    /**
     * Editing a company from the desk.
     *
     * Only fields actually present are written: an agent correcting a phone
     * number must not silently reset a timezone they never saw.
     */
    public function update(Request $request): JsonResponse
    {
        $admin = self::admin($request);
        $tenantId = self::existing($request);

        $updates = [];

        if ($request->has('name')) {
            $name = trim(Value::string($request->input('name')));

            if ($name === '') {
                throw new ApiFailure('اسم الشركة لا يمكن أن يكون فارغًا', 422, 'name_required');
            }

            $updates['name'] = $name;
        }

        $updates += $this->localeFields($request);

        // Contact fields accept '' as "clear it" — unlike the settings above,
        // erasing a stale phone number is a normal support action.
        foreach (['contact_name', 'contact_email', 'contact_phone', 'ops_notes'] as $field) {
            if (! $request->has($field)) {
                continue;
            }

            $value = trim(Value::string($request->input($field)));

            if ($field === 'contact_email' && $value !== ''
                && filter_var($value, FILTER_VALIDATE_EMAIL) === false) {
                throw new ApiFailure('بريد جهة الاتصال غير صالح', 422, 'invalid_contact_email');
            }

            $updates[$field] = $value === '' ? null : $value;
        }

        if ($updates === []) {
            throw new ApiFailure('لا يوجد ما يتم تحديثه', 422, 'nothing_to_update');
        }

        DB::table('tenants')->where('id', $tenantId)->update($updates);

        // The field names, not their values: the audit log records that a
        // support agent changed a company's contact details, without copying
        // the customer's phone number into a second table.
        SuperAdminAudit::record($admin->id, 'tenant.update', 'tenant', $tenantId, [
            'fields' => array_keys($updates),
        ]);

        return ApiResponse::success(['tenant_id' => $tenantId, 'updated' => array_keys($updates)]);
    }

    public function activate(Request $request): JsonResponse
    {
        return $this->setActive($request, true);
    }

    public function deactivate(Request $request): JsonResponse
    {
        return $this->setActive($request, false);
    }

    private function setActive(Request $request, bool $active): JsonResponse
    {
        $admin = self::admin($request);
        $tenantId = self::existing($request);

        DB::table('tenants')->where('id', $tenantId)->update(['is_active' => $active ? 1 : 0]);

        SuperAdminAudit::record(
            $admin->id, $active ? 'tenant.activate' : 'tenant.deactivate', 'tenant', $tenantId,
        );

        return ApiResponse::success(['message' => $active ? 'Tenant activated' : 'Tenant deactivated']);
    }

    /**
     * @return array<string, mixed>
     */
    private function localeFields(Request $request): array
    {
        $fields = [];

        if (self::filled($request, 'timezone')) {
            $timezone = trim(Value::string($request->input('timezone')));

            if (! in_array($timezone, timezone_identifiers_list(), true)) {
                throw new ApiFailure('المنطقة الزمنية غير صالحة', 422, 'invalid_timezone');
            }

            $fields['timezone'] = $timezone;
            // Setting it by hand is always deliberate, so it clears the "we
            // guessed this" flag the settings screen reads.
            $fields['timezone_is_explicit'] = 1;
        }

        if (self::filled($request, 'currency')) {
            $currency = strtoupper(trim(Value::string($request->input('currency'))));

            if (preg_match('/^[A-Z]{3}$/', $currency) !== 1) {
                throw new ApiFailure('العملة يجب أن تكون رمزًا من 3 أحرف (مثل EGP)', 422, 'invalid_currency');
            }

            $fields['currency'] = $currency;
        }

        if (self::filled($request, 'cycle_start_day')) {
            $fields['cycle_start_day'] = self::inRange(
                $request->input('cycle_start_day'), 1, 28,
                'بداية دورة الحضور يجب أن تكون بين 1 و 28', 'invalid_cycle_start_day',
            );
        }

        if (self::filled($request, 'week_start_day')) {
            $fields['week_start_day'] = self::inRange(
                $request->input('week_start_day'), 1, 7,
                'بداية الأسبوع يجب أن تكون بين 1 (الاثنين) و 7 (الأحد)', 'invalid_week_start_day',
            );
        }

        return $fields;
    }

    /**
     * Who we call about this account. Kept even when no invitation goes out —
     * a company onboarded over the phone still needs a contact.
     *
     * @return array<string, string|null>
     */
    private function contactFields(Request $request): array
    {
        $email = self::trimmed($request->input('contact_email'));

        if ($email !== null && filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
            throw new ApiFailure('بريد جهة الاتصال غير صالح', 422, 'invalid_contact_email');
        }

        $fields = [];

        foreach (['contact_name', 'contact_phone', 'ops_notes'] as $field) {
            $value = self::trimmed($request->input($field));

            if ($value !== null) {
                $fields[$field] = $value;
            }
        }

        if ($email !== null) {
            $fields['contact_email'] = $email;
        }

        return $fields;
    }

    private static function existing(Request $request): int
    {
        $id = Value::int($request->input('id')) ?: Value::int($request->query('id'));

        if ($id <= 0) {
            throw new ApiFailure('معرّف الشركة مطلوب', 422, 'id_required');
        }

        if (! DB::table('tenants')->where('id', $id)->exists()) {
            throw new ApiFailure('Tenant not found', 404, 'not_found');
        }

        return $id;
    }

    private static function filled(Request $request, string $field): bool
    {
        return $request->has($field) && trim(Value::string($request->input($field))) !== '';
    }

    private static function trimmed(mixed $raw): ?string
    {
        $value = trim(Value::string($raw));

        return $value === '' ? null : $value;
    }

    private static function inRange(mixed $raw, int $min, int $max, string $message, string $code): int
    {
        $value = Value::int($raw);

        if ($value < $min || $value > $max) {
            throw new ApiFailure($message, 422, $code);
        }

        return $value;
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
