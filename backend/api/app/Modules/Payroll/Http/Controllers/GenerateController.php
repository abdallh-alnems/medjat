<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Notifications\Domain\ManagerAlert;
use App\Modules\Payroll\Domain\PayrollCache;
use App\Modules\Payroll\Domain\PayrollLedger;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/payroll/generate.php.
 *
 * Materialise draft slips for a month. Re-running is safe: each employee's slip
 * is upserted, so a second run refreshes the figures rather than duplicating
 * rows. Slips already approved keep their frozen numbers — the calculator is
 * not consulted for them again.
 */
final class GenerateController
{
    public function __construct(
        private readonly PayrollLedger $ledger,
        private readonly ManagerAlert $alert,
    ) {}

    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        $adminId = $admin->id;

        $month = Value::string($request->input('month'), '') ?: substr(TenantClock::date($tenantId), 0, 7);
        $branchId = Value::int($request->input('branch_id')) ?: null;

        $results = $this->ledger->generate($tenantId, $month, $branchId);

        AuditLog::record($tenantId, $adminId, 'payroll.generate', null, null, ['month' => $month]);

        $this->alert->notify(
            $tenantId,
            'payroll',
            'كشف رواتب جديد',
            'Payroll Generated',
            "تم توليد كشف رواتب لشهر {$month}",
            "Payroll generated for {$month}",
            null,
            ['month' => $month, 'branch_id' => (string) ($branchId ?? ''), 'count' => (string) count($results)],
        );

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success([
            'month' => $month,
            'generated_count' => count($results),
        ]);
    }
}
