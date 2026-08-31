<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Notifications\Domain\Notifier;
use App\Modules\Payroll\Domain\PayrollCache;
use App\Modules\Payroll\Domain\PayrollLedger;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/payroll/mark_paid.php.
 *
 * Accepts one id or a list of them — the single-row action should not have to
 * wrap its id in an array to reach the same endpoint.
 */
final class MarkPaidController
{
    public function __construct(
        private readonly PayrollLedger $ledger,
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

        $ids = self::ids($request);
        $paidAt = PaidAt::fromRequest($request);

        $touched = $this->ledger->markPaidMany($ids, $tenantId, $paidAt);

        AuditLog::record($tenantId, $adminId, 'payroll.mark_paid', 'payroll', null, [
            'count' => count($touched),
            'ids' => array_map(static fn (array $row): int => Value::int($row['id'] ?? null), $touched),
            'paid_at' => $paidAt,
        ]);

        PayrollCache::invalidate($tenantId);

        foreach ($touched as $row) {
            $month = Value::string($row['month'] ?? null);

            $this->notifier->notifyEmployee(
                $tenantId,
                Value::int($row['employee_id'] ?? null),
                'payroll',
                'Salary paid',
                'تم دفع راتبك',
                "Your salary for {$month} has been paid.",
                "تم تأكيد دفع راتب شهر {$month}.",
                ['type' => 'payroll_paid', 'month' => $month],
            );
        }

        return ApiResponse::success([
            'paid_count' => count($touched),
            'message' => 'Slips marked as paid',
        ]);
    }

    /**
     * @return list<int>
     */
    private static function ids(Request $request): array
    {
        $ids = $request->input('ids');

        if (is_array($ids) && $ids !== []) {
            return array_values(array_map(static fn (mixed $id): int => Value::int($id), $ids));
        }

        $single = Value::int($request->input('payroll_id'));

        if ($single > 0) {
            return [$single];
        }

        throw new ApiFailure('payroll_id or ids required', 422, 'payroll_id_ids_required');
    }
}
