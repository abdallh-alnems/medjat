<?php

declare(strict_types=1);

namespace App\Services\Leave;

use App\Domain\Approvals\ApprovalRouter;
use App\Domain\Leave\LeaveBalanceCalculator;
use App\Domain\Leave\LeaveRequests;
use App\Domain\Notifications\ManagerAlert;
use App\Exceptions\ApiFailure;
use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * A manager recording leave on somebody's behalf.
 *
 * Differs from an employee's own request in one substantial way: when the
 * period runs past the remaining annual balance, this can split it rather than
 * refuse it — the paid days as annual leave, the rest as unpaid. That is what
 * actually happens when somebody takes three weeks with two weeks left, and
 * recording it as one over-long annual leave would quietly overdraw the balance
 * instead.
 *
 * `on_exceed=block` is there for companies that would rather be stopped.
 */
final class RecordLeaveAction
{
    public function __construct(
        private readonly LeaveRequests $leaves,
        private readonly LeaveBalanceCalculator $balances,
        private readonly ApprovalRouter $approvals,
        private readonly ManagerAlert $alert,
    ) {}

    /**
     * @param  array<array-key, mixed>  $input
     * @return array<string, mixed>
     */
    public function execute(array $input, int $tenantId, int $adminId): array
    {
        $employeeId = Value::int($input['employee_id'] ?? null);
        $type = Value::string($input['type'] ?? null);
        $start = Value::string($input['start_date'] ?? null);
        $end = Value::string($input['end_date'] ?? null) ?: $start;
        $reason = Value::nullableString($input['reason'] ?? null);
        $autoApprove = filter_var($input['auto_approve'] ?? false, FILTER_VALIDATE_BOOLEAN);
        $onExceed = Value::string($input['on_exceed'] ?? null, 'split') ?: 'split';

        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'employee_id_required');
        }
        if (! in_array($type, LeaveRequests::TYPES, true)) {
            throw new ApiFailure('Invalid type', 422, 'invalid_type');
        }
        if ($start === '') {
            throw new ApiFailure('start_date is required', 422, 'start_date_required');
        }
        if (! in_array($onExceed, ['split', 'block'], true)) {
            throw new ApiFailure('Invalid on_exceed', 422, 'invalid_on_exceed');
        }

        $employee = DB::table('employees')
            ->where('id', $employeeId)->where('tenant_id', $tenantId)
            ->first(['id', 'name', 'branch_id']);

        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        $branchId = Value::nullableInt($employee->branch_id);
        $name = Value::string($employee->name);

        if ($this->leaves->overlaps($employeeId, $tenantId, $start, $end)) {
            throw new ApiFailure('يوجد تداخل مع إجازة قائمة في هذه الفترة', 409, 'leave_overlap');
        }

        if ($type === 'annual') {
            $year = (int) substr($start, 0, 4);
            $remaining = Value::int($this->balances->forYear($employeeId, $tenantId, $year)['remaining_days']);
            $requested = LeaveRequests::days($start, $end);

            if ($requested > $remaining) {
                if ($onExceed === 'block') {
                    throw new ApiFailure('رصيد الإجازات السنوية غير كافٍ', 422, 'balance_exceeded');
                }

                return $this->split(
                    $employeeId, $tenantId, $adminId, $branchId, $name,
                    $start, $end, $reason, $remaining, $requested, $autoApprove,
                );
            }
        }

        $leaveId = $this->leaves->open($employeeId, $tenantId, $type, $start, $end, $reason);

        if ($autoApprove) {
            $this->leaves->approve($leaveId, $tenantId, $adminId);
        } else {
            $this->approvals->route(
                $tenantId, 'leave', $leaveId,
                branchId: $branchId, byAdminId: $adminId, byEmployeeId: $employeeId,
            );
        }

        $this->announce($tenantId, $employeeId, $leaveId, $name, $type);

        return ['leave_id' => $leaveId, 'status' => $autoApprove ? 'approved' : 'pending'];
    }

    /**
     * Paid days first, then the remainder unpaid, in one transaction — half a
     * split is worse than either whole answer.
     *
     * @return array<string, mixed>
     */
    private function split(
        int $employeeId,
        int $tenantId,
        int $adminId,
        ?int $branchId,
        string $name,
        string $start,
        string $end,
        ?string $reason,
        int $paidDays,
        int $requestedDays,
        bool $autoApprove,
    ): array {
        [$paidId, $unpaidId] = DB::transaction(function () use (
            $employeeId, $tenantId, $adminId, $start, $end, $reason, $paidDays, $autoApprove
        ): array {
            $paidId = null;

            if ($paidDays > 0) {
                $paidEnd = self::shift($start, $paidDays - 1);
                $paidId = $this->leaves->open($employeeId, $tenantId, 'annual', $start, $paidEnd, $reason);

                if ($autoApprove) {
                    $this->leaves->approve($paidId, $tenantId, $adminId);
                }
            }

            $unpaidStart = self::shift($start, $paidDays);
            $unpaidId = $this->leaves->open($employeeId, $tenantId, 'unpaid', $unpaidStart, $end, $reason);

            if ($autoApprove) {
                $this->leaves->approve($unpaidId, $tenantId, $adminId);
            }

            return [$paidId, $unpaidId];
        });

        if (! $autoApprove) {
            foreach (array_filter([$paidId, $unpaidId]) as $id) {
                $this->approvals->route(
                    $tenantId, 'leave', $id,
                    branchId: $branchId, byAdminId: $adminId, byEmployeeId: $employeeId,
                );
            }
        }

        $this->announce($tenantId, $employeeId, $paidId ?? $unpaidId, $name, 'annual');

        return [
            'warning' => 'balance_exceeded',
            'paid_days' => $paidDays,
            'unpaid_days' => $requestedDays - $paidDays,
            'leaves' => [
                ['id' => $paidId, 'type' => 'annual', 'status' => $autoApprove ? 'approved' : 'pending'],
                ['id' => $unpaidId, 'type' => 'unpaid', 'status' => $autoApprove ? 'approved' : 'pending'],
            ],
        ];
    }

    private function announce(int $tenantId, int $employeeId, int $leaveId, string $name, string $type): void
    {
        $this->alert->notify(
            $tenantId,
            'leave',
            'طلب إجازة جديد',
            'New Leave Request',
            "طلب إجازة جديد من {$name} ({$type})",
            "New leave request from {$name} ({$type})",
            $employeeId,
            ['leave_id' => (string) $leaveId, 'employee_id' => (string) $employeeId, 'type' => $type],
        );
    }

    private static function shift(string $date, int $days): string
    {
        $from = strtotime($date.' + '.$days.' days');

        return $from === false ? $date : date('Y-m-d', $from);
    }
}
