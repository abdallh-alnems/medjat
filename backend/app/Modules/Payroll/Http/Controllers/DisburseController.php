<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Notifications\Domain\Notifier;
use App\Modules\Payroll\Domain\PayrollCache;
use App\Modules\Payroll\Domain\PayrollLedger;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/payroll/disburse.php and disburse_all.php.
 *
 * One button that walks generate → approve → pay. The employee may have no slip
 * at all, a draft, or an approved one, and the screen should not make the user
 * work out which. Already-paid is left alone, so pressing it twice pays nobody
 * twice.
 */
final class DisburseController
{
    public function __construct(
        private readonly PayrollLedger $ledger,
        private readonly Notifier $notifier,
    ) {}

    public function one(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $adminId = $admin->id;
        $employeeId = Value::int($request->input('employee_id'));

        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'employee_id_required');
        }

        $month = Value::string($request->input('month'), '') ?: substr(TenantClock::date($tenantId), 0, 7);
        $paidAt = PaidAt::fromRequest($request);

        $result = $this->ledger->disburse($employeeId, $month, $tenantId, $adminId, $paidAt);

        AuditLog::record($tenantId, $adminId, 'payroll.disburse', 'payroll', $result['payroll_id'], [
            'employee_id' => $employeeId,
            'month' => $month,
            'result' => $result['result'],
        ]);

        PayrollCache::invalidate($tenantId);

        // Only a real transition is announced. Telling somebody their salary
        // was paid because a button was pressed twice is worse than silence.
        if ($result['result'] === 'paid') {
            $this->announce($tenantId, $employeeId, $month);
        }

        return ApiResponse::success([
            'result' => $result['result'],
            'payroll_id' => $result['payroll_id'],
            'message' => 'Salary disbursed',
        ]);
    }

    public function all(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $adminId = $admin->id;

        $month = Value::string($request->input('month'), '') ?: substr(TenantClock::date($tenantId), 0, 7);
        $branchId = Value::int($request->input('branch_id')) ?: null;
        $paidAt = PaidAt::fromRequest($request);

        // The same scope the overview and generate use, so a branch filter on
        // screen pays exactly the rows the user is looking at.
        $employees = DB::table('employees')
            ->where('tenant_id', $tenantId)->where('status', 'active')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('branch_id', $branchId))
            ->pluck('id');

        $paid = [];
        $alreadyPaid = 0;

        foreach ($employees as $id) {
            $employeeId = Value::int($id);
            $result = $this->ledger->disburse($employeeId, $month, $tenantId, $adminId, $paidAt);

            if ($result['result'] === 'paid') {
                $paid[] = $employeeId;
            } elseif ($result['result'] === 'already_paid') {
                $alreadyPaid++;
            }
        }

        AuditLog::record($tenantId, $adminId, 'payroll.disburse_all', 'payroll', null, [
            'month' => $month,
            'branch_id' => $branchId,
            'paid_count' => count($paid),
            'already_paid' => $alreadyPaid,
        ]);

        PayrollCache::invalidate($tenantId);

        foreach ($paid as $employeeId) {
            $this->announce($tenantId, $employeeId, $month);
        }

        return ApiResponse::success([
            'paid_count' => count($paid),
            'already_paid' => $alreadyPaid,
            'total' => $employees->count(),
            'message' => 'Payroll disbursed',
        ]);
    }

    private function announce(int $tenantId, int $employeeId, string $month): void
    {
        $this->notifier->notifyEmployee(
            $tenantId,
            $employeeId,
            'payroll',
            'Salary paid',
            'تم دفع راتبك',
            "Your salary for {$month} has been paid.",
            "تم تأكيد دفع راتب شهر {$month}.",
            ['type' => 'payroll_paid', 'month' => $month],
        );
    }
}
