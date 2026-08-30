<?php

declare(strict_types=1);

namespace App\Domain\Leave;

use Illuminate\Support\Facades\DB;

/**
 * Cashing out leave days that were never taken.
 *
 * An encashment sits pending until some payroll run is approved, then it is
 * stamped with the month that paid it. Nothing here decides *whether* to pay —
 * that is the approval's job; this only records that it happened.
 */
final class LeaveEncashment
{
    /**
     * @param  list<int>  $employeeIds
     */
    public function markPaid(array $employeeIds, string $month, int $tenantId): void
    {
        $employeeIds = array_values(array_unique(array_filter($employeeIds, static fn (int $id): bool => $id > 0)));

        if ($employeeIds === []) {
            return;
        }

        DB::table('leave_encashments')
            ->where('tenant_id', $tenantId)
            ->where('status', 'pending')
            ->whereIn('employee_id', $employeeIds)
            ->update(['status' => 'paid', 'payroll_month' => $month]);
    }
}
