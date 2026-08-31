<?php

declare(strict_types=1);

namespace App\Modules\Loans\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Loans\Domain\Loans;
use App\Modules\Notifications\Domain\ManagerAlert;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Ports of api/app/loans/{request,my_list,cancel_request}.php.
 *
 * An employee asking for a salary advance. It lands as a pending advance
 * exactly as an administrator-created one does, so the existing management
 * screen lists and decides it — there is no second queue to remember to check.
 */
final class MyAdvanceController
{
    public function __construct(private readonly ManagerAlert $alert) {}

    public function request(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $totalAmount = Value::float($request->input('total_amount'));
        $installments = max(1, Value::int($request->input('installments_count'), 1));
        $thisMonth = substr(TenantClock::date($tenantId), 0, 7);
        $startMonth = Value::string($request->input('start_month')) ?: $thisMonth;

        if ($totalAmount < 0.01) {
            throw new ApiFailure('total_amount must be greater than zero', 422, 'invalid_total_amount');
        }

        if (preg_match('/^\d{4}-\d{2}$/', $startMonth) !== 1) {
            throw new ApiFailure('start_month must be in YYYY-MM format', 422, 'invalid_start_month');
        }

        // Months in this form sort lexically, so the comparison is the check.
        if ($startMonth < $thisMonth) {
            throw new ApiFailure('شهر بداية الخصم لا يمكن أن يكون في الماضي', 422, 'start_month_in_past');
        }

        if (Loans::pendingCountForEmployee($employee->id, $tenantId) >= Loans::PENDING_LIMIT) {
            throw new ApiFailure('لديك طلبات سلفة معلّقة بالفعل', 409, 'advance_pending_limit');
        }

        $id = Loans::create(
            $tenantId,
            $employee->id,
            'advance',
            $totalAmount,
            round($totalAmount / $installments, 2),
            $installments,
            $startMonth,
            Value::nullableString($request->input('reason')),
            // Requested by the employee, so there is no administrator to name.
            null,
        );

        AuditLog::record($tenantId, null, 'loan.request', 'loan', $id, [
            'type' => 'advance',
            'total_amount' => $totalAmount,
            'installments' => $installments,
            'by_employee' => $employee->id,
        ]);

        // Whole amounts read as "1,000"; decimals only when there are any.
        $amount = fmod($totalAmount, 1.0) === 0.0
            ? number_format($totalAmount, 0)
            : number_format($totalAmount, 2);

        $this->alert->notify(
            $tenantId,
            'payroll',
            'طلب سلفة جديد',
            'New advance request',
            "طلب سلفة بقيمة {$amount} من {$employee->name}",
            "Advance request of {$amount} from {$employee->name}",
            $employee->id,
            ['loan_id' => (string) $id, 'employee_id' => (string) $employee->id, 'type' => 'advance'],
        );

        return ApiResponse::success(['id' => $id, 'message' => 'Advance requested']);
    }

    public function index(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        return ApiResponse::success([
            'loans' => Loans::forTenant(
                $tenantId,
                Value::string($request->query('status')) ?: null,
                $employee->id,
            ),
        ]);
    }

    /** Withdrawing a request nobody has decided yet. */
    public function cancel(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $id = Value::int($request->input('loan_id')) ?: Value::int($request->input('id'));
        $loan = $id > 0 ? Loans::find($id, $tenantId) : null;

        // Somebody else's request is reported as missing rather than forbidden:
        // from this employee's point of view it does not exist.
        if ($loan === null || Value::int($loan['employee_id'] ?? null) !== $employee->id) {
            throw new ApiFailure('Advance not found', 404, 'not_found');
        }

        if (Value::string($loan['status'] ?? null) !== 'pending') {
            throw new ApiFailure('لا يمكن إلغاء هذا الطلب', 409, 'not_pending');
        }

        Loans::cancel($id, $tenantId);

        AuditLog::record($tenantId, null, 'loan.cancel_request', 'loan', $id, [
            'by_employee' => $employee->id,
        ]);

        return ApiResponse::success(['message' => 'Advance request cancelled']);
    }

    private static function employee(Request $request): Employee
    {
        $employee = $request->attributes->get('employee');

        if (! $employee instanceof Employee) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $employee;
    }
}
