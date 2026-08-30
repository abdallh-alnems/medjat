<?php

declare(strict_types=1);

namespace App\Modules\Loans\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Loans\Domain\Loans;
use App\Modules\Notifications\Domain\Notifier;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/loans/{list,get,create,approve,cancel}.php.
 *
 * Loans and salary advances from the management side. Approving one writes its
 * whole repayment schedule; cancelling a running one drops what is still
 * unpaid and leaves what was already deducted alone.
 */
final class LoanController
{
    public function __construct(private readonly Notifier $notifier) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        return ApiResponse::success([
            'items' => Loans::forTenant(
                $tenantId,
                Value::string($request->query('status')) ?: null,
                Value::int($request->query('employee_id')) ?: null,
            ),
        ]);
    }

    public function show(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $id = Value::int($request->query('id'));
        $loan = $id > 0 ? Loans::find($id, $tenantId) : null;

        if ($loan === null) {
            throw new ApiFailure('Loan not found', 404, 'not_found');
        }

        $loan['installments'] = Loans::installments($id, $tenantId);

        return ApiResponse::success(['loan' => $loan]);
    }

    public function create(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        $employeeId = Value::int($request->input('employee_id'));
        $type = Value::string($request->input('type'), 'loan') ?: 'loan';
        $totalAmount = Value::float($request->input('total_amount'));
        $installments = Value::int($request->input('installments_count'));
        $startMonth = Value::string($request->input('start_month')) ?: substr(TenantClock::date($tenantId), 0, 7);

        if (! in_array($type, Loans::TYPES, true)) {
            throw new ApiFailure('Invalid type', 422, 'invalid_type');
        }
        if ($totalAmount < 0.01) {
            throw new ApiFailure('total_amount must be greater than zero', 422, 'invalid_total_amount');
        }
        if ($installments < 1) {
            throw new ApiFailure('installments_count must be at least 1', 422, 'installments_count_at_least_1');
        }
        if (preg_match('/^\d{4}-\d{2}$/', $startMonth) !== 1) {
            throw new ApiFailure('start_month must be in YYYY-MM format', 422, 'start_month_yyyy_mm_format');
        }

        $exists = DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)->exists();

        if (! $exists) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        $installmentAmount = round($totalAmount / $installments, 2);

        $id = Loans::create(
            $tenantId, $employeeId, $type, $totalAmount, $installmentAmount,
            $installments, $startMonth, Value::nullableString($request->input('reason')), $adminId,
        );

        AuditLog::record($tenantId, $adminId, 'loan.create', 'loan', $id, [
            'type' => $type,
            'total_amount' => $totalAmount,
            'installments' => $installments,
        ]);

        return ApiResponse::success([
            'id' => $id,
            'installment_amount' => $installmentAmount,
            'message' => 'Loan created',
        ]);
    }

    public function approve(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $loan] = $this->target($request, $tenantId);

        if (Value::string($loan['status'] ?? null) !== 'pending') {
            throw new ApiFailure('Only pending loans can be approved', 409, 'only_pending_loans_can_approved');
        }

        Loans::approve($id, $tenantId, $adminId);

        AuditLog::record($tenantId, $adminId, 'loan.approve', 'loan', $id);

        $isAdvance = Value::string($loan['type'] ?? null, 'loan') === 'advance';

        $this->tell(
            $tenantId, $loan, $id, 'approve',
            $isAdvance ? 'Advance Approved' : 'Loan Approved',
            $isAdvance ? 'تمت الموافقة على السلفة' : 'تمت الموافقة على القرض',
            'Your request has been approved and will be deducted in installments.',
            $isAdvance
                ? 'تمت الموافقة على طلب السلفة وسيتم خصمها على أقساط.'
                : 'تمت الموافقة على القرض وسيتم خصمه على أقساط.',
        );

        return ApiResponse::success(['message' => 'Loan approved and installment schedule generated']);
    }

    /**
     * One button for two different acts.
     *
     * A request nobody agreed to is refused; one already running is stopped.
     * The employee's history should show which of the two happened, so they
     * are recorded as different statuses and read differently to them.
     */
    public function cancel(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $loan] = $this->target($request, $tenantId);

        $wasPending = Value::string($loan['status'] ?? null) === 'pending';

        $done = $wasPending ? Loans::reject($id, $tenantId) : Loans::cancel($id, $tenantId);

        if (! $done) {
            throw new ApiFailure(
                'Loan cannot be cancelled in its current state',
                409,
                'loan_cannot_cancelled_its_current',
            );
        }

        AuditLog::record($tenantId, $adminId, $wasPending ? 'loan.reject' : 'loan.cancel', 'loan', $id);

        $isAdvance = Value::string($loan['type'] ?? null, 'loan') === 'advance';
        $noun = $isAdvance ? 'السلفة' : 'القرض';

        $this->tell(
            $tenantId, $loan, $id, $wasPending ? 'reject' : 'cancel',
            $wasPending
                ? ($isAdvance ? 'Advance Request Rejected' : 'Loan Request Rejected')
                : ($isAdvance ? 'Advance Cancelled' : 'Loan Cancelled'),
            $wasPending ? "تم رفض طلب {$noun}" : "تم إلغاء {$noun}",
            $wasPending
                ? 'Your request has been rejected.'
                : 'It has been cancelled and remaining installments stopped.',
            $wasPending
                ? "تم رفض طلب {$noun} الخاص بك."
                : "تم إلغاء {$noun} وإيقاف خصم الأقساط المتبقية.",
        );

        return ApiResponse::success(['message' => $wasPending ? 'Loan rejected' : 'Loan cancelled']);
    }

    /**
     * @param  array<string, mixed>  $loan
     */
    private function tell(
        int $tenantId,
        array $loan,
        int $id,
        string $action,
        string $titleEn,
        string $titleAr,
        string $bodyEn,
        string $bodyAr,
    ): void {
        $this->notifier->notifyEmployee(
            $tenantId,
            Value::int($loan['employee_id'] ?? null),
            'payroll',
            $titleEn, $titleAr, $bodyEn, $bodyAr,
            [
                'loan_id' => (string) $id,
                'action' => $action,
                'type' => Value::string($loan['type'] ?? null, 'loan'),
            ],
        );
    }

    /**
     * @return array{0: int, 1: array<string, mixed>}
     */
    private function target(Request $request, int $tenantId): array
    {
        $id = Value::int($request->input('id')) ?: Value::int($request->query('id'));
        $loan = $id > 0 ? Loans::find($id, $tenantId) : null;

        if ($loan === null) {
            throw new ApiFailure('Loan not found', 404, 'not_found');
        }

        return [$id, $loan];
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
