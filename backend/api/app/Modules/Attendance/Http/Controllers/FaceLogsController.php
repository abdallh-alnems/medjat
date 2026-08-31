<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Models\Employee;
use App\Shared\Face\FaceMatcher;
use App\Shared\Http\ApiResponse;
use App\Shared\Http\Middleware\RequireBranchAccess;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/attendance/face_logs.php.
 *
 * Two shapes. `employee` shows the recent attempts for one person, for handling
 * a dispute. `distribution` is the histogram across the company, and it is what
 * turns log_only mode into a decision: run for a fortnight, see where genuine
 * matches cluster against the rejections, then set the threshold on that
 * company's own data before switching to enforce.
 */
final class FaceLogsController
{
    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));

        return Value::string($request->input('view'), 'employee') === 'distribution'
            ? $this->distribution($request, $tenantId)
            : $this->forEmployee($request, $admin, $tenantId);
    }

    private function distribution(Request $request, int $tenantId): JsonResponse
    {
        // Clamped: an unbounded window is a table scan somebody will eventually
        // ask for by accident.
        $days = max(1, min(365, Value::int($request->input('days'), 30)));

        $rows = DB::table('face_verification_logs')
            ->where('tenant_id', $tenantId)
            ->whereNotNull('match_score')
            ->whereRaw('created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)', [$days])
            ->groupBy('bucket', 'result')
            ->orderBy('bucket')
            ->get([
                // Twentieths: fine enough to see where the two populations
                // separate, coarse enough to read as a chart.
                DB::raw('ROUND(FLOOR(match_score * 20) / 20, 2) as bucket'),
                'result',
                DB::raw('COUNT(*) as attempts'),
            ]);

        $configured = DB::table('tenants')->where('id', $tenantId)->value('face_match_threshold');

        return ApiResponse::success([
            'days' => $days,
            'threshold' => is_numeric($configured) ? (float) $configured : FaceMatcher::DEFAULT_THRESHOLD,
            'buckets' => array_values(array_map(static fn (object $row): array => [
                'score' => Value::float($row->bucket),
                'result' => $row->result,
                'attempts' => Value::int($row->attempts),
            ], $rows->all())),
        ]);
    }

    private function forEmployee(Request $request, Admin $admin, int $tenantId): JsonResponse
    {
        $employeeId = Value::int($request->input('employee_id'));
        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'missing_fields');
        }

        $employee = Employee::query()->forTenant($tenantId)->whereKey($employeeId)->first();
        if ($employee === null) {
            throw new ApiFailure(__('messages.employee_not_found'), 404);
        }

        RequireBranchAccess::assert($admin, $employee->branch_id);

        $limit = max(1, min(200, Value::int($request->input('limit'), 20)));

        $logs = DB::table('face_verification_logs')
            ->where('employee_id', $employeeId)
            ->where('tenant_id', $tenantId)
            ->orderByDesc('created_at')
            ->limit($limit)
            ->get();

        return ApiResponse::success([
            'employee_id' => $employeeId,
            'logs' => array_values(array_map(static fn (object $row): array => [
                'id' => Value::int($row->id),
                'purpose' => $row->purpose,
                'result' => $row->result,
                'accepted' => (bool) $row->accepted,
                'match_score' => Value::nullableFloat($row->match_score),
                'threshold' => Value::nullableFloat($row->threshold),
                'liveness_passed' => (bool) $row->liveness_passed,
                'challenge' => $row->challenge,
                'selfie_path' => $row->selfie_path,
                'created_at' => $row->created_at,
            ], $logs->all())),
        ]);
    }
}
