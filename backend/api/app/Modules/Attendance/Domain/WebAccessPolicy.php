<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Domain;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Shared\Security\AttendanceSecurityLog;
use App\Support\Value;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * Whether this employee may use the browser attendance channel at all.
 *
 * The channel ships switched off per company: the feature was built before
 * anyone had asked for it to be on, and turning it on for everybody at once is
 * how a pilot becomes an incident.
 */
final class WebAccessPolicy
{
    public static function isAllowed(Employee $employee, int $tenantId): bool
    {
        $enabled = DB::table('tenants')->where('id', $tenantId)->value('web_attendance_enabled');

        if (Value::int($enabled) !== 1) {
            return false;
        }

        // Union-with-any across the employee's categories, matching how category
        // attendance methods already resolve — administrators should meet one
        // mental model, not two. A company that configures nothing has the
        // channel available to everyone, so the simple case needs no setup.
        $flags = DB::table('employee_categories as ec')
            ->join('employee_category_assignments as eca', function (JoinClause $join): void {
                $join->on('eca.category_id', '=', 'ec.id')
                    ->on('eca.tenant_id', '=', 'ec.tenant_id');
            })
            ->where('eca.employee_id', $employee->id)
            ->where('eca.tenant_id', $tenantId)
            ->where('ec.is_active', 1)
            ->whereNotNull('ec.web_attendance_allowed')
            ->pluck('ec.web_attendance_allowed');

        if ($flags->isEmpty()) {
            return true;
        }

        return $flags->contains(fn (mixed $flag): bool => Value::int($flag) === 1);
    }

    /** True when this company wants an image captured at each browser punch. */
    public static function photoRequired(int $tenantId): bool
    {
        $required = DB::table('tenants')->where('id', $tenantId)->value('web_attendance_photo_required');

        // Defaults to on: a company that has never chosen gets the stricter
        // behaviour, not the looser one.
        return $required === null || Value::int($required) === 1;
    }

    /**
     * Refuses the request and records why.
     *
     * Every refusal is written to attendance_security_logs. A blocked attempt
     * that leaves no trace is indistinguishable from one that never happened,
     * which is exactly the state this table was created to end.
     */
    public static function refuse(
        int $tenantId,
        int $employeeId,
        string $reason,
        ?int $branchId = null,
        ?float $lat = null,
        ?float $lng = null,
    ): never {
        AttendanceSecurityLog::record($tenantId, $employeeId, $branchId, $reason, 'blocked', $lat, $lng);

        throw new ApiFailure(
            'تسجيل الحضور من المتصفح غير متاح لحسابك',
            403,
            strtoupper($reason),
        );
    }
}
