<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Attendance;
use App\Models\Branch;
use App\Models\Employee;
use App\Modules\Attendance\Domain\AttendanceMethod;
use App\Modules\Attendance\Domain\NetworkVerifier;
use App\Modules\Attendance\Domain\WebAccessPolicy;
use App\Modules\Auth\Services\WebSessionService;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/attendance/web_status.php.
 *
 * What the browser page needs to render truthfully. It reports the employee's
 * state for today across *every* channel, not just the browser: somebody who
 * checked in on their phone this morning must see "checked in" here, or the page
 * would cheerfully offer them a second check-in for the same day.
 */
final class WebStatusController
{
    public function __invoke(Request $request): JsonResponse
    {
        $employee = $request->attributes->get('employee');
        if (! $employee instanceof Employee) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));

        WebSessionService::enforcePerEmployeeLimit($employee->id);

        if (! WebAccessPolicy::isAllowed($employee, $tenantId)) {
            WebAccessPolicy::refuse($tenantId, $employee->id, 'web_not_permitted');
        }

        $now = TenantClock::now($tenantId);
        $today = $now->format('Y-m-d');
        $row = Attendance::forDay($employee->id, $tenantId, $today);

        // The punch's branch when there is one, else the employee's posting.
        $branchId = $row === null ? $employee->branch_id : ($row->branch_id ?? $employee->branch_id);
        $branch = $branchId === null
            ? null
            : Branch::query()->forTenant($tenantId)->whereKey($branchId)->first();

        // The page sends no method, so the punch resolves as gps_only. An
        // employee whose methods exclude it is refused the moment they press the
        // button — with a message written for a phone that can scan, which is
        // the one thing this page cannot do. Better to say so up front than to
        // offer a button guaranteed to fail.
        $canPunch = in_array('gps_only', AttendanceMethod::resolveFor($employee, $tenantId), true);

        return ApiResponse::success([
            'state' => $this->state($row),
            'check_in_at' => $row?->check_in_time,
            'check_out_at' => $row?->check_out_time,
            'check_in_origin' => $row?->getAttribute('check_in_origin'),
            'check_out_origin' => $row?->getAttribute('check_out_origin'),
            'branch' => $branch === null ? null : [
                'id' => $branch->id,
                'name' => $branch->name,
                'latitude' => $branch->latitude,
                'longitude' => $branch->longitude,
                'gps_radius_meters' => $branch->radiusMetres(),
            ],
            'photo_required' => WebAccessPolicy::photoRequired($tenantId),
            // Answered by the same helper the punch path calls, never by a
            // second query written here. The two used to disagree — this
            // endpoint reported a control off the mere existence of a row while
            // the punch path applied nothing — and the page spent that whole
            // time claiming a control that was not there.
            'network_constraint' => $branch === null ? 'none' : NetworkVerifier::browserConstraint($branch),
            'can_punch' => $canPunch,
            // A code rather than a sentence, so each client localises it.
            'blocked_reason' => $canPunch ? null : 'gps_only_not_enabled',
            // Sent so the interface never renders the device's own clock. A
            // browser's clock is user-editable with no permission prompt at all,
            // which makes it a weaker input than anything the mobile app deals
            // with.
            'server_time' => $now->format('Y-m-d\TH:i:sP'),
        ]);
    }

    private function state(?Attendance $row): string
    {
        if ($row === null || $row->check_in_time === null || $row->check_in_time === '') {
            return 'not_checked_in';
        }

        return $row->check_out_time === null || $row->check_out_time === ''
            ? 'checked_in'
            : 'checked_out';
    }
}
