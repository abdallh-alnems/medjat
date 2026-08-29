<?php

declare(strict_types=1);

namespace App\Http\Controllers\Attendance;

use App\Domain\Crew\Crew;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Employee;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/attendance/crew_list.php.
 */
final class CrewListController
{
    public function __invoke(Request $request): JsonResponse
    {
        $employee = $request->attributes->get('employee');
        if (! $employee instanceof Employee) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $members = Crew::membersFor($employee->id, $tenantId);

        return ApiResponse::success([
            // Derived from whether anybody points at this employee, never from a
            // flag. An empty crew and "not a supervisor" are the same state by
            // construction, so the two cannot drift apart.
            'is_supervisor' => $members !== [],
            'photo_required' => Crew::photoRequired($tenantId),
            'members' => $members,
        ]);
    }
}
