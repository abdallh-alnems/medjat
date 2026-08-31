<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Notifications\Domain\Notifier;
use App\Modules\Payroll\Domain\BulkAdjustments;
use App\Modules\Payroll\Domain\ManualAdjustments;
use App\Modules\Payroll\Domain\PayrollCache;
use App\Modules\Payroll\Domain\PayrollLedger;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/bulk_adjustments/*.php.
 *
 * A bonus or deduction across a group, kept as a batch so it can be edited or
 * undone later without hunting for the rows it created.
 *
 * Two things it will not do. It skips anybody whose payroll for the month is
 * already frozen — a manual line cannot change an approved slip, so writing one
 * would be a row that silently does nothing. And it offers a preview, because a
 * bulk mistake is expensive and invisible until somebody reads their payslip.
 */
final class BulkAdjustmentBatchController
{
    public function __construct(
        private readonly ManualAdjustments $adjustments,
        private readonly PayrollLedger $ledger,
        private readonly Notifier $notifier,
    ) {}

    public function index(Request $request): JsonResponse
    {
        return ApiResponse::success([
            'items' => BulkAdjustments::forTenant(Value::int($request->attributes->get('tenant_id'))),
        ]);
    }

    public function show(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        [$id, $batch] = $this->target(Value::int($request->input('id')) ?: Value::int($request->query('id')), $tenantId);

        return ApiResponse::success([
            'batch' => $batch,
            'members' => BulkAdjustments::members($id, Value::string($batch['kind'] ?? null), $tenantId),
        ]);
    }

    public function create(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        $kind = Value::string($request->input('kind'));
        $scopeType = Value::string($request->input('scope_type'));
        $scopeId = Value::int($request->input('scope_id'));
        $amountType = Value::string($request->input('amount_type'), 'fixed') ?: 'fixed';
        $amount = Value::float($request->input('amount'));
        $reason = trim(Value::string($request->input('reason')));

        $this->assertShape($kind, $scopeType, $amountType, $amount, $scopeId);

        $month = Value::string($request->input('month')) ?: substr(TenantClock::date($tenantId), 0, 7);

        if (preg_match('/^\d{4}-\d{2}$/', $month) !== 1) {
            throw new ApiFailure('Invalid month format (expected YYYY-MM)', 422, 'invalid_month');
        }

        $scopeName = $this->scopeName($scopeType, $scopeId, $tenantId);
        $employees = $this->adjustments->inScope($scopeType, $scopeId, $tenantId);

        if ($employees === []) {
            throw new ApiFailure(__('messages.no_employees_in_scope'), 404, 'no_employees_in_scope');
        }

        $isPercent = $amountType === 'percent';
        $locked = array_flip($this->ledger->lockedEmployeeIds(
            $tenantId,
            $month,
            array_map(static fn (array $e): int => Value::int($e['id'] ?? null), $employees),
        ));

        $eligible = [];
        $lockedCount = 0;
        $zeroCount = 0;

        foreach ($employees as $employee) {
            $employeeId = Value::int($employee['id'] ?? null);

            if (isset($locked[$employeeId])) {
                $lockedCount++;

                continue;
            }

            $figure = $isPercent
                ? round(Value::float($employee['base_salary'] ?? null) * $amount / 100, 2)
                : $amount;

            // A percentage of nothing is nothing, and a zero line would clutter
            // the payslip with something that changes no total.
            if ($figure <= 0) {
                $zeroCount++;

                continue;
            }

            $eligible[] = [
                'id' => $employeeId,
                'amount' => $figure,
            ];
        }

        $duplicate = BulkAdjustments::existsSimilar(
            $tenantId, $kind, $scopeType, $scopeType === 'all' ? null : $scopeId, $month
        );

        if ($request->boolean('dry_run')) {
            return ApiResponse::success([
                'dry_run' => true,
                'affected_count' => count($employees),
                'eligible_count' => count($eligible),
                'locked_count' => $lockedCount,
                'zero_count' => $zeroCount,
                // Reported rather than refused: applying the same bonus twice
                // is occasionally deliberate, and only the person pressing the
                // button knows.
                'duplicate' => $duplicate,
                'month' => $month,
            ]);
        }

        if ($eligible === []) {
            throw new ApiFailure(
                __('messages.no_eligible_employees'),
                409,
                'no_eligible_employees',
            );
        }

        $batchId = BulkAdjustments::create(
            $tenantId, $kind, $scopeType,
            $scopeType === 'all' ? null : $scopeId,
            $scopeName, $amount, $amountType, $reason, $adminId, $month,
        );

        $lineReason = $isPercent ? $reason.BulkAdjustments::percentNote($amount) : $reason;
        $isBonus = $kind === 'bonus';

        foreach ($eligible as $line) {
            $this->adjustments->record(
                $isBonus, $line['id'], $tenantId, $line['amount'], $lineReason, $adminId, $month, $batchId,
            );

            $this->notifier->notifyEmployee(
                $tenantId, $line['id'], 'payroll',
                $isBonus ? 'New bonus' : 'New deduction',
                $isBonus ? 'مكافأة جديدة' : 'خصم جديد',
                $isBonus ? 'A bonus was added to your salary.' : 'A deduction was applied to your salary.',
                $isBonus ? 'تمت إضافة مكافأة على راتبك.' : 'تمت إضافة خصم على راتبك.',
                ['type' => $isBonus ? 'bonus_added' : 'deduction_added', 'month' => $month],
            );
        }

        AuditLog::record($tenantId, $adminId, $kind.'.bulk', 'bulk_adjustment', $batchId, [
            'amount' => $amount,
            'amount_type' => $amountType,
            'count' => count($eligible),
            'locked' => $lockedCount,
            'zero' => $zeroCount,
            'scope_type' => $scopeType,
            'month' => $month,
        ]);

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success([
            'id' => $batchId,
            'count' => count($eligible),
            'locked' => $lockedCount,
            'skipped' => $zeroCount,
            'month' => $month,
            'message' => 'Bulk '.$kind.' applied to '.count($eligible).' employees',
        ]);
    }

