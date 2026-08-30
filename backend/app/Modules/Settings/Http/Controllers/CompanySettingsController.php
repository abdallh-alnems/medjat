<?php

declare(strict_types=1);

namespace App\Modules\Settings\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Attendance\Domain\AttendanceMethod;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Branches\Domain\BranchNetworks;
use App\Modules\Categories\Domain\EmployeeCategories;
use App\Shared\Face\FaceMatcher;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/settings/company.php.
 *
 * Everything a company configures about how attendance is taken, plus the
 * overrides beneath it — branches, categories and named employees — returned
 * together so the settings screen can show the whole resolution chain rather
 * than one layer of it.
 */
final class CompanySettingsController
{
    /**
     * What a browser cannot check, whatever is configured elsewhere.
     *
     * Codes rather than sentences so each client localises them, and served
     * from here so the disclosure cannot drift between clients.
     *
     * @var list<string>
     */
    private const WEB_CHANNEL_LIMITATIONS = [
        'wifi_bssid',     // no access-point identity is available to a page
        'mock_location',  // no spoofing signal is reported to a page
        'face_match',     // the on-device face model does not run in a browser
    ];

    public function show(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $tenant = DB::table('tenants')->where('id', $tenantId)->first();

        if ($tenant === null) {
            throw new ApiFailure('Tenant not found', 404, 'not_found');
        }

        /** @var array<string, mixed> $company */
        $company = (array) $tenant;

        $methods = AttendanceMethod::decode($company['attendance_methods'] ?? null) ?: ['qr_gps'];

        return ApiResponse::success([
            'name' => Value::string($company['name'] ?? null),
            'address' => Value::string($company['company_address'] ?? null),
            'phone' => '',
            'email' => '',
            'attendance_methods' => $methods,
            'manual_attendance_admin_ids' => self::decodeIds($company['manual_attendance_admin_ids'] ?? null),
            'allow_offline_attendance' => Value::int($company['allow_offline_attendance'] ?? null, 1) === 1,
            'reject_mock_location' => Value::int($company['reject_mock_location'] ?? null) === 1,
            'require_local_biometric' => Value::int($company['require_local_biometric'] ?? null) === 1,
            'face_match_threshold' => Value::float(
                $company['face_match_threshold'] ?? null, FaceMatcher::DEFAULT_THRESHOLD,
            ),
            'face_liveness_required' => Value::int($company['face_liveness_required'] ?? null, 1) === 1,
            'face_enforce_mode' => Value::string($company['face_enforce_mode'] ?? null, 'log_only'),
            'gps_latitude' => Value::nullableFloat($company['gps_latitude'] ?? null),
            'gps_longitude' => Value::nullableFloat($company['gps_longitude'] ?? null),
            'gps_radius_meters' => Value::nullableInt($company['gps_radius_meters'] ?? null),
            'cycle_start_day' => Value::int($company['cycle_start_day'] ?? null, 1),
            'week_start_day' => Value::int($company['week_start_day'] ?? null, 6),
            'currency' => Value::string($company['currency'] ?? null, 'EGP'),
            'timezone' => Value::string($company['timezone'] ?? null, 'Africa/Cairo'),
            // False means nobody ever picked one, so the client may suggest the
            // device's zone. True means hands off.
            'timezone_is_explicit' => Value::int($company['timezone_is_explicit'] ?? null) === 1,
            // Off for every company that has not opted in. The photo default is
            // on, so enabling the weakest channel keeps the one control that
            // says anything about who pressed the button.
            'web_attendance_enabled' => Value::int($company['web_attendance_enabled'] ?? null) === 1,
            'web_attendance_photo_required' => Value::int($company['web_attendance_photo_required'] ?? null, 1) === 1,
            'web_channel_limitations' => self::WEB_CHANNEL_LIMITATIONS,
            'branches_without_ip_networks' => BranchNetworks::branchesWithoutIpControl($tenantId),
            // True when the company default would make the browser channel
            // useless: the page sends no method, so a browser punch always
            // resolves as gps_only, and without it every employee on the
            // company default is refused the instant they press the button.
            // Reported next to the switch because "I turned it on and nothing
            // works" is otherwise a support ticket whose cause is two screens
            // away.
            'web_requires_gps_only' => ! in_array('gps_only', $methods, true),
            'branches' => $this->branches($tenantId),
            'categories' => $this->categories($tenantId),
            'employee_overrides' => $this->employeeOverrides($tenantId),
            'commercial_register' => Value::string($company['commercial_register'] ?? null),
            'company_address' => Value::string($company['company_address'] ?? null),
            'company_phone' => Value::string($company['company_phone'] ?? null),
        ]);
    }

    public function save(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);

        $tenant = DB::table('tenants')->where('id', $tenantId)->first();

        if ($tenant === null) {
            throw new ApiFailure('Tenant not found', 404, 'not_found');
        }

