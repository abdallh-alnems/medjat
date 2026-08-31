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
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/deductions/{add,update,delete}_manual.php and the same three
 * under api/app/bonuses.
 *
 * One-off lines somebody typed in, as opposed to the ones the calculator
 * derives from attendance and rules. Only these can be edited here — a late
 * deduction is a consequence of a day, and changing it means changing the day.
 */
final class ManualAdjustmentController
{
    public function __construct(
        private readonly ManualAdjustments $adjustments,
        private readonly Notifier $notifier,
    ) {}

    public function addDeduction(Request $request): JsonResponse
    {
        return $this->add($request, isBonus: false);
    }

    public function addBonus(Request $request): JsonResponse
    {
        return $this->add($request, isBonus: true);
    }

    public function updateDeduction(Request $request, int $id): JsonResponse
    {
        return $this->change($request, $id, isBonus: false);
    }

    public function updateBonus(Request $request, int $id): JsonResponse
    {
        return $this->change($request, $id, isBonus: true);
    }

    public function deleteDeduction(Request $request, int $id): JsonResponse
    {
        return $this->remove($request, $id, isBonus: false);
    }

    public function deleteBonus(Request $request, int $id): JsonResponse
    {
        return $this->remove($request, $id, isBonus: true);
    }

    private function add(Request $request, bool $isBonus): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $employeeId = Value::int($request->input('employee_id'));
        $amount = Value::float($request->input('amount'));

        if ($amount <= 0) {
            throw new ApiFailure('amount must be positive', 422, 'amount_positive');
        }

        $exists = DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)->exists();

        if (! $exists) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        $reason = trim(Value::string($request->input('reason')));
        $month = substr(TenantClock::date($tenantId), 0, 7);

        $id = $this->adjustments->record($isBonus, $employeeId, $tenantId, $amount, $reason, $adminId, $month);

        AuditLog::record(
            $tenantId, $adminId,
            $isBonus ? 'bonus.manual' : 'deduction.manual',
            'employee', $employeeId, ['amount' => $amount],
        );

        PayrollCache::invalidate($tenantId);

        $this->tell($tenantId, $employeeId, $isBonus, $amount, $reason);

        return ApiResponse::success([
            'id' => $id,
            'message' => $isBonus ? 'Manual bonus added' : 'Manual deduction added',
        ]);
    }

    private function change(Request $request, int $id, bool $isBonus): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $existing] = $this->target($id, $tenantId, $isBonus);

        $amount = Value::float($request->input('amount'));

        if ($amount <= 0) {
            throw new ApiFailure('amount must be positive', 422, 'amount_positive');
        }

        DB::table(self::table($isBonus))->where('id', $id)->where('tenant_id', $tenantId)->update([
            'amount' => $amount,
            'reason' => trim(Value::string($request->input('reason'))),
        ]);

        AuditLog::record(
            $tenantId, $adminId,
            $isBonus ? 'bonus.manual_update' : 'deduction.manual_update',
            'employee', Value::int($existing['employee_id'] ?? null),
            ['id' => $id, 'amount' => $amount],
        );

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['message' => $isBonus ? 'Manual bonus updated' : 'Manual deduction updated']);
    }

    private function remove(Request $request, int $id, bool $isBonus): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $existing] = $this->target($id, $tenantId, $isBonus);

        DB::table(self::table($isBonus))->where('id', $id)->where('tenant_id', $tenantId)->delete();

        AuditLog::record(
            $tenantId, $adminId,
            $isBonus ? 'bonus.manual_delete' : 'deduction.manual_delete',
            'employee', Value::int($existing['employee_id'] ?? null),
            ['id' => $id, 'amount' => Value::float($existing['amount'] ?? null)],
        );

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['message' => $isBonus ? 'Manual bonus deleted' : 'Manual deduction deleted']);
    }

    private function tell(int $tenantId, int $employeeId, bool $isBonus, float $amount, string $reason): void
    {
        $this->notifier->notifyEmployee(
            $tenantId, $employeeId, 'payroll',
            $isBonus ? 'New bonus' : 'New deduction',
            $isBonus ? 'مكافأة جديدة' : 'خصم جديد',
            $isBonus
                ? "A bonus of {$amount} was added to your salary."
                : "A deduction of {$amount} was applied to your salary.",
            $isBonus
                ? "تمت إضافة مكافأة بقيمة {$amount} لراتبك."
                : "تمت إضافة خصم بقيمة {$amount} على راتبك.",
            [
                'type' => $isBonus ? 'bonus_added' : 'deduction_added',
                'amount' => (string) $amount,
                'reason' => $reason,
            ],
        );
    }

    /**
     * @return array{0: int, 1: array<string, mixed>}
     */
    private function target(int $id, int $tenantId, bool $isBonus): array
    {

        $row = $id > 0
            ? DB::table(self::table($isBonus))->where('id', $id)->where('tenant_id', $tenantId)->first()
            : null;

        if ($row === null) {
            throw new ApiFailure($isBonus ? 'Bonus not found' : 'Deduction not found', 404, 'not_found');
        }

        /** @var array<string, mixed> $existing */
        $existing = (array) $row;

        return [$id, $existing];
    }

    private static function table(bool $isBonus): string
    {
        return $isBonus ? 'manual_bonuses' : 'manual_deductions';
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
