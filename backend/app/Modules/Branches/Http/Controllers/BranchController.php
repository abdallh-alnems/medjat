<?php

declare(strict_types=1);

namespace App\Modules\Branches\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Modules\Attendance\Domain\AttendanceMethod;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Branches\Domain\Branches;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/branches/{list,create,update,generate_qr,
 * update_attendance_method}.php.
 *
 * A company's sites and what each one may decide for itself.
 */
final class BranchController
{
    public function index(Request $request): JsonResponse
    {
        // Deliberately readable by anybody signed in: every screen that shows a
        // branch picker needs this, and gating it would break navigation for
        // roles that can legitimately reach those screens.
        return ApiResponse::success([
            'branches' => Branches::forTenant(Value::int($request->attributes->get('tenant_id'))),
        ]);
    }

    public function create(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $name = trim(Value::string($request->input('name')));

        if ($name === '') {
            throw new ApiFailure('name is required', 422, 'name_required');
        }

        $branchId = Branches::create($tenantId, [
            'name' => $name,
            'address' => Value::nullableString($request->input('address')),
            'latitude' => Value::float($request->input('latitude')),
            'longitude' => Value::float($request->input('longitude')),
        ]);

        AuditLog::record($tenantId, $adminId, 'branch.create', 'branch', $branchId);

        return ApiResponse::success(['branch_id' => $branchId], 201);
    }

    public function update(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $branchId = self::existing($request, $tenantId);

        $changes = [];

        foreach (['name', 'address'] as $field) {
            if ($request->has($field)) {
                $changes[$field] = Value::nullableString($request->input($field));
            }
        }

        foreach (['latitude', 'longitude'] as $field) {
            if ($request->has($field)) {
                $changes[$field] = Value::float($request->input($field));
            }
        }

        if ($request->has('gps_radius_meters')) {
            $radius = Value::int($request->input('gps_radius_meters'));

            if ($radius < 5 || $radius > 5000) {
                throw new ApiFailure('gps_radius_meters must be between 5 and 5000', 422, 'gps_radius_meters_between_5');
            }

            $changes['gps_radius_meters'] = $radius;
        }

        if ($request->has('cycle_start_day')) {
            $raw = $request->input('cycle_start_day');

            // Null means inherit the company's cycle, which is different from
            // choosing the first of the month.
            if ($raw === null || $raw === '') {
                $changes['cycle_start_day'] = null;
            } else {
                $day = Value::int($raw);

                if ($day < 1 || $day > 28) {
                    throw new ApiFailure(
                        'cycle_start_day must be between 1 and 28, or null',
                        422,
                        'cycle_start_day_between_1',
                    );
                }

                $changes['cycle_start_day'] = $day;
            }
        }

        Branches::update($branchId, $tenantId, $changes);

        AuditLog::record($tenantId, $adminId, 'branch.update', 'branch', $branchId);

        return ApiResponse::success(['message' => 'Branch updated']);
    }

    public function generateQr(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $branchId = self::existing($request, $tenantId);

        $code = Branches::ensureQrCode($branchId, $tenantId, Value::int($request->input('force')) === 1);

        AuditLog::record($tenantId, $adminId, 'branch.generate_qr', 'branch', $branchId);

        return ApiResponse::success(['qr_code' => $code]);
    }

    /**
     * How people may record attendance at this branch.
     *
     * Every setting here is three-valued — yes, no, or inherit — because a
     * warehouse and a head office rarely want the same strictness but neither
     * wants to restate every choice the company already made.
     */
    public function updateAttendanceMethod(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $branchId = self::existing($request, $tenantId);
        $branch = Branches::find($branchId, $tenantId) ?? [];

        $methods = $this->methods($request);
        $radius = Value::int(
            $request->input('gps_radius_meters'),
            Value::int($branch['gps_radius_meters'] ?? null, 100),
        );

        if ($radius < 10 || $radius > 5000) {
            throw new ApiFailure('gps_radius_meters must be between 10 and 5000', 422, 'gps_radius_meters_between_10');
        }

        Branches::updateAttendanceMethods(
            $branchId, $tenantId, $methods, $radius,
            self::tristate($request, 'allow_offline_attendance', 'allow_offline_attendance_true_false'),
        );

        if ($request->has('face_match_threshold') || $request->has('face_liveness_required')) {
            $this->updateFaceSettings($request, $branchId, $tenantId);
        }

        if ($request->has('rotating_qr_enabled')) {
            $this->updateRotatingQr($request, $branchId, $tenantId, $methods, $branch);
        }

        AuditLog::record($tenantId, $adminId, 'branch.update_attendance_method', 'branch', $branchId);

        return ApiResponse::success(['message' => 'Branch attendance methods updated']);
    }