    /**
     * Changes the batch and re-resolves every line it owns.
     *
     * A percentage is re-applied against each employee's *current* base salary,
     * so a raise between the two edits is reflected rather than frozen at what
     * the original run happened to compute.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $batch] = $this->target($id, $tenantId);

        $amountType = Value::string($request->input('amount_type'), 'fixed') ?: 'fixed';
        $amount = Value::float($request->input('amount'));

        if (! in_array($amountType, BulkAdjustments::AMOUNT_TYPES, true)) {
            throw new ApiFailure('Invalid amount_type', 422, 'invalid_amount_type');
        }

        if ($amount <= 0) {
            throw new ApiFailure('Amount must be greater than zero', 422, 'invalid_amount');
        }

        if ($amountType === 'percent' && $amount > 100) {
            throw new ApiFailure('Percentage must be between 0 and 100', 422, 'invalid_percentage');
        }

        $kind = Value::string($batch['kind'] ?? null);
        $reason = trim(Value::string($request->input('reason')));
        $isPercent = $amountType === 'percent';
        $lineReason = $isPercent ? $reason.BulkAdjustments::percentNote($amount) : $reason;

        $updated = 0;

        foreach (BulkAdjustments::members($id, $kind, $tenantId) as $member) {
            $figure = $isPercent
                ? round(Value::float($member['base_salary'] ?? null) * $amount / 100, 2)
                : $amount;

            if ($figure <= 0) {
                continue;
            }

            BulkAdjustments::updateMemberAmount(
                Value::int($member['id'] ?? null), $kind, $tenantId, $figure, $lineReason,
            );
            $updated++;
        }

        BulkAdjustments::updateMeta($id, $tenantId, $amount, $amountType, $reason);

        AuditLog::record($tenantId, $adminId, $kind.'.bulk_update', 'bulk_adjustment', $id, [
            'amount' => $amount,
            'amount_type' => $amountType,
            'updated' => $updated,
        ]);

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['updated' => $updated, 'message' => 'Bulk adjustment updated']);
    }

    public function delete(Request $request, int $id): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $batch] = $this->target($id, $tenantId);

        $kind = Value::string($batch['kind'] ?? null);
        $isBonus = $kind === 'bonus';

        // Captured before the rows go, so the people affected can still be told.
        $members = BulkAdjustments::members($id, $kind, $tenantId);

        BulkAdjustments::deleteBatch($id, $kind, $tenantId);

        foreach ($members as $member) {
            $this->announceRemoval($tenantId, $member, $isBonus);
        }

        AuditLog::record($tenantId, $adminId, $kind.'.bulk_delete', 'bulk_adjustment', $id, [
            'members' => count($members),
        ]);

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['removed' => count($members), 'message' => 'Bulk adjustment deleted']);
    }

    /** Takes one person out, leaving the rest of the batch intact. */
    public function removeMember(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $batch] = $this->target(Value::int($request->input('id')) ?: Value::int($request->query('id')), $tenantId);