        /** @var array<string, mixed> $current */
        $current = (array) $tenant;

        $fields = $this->identityFields($request);
        $fields += $this->cycleFields($request);
        $fields += $this->togglesFields($request);
        $fields += $this->faceFields($request, $current);
        $fields += $this->geofenceFields($request);
        $fields += $this->brandingFields($request);
        $fields += $this->methodFields($request, $tenantId, $current);

        // Audited on its own line: this is the switch that decides whether the
        // weakest verification surface in the product is open, and "who turned
        // it on, and when" is the first question anyone asks about a disputed
        // browser punch.
        $web = $this->webChannelFields($request, $current);

        if ($web !== []) {
            $fields += $web;

            AuditLog::record($tenantId, $admin->id, 'tenant.web_attendance_settings', 'tenant', $tenantId, [
                'enabled' => [
                    'from' => Value::int($current['web_attendance_enabled'] ?? null) === 1,
                    'to' => $web['web_attendance_enabled'] === 1,
                ],
                'photo_required' => [
                    'from' => Value::int($current['web_attendance_photo_required'] ?? null, 1) === 1,
                    'to' => $web['web_attendance_photo_required'] === 1,
                ],
            ]);
        }

        if ($fields !== []) {
            DB::table('tenants')->where('id', $tenantId)->update($fields);
        }

        AuditLog::record($tenantId, $admin->id, 'tenant.update_settings', 'tenant', $tenantId);

