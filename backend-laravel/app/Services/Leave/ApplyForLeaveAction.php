<?php

declare(strict_types=1);

namespace App\Services\Leave;

use App\Domain\Approvals\ApprovalRouter;
use App\Domain\Leave\LeaveBalanceCalculator;
use App\Domain\Leave\LeaveRequests;
use App\Domain\Notifications\ManagerAlert;
use App\Domain\Time\TenantClock;
use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Support\Value;

/**
 * An employee asking for time off.
 *
 * The four refusals here are all about catching a problem while it is still
 * cheap: a request in the past, one that clashes with leave they already have,
 * one beyond their remaining balance, and a queue of requests nobody has got to
 * yet. Each of them would otherwise surface as a manager's problem days later.
 */
final class ApplyForLeaveAction
{
    private const TYPE_LABELS_AR = [
        'annual' => 'سنوية',
        'sick' => 'مرضية',
        'personal' => 'شخصية',
        'unpaid' => 'بدون راتب',
    ];

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
    public function execute(array $input, Employee $employee, int $tenantId): array
    {
        $type = Value::string($input['type'] ?? null);

        if (! in_array($type, LeaveRequests::TYPES, true)) {
            throw new ApiFailure('Invalid type', 422, 'invalid_type');
        }

        $date = Value::string($input['date'] ?? null);
        $start = Value::string($input['start_date'] ?? null) ?: $date;
        $end = Value::string($input['end_date'] ?? null) ?: $start;

        if ($start === '') {
            throw new ApiFailure('date is required', 422, 'date_required');
        }

        $employeeId = $employee->id;

        if ($this->leaves->pendingCount($employeeId, $tenantId) >= LeaveRequests::PENDING_LIMIT) {
            throw new ApiFailure('لا يمكنك تقديم أكثر من طلبين قيد المراجعة', 422, 'leave_pending_limit');
        }

        // Against the company's today, not the server's: a request filed at
        // 01:00 in Cairo must not be judged against a UTC date that has not
        // turned over yet.
        if ($start < TenantClock::date($tenantId)) {
            throw new ApiFailure('لا يمكن طلب إجازة بتاريخ ماضٍ', 422, 'leave_past_date');
        }

        if ($this->leaves->overlaps($employeeId, $tenantId, $start, $end)) {
            throw new ApiFailure('يوجد تداخل مع إجازة قائمة في هذه الفترة', 409, 'leave_overlap');
        }

        if ($type === 'annual') {
            $this->assertBalanceCovers($employeeId, $tenantId, $start, $end);
        }

        $leaveId = $this->leaves->open($employeeId, $tenantId, $type, $start, $end, Value::nullableString($input['reason'] ?? null));

        $this->approvals->route(
            $tenantId, 'leave', $leaveId,
            branchId: $employee->branch_id,
            byEmployeeId: $employeeId,
        );

        $typeAr = self::TYPE_LABELS_AR[$type];

        $this->alert->notify(
            $tenantId,
            'leave',
            'طلب إجازة جديد',
            'New Leave Request',
            "طلب إجازة جديدة من {$employee->name} (إجازة {$typeAr})",
            "New leave request from {$employee->name} ({$type})",
            $employeeId,
            ['leave_id' => (string) $leaveId, 'employee_id' => (string) $employeeId, 'type' => $type],
        );

        return ['leave_id' => $leaveId, 'message' => 'Leave request submitted'];
    }

    private function assertBalanceCovers(int $employeeId, int $tenantId, string $start, string $end): void
    {
        $year = (int) substr($start, 0, 4);
        $remaining = Value::int($this->balances->forYear($employeeId, $tenantId, $year)['remaining_days']);
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
}
