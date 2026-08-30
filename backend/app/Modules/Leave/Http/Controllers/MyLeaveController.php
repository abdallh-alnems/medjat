<?php

declare(strict_types=1);

namespace App\Modules\Leave\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Employee;
use App\Modules\Leave\Domain\LeaveBalanceCalculator;
use App\Modules\Leave\Domain\LeaveRequests;
use App\Modules\Leave\Services\ApplyForLeaveAction;
use App\Shared\Approvals\ApprovalRouter;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Ports of api/app/leaves/{apply,my_leaves,my_balance,cancel,update}.php.
 *
 * What an employee can do with their own leave. Everything here is scoped to
 * the person holding the token — never to an id in the request — and only
 * requests nobody has decided yet can be changed or withdrawn.
 */
final class MyLeaveController
{
    public function __construct(
        private readonly LeaveRequests $leaves,
        private readonly LeaveBalanceCalculator $balances,
        private readonly ApplyForLeaveAction $apply,
        private readonly ApprovalRouter $approvals,
    ) {}

    public function apply(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        return ApiResponse::success($this->apply->execute($request->all(), $employee, $tenantId));
    }

    public function index(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $status = Value::string($request->query('status'));
        $status = in_array($status, ['pending', 'approved', 'rejected'], true) ? $status : null;

        return ApiResponse::success([
            'items' => $this->leaves->forEmployee($employee->id, $tenantId, $status),
        ]);
    }

    public function balance(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $year = Value::int($request->query('year')) ?: (int) substr(TenantClock::date($tenantId), 0, 4);

        return ApiResponse::success($this->balances->forYear($employee->id, $tenantId, $year));
    }

    public function cancel(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $leaveId = self::leaveId($request);

        if ($this->leaves->ownedPending($leaveId, $employee->id, $tenantId) === null) {
            throw new ApiFailure('لا يمكن إلغاء هذا الطلب', 409, 'leave_not_cancellable');
        }

        // The chain goes first: dropping the leave while an approval request
        // still points at it leaves an approver holding a decision about
        // something that no longer exists.
        $this->approvals->cancelFor($tenantId, 'leave', $leaveId);
        $this->leaves->withdrawOwn($leaveId, $employee->id, $tenantId);

        return ApiResponse::success(['message' => 'Leave request cancelled']);
    }

    public function update(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $leaveId = self::leaveId($request);

        $type = Value::string($request->input('type'));
        $start = Value::string($request->input('start_date') ?? $request->input('date'));
        $end = Value::string($request->input('end_date')) ?: $start;
        $reason = Value::nullableString($request->input('reason'));

        if (! in_array($type, LeaveRequests::TYPES, true)) {
            throw new ApiFailure('Invalid type', 422, 'invalid_type');
        }
        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $start) !== 1 || preg_match('/^\d{4}-\d{2}-\d{2}$/', $end) !== 1) {
            throw new ApiFailure('Invalid date', 422, 'invalid_date');
        }
        if ($end < $start) {
            throw new ApiFailure('تاريخ النهاية قبل تاريخ البداية', 422, 'invalid_date_range');
        }
        if ($start < TenantClock::date($tenantId)) {
            throw new ApiFailure('لا يمكن طلب إجازة بتاريخ ماضٍ', 422, 'leave_past_date');
        }

        if ($this->leaves->ownedPending($leaveId, $employee->id, $tenantId) === null) {
            throw new ApiFailure('لا يمكن تعديل هذا الطلب', 409, 'leave_not_editable');
        }

        // Excluding this request from the overlap check: a request always
        // overlaps itself, and editing it must not be blocked by that.
        if ($this->leaves->overlaps($employee->id, $tenantId, $start, $end, $leaveId)) {
            throw new ApiFailure('يوجد تداخل مع إجازة قائمة في هذه الفترة', 409, 'leave_overlap');
        }

        if ($type === 'annual') {
            $year = (int) substr($start, 0, 4);
            $remaining = Value::int($this->balances->forYear($employee->id, $tenantId, $year)['remaining_days']);
            $requested = LeaveRequests::days($start, $end);

            if ($requested > $remaining) {
                throw new ApiFailure(
                    "رصيد إجازتك السنوية لا يكفي (المتبقي {$remaining} يوم، والطلب {$requested} يوم)",
                    422,
                    'leave_balance_insufficient',
                    ['remaining' => $remaining, 'days' => $requested],
                );
            }
        }

        $this->leaves->amendOwn($leaveId, $employee->id, $tenantId, $type, $start, $end, $reason);

        return ApiResponse::success(['message' => 'Leave request updated']);
    }

    private static function employee(Request $request): Employee
    {
        $employee = $request->attributes->get('employee');

        if (! $employee instanceof Employee) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $employee;
    }

    private static function leaveId(Request $request): int
    {
        $leaveId = Value::int($request->input('leave_id')) ?: Value::int($request->query('id'));

        if ($leaveId <= 0) {
            throw new ApiFailure('leave_id is required', 422, 'leave_id_required');
        }

        return $leaveId;
    }
}