        return ApiResponse::success(['message' => 'Settings updated']);
    }

    /**
     * @return array<string, mixed>
     */
    private function identityFields(Request $request): array
    {
        $fields = [];

        if ($request->has('name')) {
            $fields['name'] = trim(Value::string($request->input('name')));
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

        if ($request->has('timezone')) {
            $timezone = trim(Value::string($request->input('timezone')));

            if (! in_array($timezone, timezone_identifiers_list(), true)) {
                throw new ApiFailure('Invalid timezone identifier', 422, 'invalid_timezone_identifier');
            }

            $fields['timezone'] = $timezone;
            // Saving from this screen is deliberate, so the client must never
            // auto-suggest a device timezone over it again.
            $fields['timezone_is_explicit'] = 1;
        }

        return $fields;
    }

    /**
     * @return array<string, int>
     */
    private function cycleFields(Request $request): array
    {
        $fields = [];

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

        return $fields;
    }

    /**
     * @return array<string, int>
     */
    private function togglesFields(Request $request): array
    {
        $toggles = [
            'allow_offline_attendance',
            'reject_mock_location',
            'require_local_biometric',
        ];

        $fields = [];

        foreach ($toggles as $toggle) {
            if ($request->has($toggle)) {
                $fields[$toggle] = self::boolean($request->input($toggle), $toggle) ? 1 : 0;
            }
        }

        return $fields;
    }

    /**
     * @param  array<string, mixed>  $current
     * @return array<string, mixed>
     */
    private function faceFields(Request $request, array $current): array
    {
        if (! $request->hasAny(['face_match_threshold', 'face_liveness_required', 'face_enforce_mode'])) {
            return [];
        }

        $threshold = $request->has('face_match_threshold')
            ? Value::float($request->input('face_match_threshold'))
            : Value::float($current['face_match_threshold'] ?? null, FaceMatcher::DEFAULT_THRESHOLD);

        // Below 0.3 the match means nothing; above 0.95 nobody ever passes.
        if ($threshold < 0.3 || $threshold > 0.95) {
            throw new ApiFailure(
                'face_match_threshold must be between 0.3 and 0.95',
                422,
                'face_match_threshold_range',
            );
        }

        $liveness = $request->has('face_liveness_required')
            ? self::boolean($request->input('face_liveness_required'), 'face_liveness_required')
            : Value::int($current['face_liveness_required'] ?? null, 1) === 1;

        $mode = $request->has('face_enforce_mode')
            ? Value::string($request->input('face_enforce_mode'))
            : Value::string($current['face_enforce_mode'] ?? null, 'log_only');

        if (! in_array($mode, ['log_only', 'enforce'], true)) {
            throw new ApiFailure('face_enforce_mode must be log_only or enforce', 422, 'face_enforce_mode_invalid');
        }

        return [
            'face_match_threshold' => $threshold,
            'face_liveness_required' => $liveness ? 1 : 0,
            'face_enforce_mode' => $mode,
        ];
    }

    /**
     * The company-wide geofence, the default for branches with no centre of
     * their own. All three move together; a null pair clears the location.
     *
     * @return array<string, mixed>
     */
    private function geofenceFields(Request $request): array
    {
        if (! $request->hasAny(['gps_latitude', 'gps_longitude', 'gps_radius_meters'])) {
            return [];
        }

        $latitude = $request->input('gps_latitude');
        $longitude = $request->input('gps_longitude');

        if ($latitude === null || $longitude === null) {
            return ['gps_latitude' => null, 'gps_longitude' => null, 'gps_radius_meters' => null];
        }

        return [
            'gps_latitude' => Value::float($latitude),
            'gps_longitude' => Value::float($longitude),
            'gps_radius_meters' => self::inRange(
                $request->input('gps_radius_meters'), 5, 5000,
                'gps_radius_meters must be between 5 and 5000', 'gps_radius_meters_between_5',
            ),
        ];
    }

    /**
     * @return array<string, string>
     */
    private function brandingFields(Request $request): array
    {
        $fields = [];

        foreach (['commercial_register', 'company_address', 'company_phone'] as $field) {
            if ($request->has($field)) {
                $fields[$field] = trim(Value::string($request->input($field)));
            }
        }

        return $fields;
    }

    /**
     * The attendance methods, and who may record attendance by hand.
     *
     * The two are separable. `has` rather than a null check on the list: null is
     * a real value there — it means "no restriction, any administrator may" —
     * and treating it as absent made clearing the list impossible without also
     * sending the whole method list along to carry it. That coupling is what
     * let an unrelated save silently rewrite a company's methods.
     *
     * @param  array<string, mixed>  $current
     * @return array<string, mixed>
     */
    private function methodFields(Request $request, int $tenantId, array $current): array
    {
        $touchesMethods = $request->has('attendance_methods');
        $touchesAdmins = $request->has('manual_attendance_admin_ids');

        if (! $touchesMethods && ! $touchesAdmins) {
            return [];
        }

        if ($touchesMethods) {
            $raw = $request->input('attendance_methods');

            if (! is_array($raw) || $raw === []) {
                throw new ApiFailure(
                    'attendance_methods must be a non-empty array',
                    422,
                    'attendance_methods_non_empty_array',
                );
            }

            $methods = [];

            foreach ($raw as $method) {
                if (! is_string($method) || ! in_array($method, AttendanceMethod::ALLOWED, true)) {
                    throw new ApiFailure(
                        'Invalid attendance method: '.Value::string($method)
                        .'. Allowed: '.implode(', ', AttendanceMethod::ALLOWED),
                        422,
                        'invalid_attendance_method',
                    );
                }

                $methods[] = $method;
            }

            $methods = array_values(array_unique($methods));
        } else {
            // Read through, never rewritten: this path has no opinion about the
            // methods and must not become a way to change them by omission.
            $methods = AttendanceMethod::decode($current['attendance_methods'] ?? null);
        }

        $adminIds = $touchesAdmins ? $request->input('manual_attendance_admin_ids') : null;

        // A restriction on a method nobody can use is noise, so it goes with it.
        if (! in_array('manual', $methods, true) && $touchesMethods) {
            $adminIds = null;
        }

        // Only guard when a list is actually being set. Refusing to *clear* one
        // because the method is off would leave a company unable to tidy up
        // after disabling manual attendance.
        if ($adminIds !== null && ! $touchesMethods && ! in_array('manual', $methods, true)) {
            throw new ApiFailure(
                'Cannot set manual_attendance_admin_ids when manual method is not enabled',
                422,
                'cannot_set_manual_attendance_admin',
            );
        }

        if ($adminIds !== null) {
            if (! is_array($adminIds)) {
                throw new ApiFailure(
                    'manual_attendance_admin_ids must be an array or null',
                    422,
                    'manual_attendance_admin_ids_array',
                );
            }

            foreach ($adminIds as $adminId) {
                $exists = DB::table('admins')
                    ->where('id', Value::int($adminId))->where('tenant_id', $tenantId)->exists();

                if (! $exists) {
                    throw new ApiFailure(
                        'Admin ID '.Value::string($adminId).' not found in this tenant',
                        422,
                        'admin_not_found',
                    );
                }
            }

            $adminIds = array_values(array_map(static fn (mixed $id): int => Value::int($id), $adminIds));
        }

        return [
            'attendance_methods' => json_encode($methods),
            'manual_attendance_admin_ids' => $adminIds === null ? null : json_encode($adminIds),
        ];
    }

    /**
     * @param  array<string, mixed>  $current
     * @return array<string, int>
     */
    private function webChannelFields(Request $request, array $current): array
    {
        if (! $request->hasAny(['web_attendance_enabled', 'web_attendance_photo_required'])) {
            return [];
        }

        $enabled = $request->has('web_attendance_enabled')
            ? self::boolean($request->input('web_attendance_enabled'), 'web_attendance_enabled')
            : Value::int($current['web_attendance_enabled'] ?? null) === 1;

        $photo = $request->has('web_attendance_photo_required')
            ? self::boolean($request->input('web_attendance_photo_required'), 'web_attendance_photo_required')
            : Value::int($current['web_attendance_photo_required'] ?? null, 1) === 1;

        return [
            'web_attendance_enabled' => $enabled ? 1 : 0,
            'web_attendance_photo_required' => $photo ? 1 : 0,
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function branches(int $tenantId): array
    {
        $rows = DB::table('branches')->where('tenant_id', $tenantId)->orderBy('name')->get()->all();

        /** @var list<array<string, mixed>> */
        return array_values(array_map(static function (mixed $row): array {
            /** @var array<string, mixed> $branch */
            $branch = (array) $row;

            $latitude = Value::float($branch['latitude'] ?? null);
            $longitude = Value::float($branch['longitude'] ?? null);

            return [
                'id' => Value::int($branch['id'] ?? null),
                'name' => $branch['name'] ?? null,
                'qr_code' => $branch['qr_code'] ?? null,
                // Null means inherit the company's methods.
                'attendance_methods' => self::inherited($branch['attendance_methods'] ?? null),
                'face_match_threshold' => Value::nullableFloat($branch['face_match_threshold'] ?? null),
                'face_liveness_required' => ($branch['face_liveness_required'] ?? null) === null
                    ? null
                    : Value::int($branch['face_liveness_required']) === 1,
                // Null wifi_mode means the branch never enabled the WiFi method.
                'wifi_mode' => $branch['wifi_mode'] ?? null,
                'wifi_match' => Value::string($branch['wifi_match'] ?? null, 'bssid'),
                'gps_radius_meters' => Value::int($branch['gps_radius_meters'] ?? null, 100),
                // The columns are NOT NULL, so 0,0 is how "unset" is stored —
                // and it is a real place in the Atlantic, not a branch.
                'lat' => $latitude === 0.0 ? null : $latitude,
                'lng' => $longitude === 0.0 ? null : $longitude,
                'cycle_start_day' => Value::nullableInt($branch['cycle_start_day'] ?? null),
            ];
        }, $rows));
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function categories(int $tenantId): array
    {
        /** @var list<array<string, mixed>> */
        return array_values(array_map(static function (array $category): array {
            return [
                'id' => Value::int($category['id'] ?? null),
                'name' => $category['name'] ?? null,
                'color' => $category['color'] ?? null,
                'employee_count' => Value::int($category['employee_count'] ?? null),
                'attendance_methods' => self::inherited($category['attendance_methods'] ?? null),
                // Null rather than false, so the screen can show three states
                // instead of guessing between two.
                'web_attendance_allowed' => ($category['web_attendance_allowed'] ?? null) === null
                    ? null
                    : Value::int($category['web_attendance_allowed']) === 1,
            ];
        }, EmployeeCategories::forTenant($tenantId, true)));
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function employeeOverrides(int $tenantId): array
    {
        $rows = DB::table('employees as e')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->where('e.tenant_id', $tenantId)
            ->whereNotNull('e.attendance_methods')
            ->where('e.status', '!=', 'terminated')
            ->orderBy('e.name')
            ->get(['e.id', 'e.name', 'e.attendance_methods', 'b.name as branch_name'])
            ->all();

        /** @var list<array<string, mixed>> */
        return array_values(array_map(static function (mixed $row): array {
            /** @var array<string, mixed> $employee */
            $employee = (array) $row;

            return [
                'id' => Value::int($employee['id'] ?? null),
                'name' => $employee['name'] ?? null,
                'branch_name' => $employee['branch_name'] ?? null,
                'attendance_methods' => self::inherited($employee['attendance_methods'] ?? null),
            ];
        }, $rows));
    }

    /**
     * An override's methods, keeping null distinct from an empty list.
     *
     * Null means inherit from the layer above; an empty list would mean the
     * override exists and permits nothing, which is a different thing and would
     * lock everybody at that branch out.
     *
     * @return list<string>|null
     */
    private static function inherited(mixed $stored): ?array
    {
        return $stored === null ? null : AttendanceMethod::decode($stored);
    }

    /**
     * @return list<int>|null
     */
    private static function decodeIds(mixed $stored): ?array
    {
        if (! is_string($stored) || $stored === '') {
            return null;
        }

        $decoded = json_decode($stored, true);

        if (! is_array($decoded)) {
            return null;
        }

        return array_values(array_map(static fn (mixed $id): int => Value::int($id), $decoded));
    }

    private static function boolean(mixed $raw, string $field): bool
    {
        $value = filter_var($raw, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);

        if ($value === null) {
            throw new ApiFailure("$field must be true or false", 422, $field.'_bool');
        }

        return $value;
    }

    private static function inRange(mixed $raw, int $min, int $max, string $message, string $code): int
    {
        $value = Value::int($raw);

        if ($value < $min || $value > $max) {
            throw new ApiFailure($message, 422, $code);
        }

        return $value;
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