        $rowId = Value::int($request->input('row_id'));

        if ($rowId <= 0) {
            throw new ApiFailure('row_id is required', 422, 'row_id_required');
        }

        $kind = Value::string($batch['kind'] ?? null);
        $member = null;

        foreach (BulkAdjustments::members($id, $kind, $tenantId) as $candidate) {
            if (Value::int($candidate['id'] ?? null) === $rowId) {
                $member = $candidate;
            }
        }

        if ($member === null || ! BulkAdjustments::removeMember($rowId, $id, $kind, $tenantId)) {
            throw new ApiFailure(__('messages.member_not_in_batch'), 404, 'not_found');
        }

        $this->announceRemoval($tenantId, $member, $kind === 'bonus');

        AuditLog::record($tenantId, $adminId, $kind.'.bulk_remove_member', 'bulk_adjustment', $id, [
            'row_id' => $rowId,
            'employee_id' => $member['employee_id'] ?? null,
        ]);

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['message' => 'Member removed from batch']);
    }

    /**
     * @param  array<string, mixed>  $member
     */
    private function announceRemoval(int $tenantId, array $member, bool $isBonus): void
    {
        $amount = Value::float($member['amount'] ?? null);

        $this->notifier->notifyEmployee(
            $tenantId,
            Value::int($member['employee_id'] ?? null),
            'payroll',
            $isBonus ? 'Bonus cancelled' : 'Deduction cancelled',
            $isBonus ? 'إلغاء مكافأة' : 'إلغاء خصم',
            $isBonus
                ? "A bonus of {$amount} was cancelled."
                : "A deduction of {$amount} was cancelled.",
            $isBonus
                ? "تم إلغاء مكافأة بقيمة {$amount} من راتبك."
                : "تم إلغاء خصم بقيمة {$amount} من راتبك.",
            ['type' => $isBonus ? 'bonus_removed' : 'deduction_removed', 'amount' => (string) $amount],
        );
    }

    private function assertShape(string $kind, string $scopeType, string $amountType, float $amount, int $scopeId): void
    {
        if (! in_array($kind, BulkAdjustments::KINDS, true)) {
            throw new ApiFailure('Invalid kind', 422, 'invalid_kind');
        }

        if (! in_array($scopeType, BulkAdjustments::SCOPES, true)) {
            throw new ApiFailure('Invalid scope_type', 422, 'invalid_scope_type');
        }

        if (! in_array($amountType, BulkAdjustments::AMOUNT_TYPES, true)) {
            throw new ApiFailure('Invalid amount_type', 422, 'invalid_amount_type');
        }

        if ($amount <= 0) {
            throw new ApiFailure('Amount must be greater than zero', 422, 'invalid_amount');
        }

        if ($amountType === 'percent' && $amount > 100) {
            throw new ApiFailure('Percentage must be between 0 and 100', 422, 'invalid_percentage');
        }

        if ($scopeType !== 'all' && $scopeId <= 0) {
            throw new ApiFailure('scope_id is required', 422, 'scope_id_required');
        }
    }

    /**
     * The scope's name as it stands now, kept on the batch so it still reads
     * sensibly after the branch it named has been renamed or removed.
     */
    private function scopeName(string $scopeType, int $scopeId, int $tenantId): ?string
    {
        $table = match ($scopeType) {
            'branch' => 'branches',
            'category' => 'employee_categories',
            'shift' => 'shifts',
            'employee' => 'employees',
            default => null,
        };

        if ($table === null) {
            return null;
        }

        $name = DB::table($table)->where('id', $scopeId)->where('tenant_id', $tenantId)->value('name');

        if ($name === null) {
            throw new ApiFailure(ucfirst($scopeType).' not found', 404, 'not_found');
        }

        return Value::string($name);
    }

    /**
     * @return array{0: int, 1: array<string, mixed>}
     */
    private function target(int $id, int $tenantId): array
    {
        $batch = $id > 0 ? BulkAdjustments::find($id, $tenantId) : null;

        if ($batch === null) {
            throw new ApiFailure(__('messages.bulk_adjustment_not_found'), 404, 'not_found');
        }

        return [$id, $batch];
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        return $admin;
    }
}
