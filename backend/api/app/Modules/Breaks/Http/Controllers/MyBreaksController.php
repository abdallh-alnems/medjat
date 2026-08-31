<?php

declare(strict_types=1);

namespace App\Modules\Breaks\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Modules\Breaks\Domain\BreakRequests;
use App\Modules\Breaks\Services\RecordBreakRequest;
use App\Modules\Notifications\Domain\ManagerAlert;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Ports of api/app/breaks/{request,my_list,cancel,respond_postpone}.php.
 *
 * What an employee can do with their own permission requests. Everything is
 * scoped to the token holder, and only an undecided request can be withdrawn.
 */
final class MyBreaksController
{
    public function __construct(
        private readonly BreakRequests $breaks,
        private readonly RecordBreakRequest $record,
        private readonly ManagerAlert $alert,
    ) {}

    public function request(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $created = $this->record->execute($request->all(), $employee->id, $tenantId);

        $this->alert->notify(
            $tenantId,
            // Not 'break': the notification type is a closed vocabulary that
            // has no such value, so the original's inserts were rejected and
            // swallowed by their own error handler — these alerts never
            // reached anybody. A permission is time away from work.
            'leave',
            'طلب إذن/استراحة جديد',
            'New break request',
            "طلب إذن جديد من {$employee->name} بتاريخ {$created['date']} ({$created['start_time']}–{$created['end_time']})",
            "New break request from {$employee->name} on {$created['date']}",
            $employee->id,
            ['break_id' => (string) $created['id'], 'employee_id' => (string) $employee->id],
        );

        return ApiResponse::success(['break_id' => $created['id'], 'message' => 'Break request submitted']);
    }

    public function index(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        // Swept before listing, so a request whose window has closed never
        // appears as still awaiting a decision.
        $this->breaks->expirePastPending($tenantId, $employee->id);

        $status = Value::string($request->query('status'));
        $status = in_array($status, BreakRequests::STATUSES, true) ? $status : null;

        return ApiResponse::success([
            'breaks' => $this->breaks->forEmployee($employee->id, $tenantId, $status),
        ]);
    }

    public function cancel(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $breakRequest = $this->owned($request, $employee, $tenantId);

        if (Value::string($breakRequest['status'] ?? null) !== 'pending') {
            throw new ApiFailure(__('messages.processed_request_not_cancellable'), 409, 'not_pending');
        }

        $this->breaks->cancel(Value::int($breakRequest['id'] ?? null), $employee->id, $tenantId);

        return ApiResponse::success(['message' => 'Break request cancelled']);
    }

    /**
     * The employee's answer to a manager's suggested alternative time.
     *
     * Accepting adopts the suggestion and approves it in one step — the manager
     * already agreed to that slot by offering it, so asking them again would be
     * a round trip nobody needs.
     */
    public function respondToPostpone(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $action = Value::string($request->input('action'));

        if (! in_array($action, ['accept', 'reject'], true)) {
            throw new ApiFailure('action must be accept or reject', 422, 'invalid_action');
        }

        $breakRequest = $this->owned($request, $employee, $tenantId);
        $id = Value::int($breakRequest['id'] ?? null);

        if (Value::string($breakRequest['status'] ?? null) !== 'postponed') {
            throw new ApiFailure(__('messages.no_alternative_time'), 409, 'not_postponed');
        }

        if ($action === 'reject') {
            if (! $this->breaks->rejectPostpone($id, $employee->id, $tenantId)) {
                throw new ApiFailure(__('messages.alternative_time_reject_failed'), 409, 'reject_failed');
            }

            return ApiResponse::success(['message' => 'Suggested time rejected', 'status' => 'cancelled']);
        }

        $date = Value::string($breakRequest['suggested_date'] ?? null);
        $start = Value::string($breakRequest['suggested_start_time'] ?? null);
        $end = Value::string($breakRequest['suggested_end_time'] ?? null);

        if ($date === '' || $start === '' || $end === '') {
            throw new ApiFailure(__('messages.no_complete_alternative_time'), 422, 'no_suggestion');
        }

        if (BreakRequests::windowHasPassed($tenantId, $date, $end)) {
            throw new ApiFailure(__('messages.alternative_window_passed'), 422, 'break_window_passed');
        }

        $duration = RecordBreakRequest::minutesBetween($date, $start, $end);

        if (! $this->breaks->acceptPostpone($id, $employee->id, $tenantId, $duration)) {
            throw new ApiFailure(__('messages.alternative_time_accept_failed'), 409, 'accept_failed');
        }

        return ApiResponse::success(['message' => 'Suggested time accepted', 'status' => 'approved']);
    }

    /**
     * @return array<string, mixed>
     */
    private function owned(Request $request, Employee $employee, int $tenantId): array
    {
        $id = Value::int($request->input('break_id'));
        $breakRequest = $id > 0 ? $this->breaks->find($id, $tenantId) : null;

        // Somebody else's request is reported as missing rather than forbidden:
        // from this employee's point of view it does not exist.
        if ($breakRequest === null || Value::int($breakRequest['employee_id'] ?? null) !== $employee->id) {
            throw new ApiFailure(__('messages.request_not_found'), 404, 'not_found');
        }

        return $breakRequest;
    }

    private static function employee(Request $request): Employee
    {
        $employee = $request->attributes->get('employee');

        if (! $employee instanceof Employee) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        return $employee;
    }
}