    /**
     * @return list<string>|null Null means inherit the company's methods.
     */
    private function methods(Request $request): ?array
    {
        if (! $request->has('attendance_methods')) {
            return null;
        }

        $raw = $request->input('attendance_methods');

        if ($raw === null) {
            return null;
        }

        if (! is_array($raw)) {
            throw new ApiFailure('attendance_methods must be an array or null', 422, 'attendance_methods_array_null');
        }

        if ($raw === []) {
            // An empty list would mean nobody can record attendance at all,
            // which is never what somebody meant to say.
            throw new ApiFailure(
                'attendance_methods cannot be empty. Use null to inherit company settings.',
                400,
                'attendance_methods_cannot_empty_null',
            );
        }

        $methods = [];

        foreach ($raw as $method) {
            $name = Value::string($method);

            if (! in_array($name, AttendanceMethod::ALLOWED, true)) {
                throw new ApiFailure('Invalid attendance method: '.$name, 422, 'invalid_attendance_method');
            }

            $methods[] = $name;
        }

        return array_values(array_unique($methods));
    }

    private function updateFaceSettings(Request $request, int $branchId, int $tenantId): void
    {
        $threshold = $request->input('face_match_threshold');

        if ($threshold !== null) {
            $threshold = Value::float($threshold);

            if ($threshold < 0.3 || $threshold > 0.95) {
                throw new ApiFailure(
                    'face_match_threshold must be between 0.3 and 0.95',
                    422,
                    'face_match_threshold_range',
                );
            }
        }

        Branches::updateFaceSettings(
            $branchId, $tenantId,
            $threshold,
            self::tristate($request, 'face_liveness_required', 'face_liveness_required_bool'),
        );
    }

    /**
     * @param  list<string>|null  $methods
     * @param  array<string, mixed>  $branch
     */
    private function updateRotatingQr(Request $request, int $branchId, int $tenantId, ?array $methods, array $branch): void
    {
        $rotating = filter_var($request->input('rotating_qr_enabled'), FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);

        if ($rotating === null) {
            throw new ApiFailure('rotating_qr_enabled must be true or false', 422, 'rotating_qr_enabled_bool');
        }

        // Refusing to turn it on for a branch that is not on qr_gps is
        // deliberate: the flag does nothing there, and a switch that silently
        // does nothing is worse than one that explains itself.
        if ($rotating) {
            $effective = $methods ?? AttendanceMethod::decode(
                DB::table('tenants')->where('id', $tenantId)->value('attendance_methods')
            );

            if (! in_array('qr_gps', $effective, true)) {
                throw new ApiFailure(
                    'Rotating QR only applies to the qr_gps method; enable qr_gps for this branch first.',
                    422,
                    'rotating_qr_requires_qr_gps',
                );
            }
        }

        unset($branch);

        Branches::updateRotatingQr($branchId, $tenantId, $rotating);
    }

    /**
     * A switch that may also be left unset, meaning "inherit".
     */
    private static function tristate(Request $request, string $field, string $errorCode): ?bool
    {
        if (! $request->has($field)) {
            return null;
        }

        $raw = $request->input($field);

        if ($raw === null) {
            return null;
        }

        $value = filter_var($raw, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);

        if ($value === null) {
            throw new ApiFailure("{$field} must be true, false, or null", 422, $errorCode);
        }

        return $value;
    }

    public static function existing(Request $request, int $tenantId): int
    {
        $branchId = Value::int($request->input('branch_id'));

        if ($branchId <= 0 || Branches::find($branchId, $tenantId) === null) {
            throw new ApiFailure('Branch not found', 404, 'not_found');
        }

        return $branchId;
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
