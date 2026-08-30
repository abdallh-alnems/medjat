<?php

declare(strict_types=1);

namespace App\Http\Controllers\Payroll;

use App\Domain\Audit\AuditLog;
use App\Domain\Loans\LoanSettlement;
use App\Domain\Notifications\ManagerAlert;
use App\Domain\Notifications\Notifier;
use App\Domain\Payroll\PayrollCache;
use App\Domain\Payroll\PayrollLedger;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/payroll/approve.php and approve_bulk.php.
 *
 * Approval is the moment the figures stop moving, so it does three things in
 * order: re-freeze the slip at its full-cycle total, flip the status, then
 * settle what the frozen slip has already deducted — loan installments and any
 * leave encashment. Settling before the freeze would charge for something the
 * payslip might not end up carrying.
 */
final class ApproveController
{
    public function __construct(
        private readonly PayrollLedger $ledger,
        private readonly LoanSettlement $loans,
        private readonly Notifier $notifier,
        private readonly ManagerAlert $alert,
    ) {}

    public function one(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $adminId = $admin->id;
        $payrollId = Value::int($request->input('payroll_id'));

        if ($payrollId <= 0) {
            throw new ApiFailure('payroll_id is required', 422, 'payroll_id_required');
        }

        $approved = $this->ledger->approve($payrollId, $tenantId, $adminId);

        AuditLog::record($tenantId, $adminId, 'payroll.approve', 'payroll', $payrollId);

        if ($approved !== null) {
            $this->loans->settleMonth($approved['employee_id'], $approved['month'], $tenantId);

            $this->notifier->notifyEmployee(
                $tenantId,
                $approved['employee_id'],
                'payroll',
                'Salary approved',
                'تم اعتماد راتبك',
                "Your payslip for {$approved['month']} has been approved.",
                "تم اعتماد كشف راتبك لشهر {$approved['month']}.",
                ['type' => 'payroll_approved', 'month' => $approved['month'], 'payroll_id' => (string) $payrollId],
            );
        }

        $this->alert->notify(
            $tenantId,
            'payroll',
            'اعتماد كشف رواتب',
            'Payroll Approved',
            "تم اعتماد كشف رواتب #{$payrollId}",
            "Payroll #{$payrollId} has been approved",
            null,
            ['payroll_id' => (string) $payrollId],
        );

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['message' => 'Payroll approved']);
    }

    public function bulk(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $adminId = $admin->id;

        $ids = $request->input('ids');
        if (! is_array($ids) || $ids === []) {
            throw new ApiFailure('ids must be a non-empty array', 422, 'ids_non_empty_array');
        }

        $touched = $this->ledger->approveMany(
            array_values(array_map(static fn (mixed $id): int => Value::int($id), $ids)),
            $tenantId,
            $adminId,
        );

        // Settling per slip rather than in bulk keeps this identical to the
        // single approval path, which is the only way the two stay consistent.
        foreach ($touched as $row) {
            $this->loans->settleMonth(
                Value::int($row['employee_id'] ?? null),
                Value::string($row['month'] ?? null),
                $tenantId,
            );
        }

        AuditLog::record($tenantId, $adminId, 'payroll.approve.bulk', 'payroll', null, [
            'count' => count($touched),
            'ids' => array_map(static fn (array $row): int => Value::int($row['id'] ?? null), $touched),
        ]);

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success([
            'approved_count' => count($touched),
            'message' => 'Bulk approval completed',
        ]);
    }
}
