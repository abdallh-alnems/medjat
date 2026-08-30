<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Notifications\Domain\Notifier;
use App\Modules\Payroll\Domain\ManualAdjustments;
use App\Modules\Payroll\Domain\PayrollCache;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/payroll/bulk_adjust.php.
 *
 * One bonus or deduction applied across a branch, shift or category. It fans
 * out into ordinary per-employee rows rather than inventing a group-level
 * concept, so everything downstream — the calculator, the slips, the audit
 * trail — sees exactly what it would see from a manual entry.
 *
 * The scope is a snapshot: somebody who joins the branch tomorrow is not
 * retroactively adjusted, which matches what the single-employee form does and
 * what a company means when it says "give this month's team a bonus".
 */
final class BulkAdjustController
{
    public function __construct(
        private readonly ManualAdjustments $adjustments,
        private readonly Notifier $notifier,
    ) {}

    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $adminId = $admin->id;

        $kind = Value::string($request->input('kind'));
        $scopeType = Value::string($request->input('scope_type'));
        $scopeId = Value::int($request->input('scope_id'));
        $amount = Value::float($request->input('amount'));
        $amountType = Value::string($request->input('amount_type'), 'fixed') ?: 'fixed';
        $reason = trim(Value::string($request->input('reason')));

        if (! in_array($kind, ['bonus', 'deduction'], true)) {
            throw new ApiFailure('Invalid kind', 422);
        }
        if (! in_array($scopeType, ['branch', 'shift', 'category'], true)) {
            throw new ApiFailure('Invalid scope_type', 422);
        }
        if ($scopeId <= 0) {
            throw new ApiFailure('scope_id is required', 422, 'scope_id_required');
        }
        if (! in_array($amountType, ['fixed', 'percent'], true)) {
            throw new ApiFailure('Invalid amount_type', 422);
        }
        if ($amount <= 0) {
            throw new ApiFailure('Amount must be greater than zero', 422);
        }
        if ($amountType === 'percent' && $amount > 100) {
            throw new ApiFailure('Percentage must be between 0 and 100', 422);
        }

        $employees = $this->adjustments->inScope($scopeType, $scopeId, $tenantId);

        if ($employees === []) {
            throw new ApiFailure('No employees match the selected scope', 404);
        }

        $isBonus = $kind === 'bonus';
        $isPercent = $amountType === 'percent';
        $month = substr(TenantClock::date($tenantId), 0, 7);

        $applied = 0;
        $skipped = 0;

        foreach ($employees as $employee) {
            $employeeId = Value::int($employee['id'] ?? null);

            $figure = $isPercent
                ? round(Value::float($employee['base_salary'] ?? null) * $amount / 100, 2)
                : $amount;

            // A percentage of nothing is nothing. Recording a zero line would
            // clutter the payslip with something that changes no total.
            if ($figure <= 0) {
                $skipped++;

                continue;
            }

            // The percentage basis goes into the reason so the trail explains
            // why two people on the same batch were charged different sums.
            $lineReason = $isPercent
                ? $reason.' ('.self::trimZeros($amount).'% من الأساسي)'
                : $reason;

            $this->adjustments->record($isBonus, $employeeId, $tenantId, $figure, $lineReason, $adminId, $month);
            $applied++;

            $this->notifier->notifyEmployee(
                $tenantId,
                $employeeId,
                'payroll',
                $isBonus ? 'New bonus' : 'New deduction',
                $isBonus ? 'مكافأة جديدة' : 'خصم جديد',
                $isBonus
                    ? "A bonus of {$figure} was added to your salary."
                    : "A deduction of {$figure} was applied to your salary.",
                $isBonus
                    ? "تمت إضافة مكافأة بقيمة {$figure} لراتبك."
                    : "تمت إضافة خصم بقيمة {$figure} على راتبك.",
                ['type' => $isBonus ? 'bonus_added' : 'deduction_added', 'amount' => (string) $figure, 'reason' => $lineReason],
            );
        }

        AuditLog::record($tenantId, $adminId, $kind.'.bulk', $scopeType, $scopeId, [
            'amount' => $amount,
            'amount_type' => $amountType,
            'count' => $applied,
            'skipped' => $skipped,
            'scope_type' => $scopeType,
        ]);

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success([
            'count' => $applied,
            'skipped' => $skipped,
            'message' => 'Bulk '.$kind.' applied to '.$applied.' employees',
        ]);
    }

    private static function trimZeros(float $percentage): string
    {
        return rtrim(rtrim(number_format($percentage, 2, '.', ''), '0'), '.');
    }
}
