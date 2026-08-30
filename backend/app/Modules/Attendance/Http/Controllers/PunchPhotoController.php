<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\Middleware\RequireBranchAccess;
use App\Models\Admin;
use App\Support\Value;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\Response;

/**
 * Port of api/app/attendance/punch_photo.php.
 *
 * Serves the image captured at a punch, to a caller allowed to review that
 * employee's attendance and to nobody else.
 *
 * The images live on a disk nginx refuses outright, so this is the only way to
 * them. Photographs of employees' faces are exactly the kind of file that must
 * not be reachable by guessing a filename, and an authenticated route is what
 * makes "who may look at this" a question the system can answer.
 */
final class PunchPhotoController
{
    public function __invoke(Request $request): Response
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $attendanceId = Value::int($request->query('attendance_id'));

        if ($attendanceId <= 0) {
            throw new ApiFailure('attendance_id is required', 422, 'missing_fields');
        }

        $which = Value::string($request->query('which'), 'check_in');
        if (! in_array($which, ['check_in', 'check_out'], true)) {
            throw new ApiFailure('which must be check_in or check_out', 422, 'invalid_which');
        }

        $row = DB::table('attendance as a')
            ->join('employees as e', function (JoinClause $join): void {
                $join->on('e.id', '=', 'a.employee_id')->on('e.tenant_id', '=', 'a.tenant_id');
            })
            ->where('a.id', $attendanceId)
            ->where('a.tenant_id', $tenantId)
            ->first(['a.check_in_photo', 'a.check_out_photo', 'a.branch_id', 'e.branch_id as employee_branch_id']);

        if ($row === null) {
            throw new ApiFailure('Attendance not found', 404);
        }

        // A branch-scoped reviewer sees only the branches they were given.
        // Judged by the punch's branch, falling back to the employee's, so a
        // punch recorded at another site is judged by where it happened.
        $branchId = Value::nullableInt($row->branch_id) ?? Value::nullableInt($row->employee_branch_id);
        if ($branchId !== null) {
            RequireBranchAccess::assert($admin, $branchId);
        }

        $stored = Value::string($which === 'check_in' ? $row->check_in_photo : $row->check_out_photo);
        if ($stored === '' || ! Storage::disk('uploads')->exists($stored)) {
            throw new ApiFailure('Photo not found', 404);
        }

        return response(Storage::disk('uploads')->get($stored), 200, [
            'Content-Type' => 'image/jpeg',
            'Content-Disposition' => 'inline; filename="punch_'.$attendanceId.'_'.$which.'.jpg"',
            'X-Content-Type-Options' => 'nosniff',
            // Private and uncached: an employee's photograph, not an asset. It
            // must not sit in a shared proxy or on a CDN edge, which is exactly
            // how the payslip leak outlived the origin being fixed.
            'Cache-Control' => 'private, no-store, max-age=0',
        ]);
    }
}
