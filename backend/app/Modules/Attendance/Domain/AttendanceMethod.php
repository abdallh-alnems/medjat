<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Domain;

use App\Models\Employee;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * Which ways this employee is allowed to record attendance.
 *
 * Resolution order is employee → category (union) → branch → company, first
 * non-empty wins. The union at the category level matches how a person with two
 * roles is treated everywhere else in the product: holding either one is enough.
 */
final class AttendanceMethod
{
    /**
     * @var list<string>
     */
    public const ALLOWED = [
        'qr_gps', 'gps_only', 'face_selfie', 'photo_gps', 'wifi_gps',
        'crew_gps', 'device', 'manual', 'kiosk',
    ];

    /**
     * Methods an employee can use to record their own attendance from a phone or
     * a browser, as opposed to ones recorded for them ('manual'), by a terminal
     * ('device') or by a shared tablet ('kiosk').
     *
     * One list rather than one per endpoint: a method added to check-in and not
     * to check-out is enforced on arrival and unenforced on departure, which is
     * how a control ends up half-applied.
     *
     * @var list<string>
     */
    public const SELF_SERVICE = ['qr_gps', 'gps_only', 'face_selfie', 'photo_gps', 'wifi_gps'];

    /**
     * Companies that configure nothing get QR plus geofence — the strictest of
     * the simple options, so the default is safe rather than convenient.
     *
     * @var list<string>
     */
    private const FALLBACK = ['qr_gps'];

    /**
     * @return list<string>
     */
    public static function resolveFor(Employee $employee, int $tenantId): array
    {
        $own = self::decode($employee->getAttribute('attendance_methods'));
        if ($own !== []) {
            return $own;
        }

        $categories = self::categoryUnion($employee->id, $tenantId);
        if ($categories !== []) {
            return $categories;
        }

        if ($employee->branch_id !== null) {
            $branch = self::decode(
                DB::table('branches')->where('id', $employee->branch_id)
                    ->where('tenant_id', $tenantId)->value('attendance_methods')
            );
            if ($branch !== []) {
                return $branch;
            }
        }

        $tenant = self::decode(DB::table('tenants')->where('id', $tenantId)->value('attendance_methods'));

        return $tenant !== [] ? $tenant : self::FALLBACK;
    }

    /**
     * Union across the employee's active categories that set an override.
     *
     * @return list<string>
     */
    private static function categoryUnion(int $employeeId, int $tenantId): array
    {
        $rows = DB::table('employee_categories as ec')
            ->join('employee_category_assignments as eca', function (JoinClause $join): void {
                $join->on('eca.category_id', '=', 'ec.id')
                    ->on('eca.tenant_id', '=', 'ec.tenant_id');
            })
            ->where('eca.employee_id', $employeeId)
            ->where('eca.tenant_id', $tenantId)
            ->where('ec.is_active', 1)
            ->whereNotNull('ec.attendance_methods')
            ->pluck('ec.attendance_methods');

        $union = [];
        foreach ($rows as $row) {
            foreach (self::decode($row) as $method) {
                $union[$method] = true;
            }
        }

        return array_keys($union);
    }

    /**
     * A JSON column into a clean list. Unknown values are dropped rather than
     * carried: a typo in a hand-edited row must not become a method nothing
     * enforces.
     *
     * @return list<string>
     */
    public static function decode(mixed $json): array
    {
        if ($json === null || $json === '') {
            return [];
        }

        $decoded = is_array($json) ? $json : json_decode(is_string($json) ? $json : '', true);

        if (! is_array($decoded)) {
            return [];
        }

        $methods = array_filter(
            $decoded,
            static fn (mixed $method): bool => is_string($method) && in_array($method, self::ALLOWED, true)
        );

        /** @var list<string> */
        return array_values(array_unique($methods));
    }

    /**
     * @param  list<string>  $methods
     */
    public static function allowsSelfService(array $methods): bool
    {
        return array_intersect($methods, self::SELF_SERVICE) !== [];
    }
}
