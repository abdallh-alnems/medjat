<?php

declare(strict_types=1);

namespace App\Modules\Performance\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Models\Employee;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Performance\Domain\PerformanceReviews;
use App\Shared\Http\ApiResponse;
use App\Shared\Http\Middleware\RequireBranchAccess;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Ports of api/app/performance/review_{create,list,delete}.php.
 */
final class ReviewController
{
    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employee = $this->subject(Value::int($request->query('employee_id')), $tenantId, self::admin($request));

        $cycleId = Value::int($request->query('cycle_id'));

        return ApiResponse::success([
            'items' => PerformanceReviews::forEmployee(
                $employee->id, $tenantId, $cycleId > 0 ? $cycleId : null,
            ),
        ]);
    }

    public function create(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);
        $employee = $this->subject(Value::int($request->input('employee_id')), $tenantId, $admin);

        $rating = null;

        if ($request->input('rating') !== null) {
            $rating = Value::float($request->input('rating'));

            if ($rating < 0 || $rating > 5) {
                throw new ApiFailure('rating must be between 0 and 5', 422, 'rating_between_0_5');
            }
        }

        $reviewerType = Value::string($request->input('reviewer_type'), 'manager') ?: 'manager';

        if (! in_array($reviewerType, PerformanceReviews::REVIEWER_TYPES, true)) {
            throw new ApiFailure('Invalid reviewer_type', 422, 'invalid_reviewer_type');
        }

        $status = Value::string($request->input('status'), 'submitted') ?: 'submitted';

        if (! in_array($status, PerformanceReviews::STATUSES, true)) {
            throw new ApiFailure('Invalid status', 422, 'invalid_status');
        }

        $cycleId = Value::int($request->input('cycle_id'));

        if ($cycleId > 0 && ! PerformanceReviews::cycleExists($cycleId, $tenantId)) {
            throw new ApiFailure('Cycle not found', 404, 'not_found');
        }

        $id = PerformanceReviews::create($tenantId, [
            'employee_id' => $employee->id,
            'cycle_id' => $cycleId > 0 ? $cycleId : null,
            'reviewer_type' => $reviewerType,
            'rating' => $rating,
            'strengths' => $request->input('strengths'),
            'areas_for_improvement' => $request->input('areas_for_improvement'),
            'review' => $request->input('review'),
            'status' => $status,
        ], $admin->id);

        AuditLog::record($tenantId, $admin->id, 'performance_review.create', 'performance_review', $id, [
            'employee_id' => $employee->id,
            'rating' => $rating,
        ]);

        return ApiResponse::success(['id' => $id, 'message' => 'Review created'], 201);
    }

    public function delete(Request $request, int $id): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);

        $review = $id > 0 ? PerformanceReviews::find($id, $tenantId) : null;

        if ($review === null) {
            throw new ApiFailure('Review not found', 404, 'not_found');
        }

        // The branch check follows the review's subject, so a branch manager
        // cannot delete an assessment of somebody outside their branch.
        $this->subject(Value::int($review['employee_id'] ?? null), $tenantId, $admin);

        PerformanceReviews::delete($id, $tenantId);

        AuditLog::record($tenantId, $admin->id, 'performance_review.delete', 'performance_review', $id);

        return ApiResponse::success(['message' => 'Review deleted']);
    }

    private function subject(int $employeeId, int $tenantId, Admin $admin): Employee
    {
        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'employee_id_required');
        }

        $employee = Employee::query()->where('id', $employeeId)->where('tenant_id', $tenantId)->first();

        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        RequireBranchAccess::assert($admin, $employee->branch_id);

        return $employee;
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
