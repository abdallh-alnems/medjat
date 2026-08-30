<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Http\ApiResponse;
use App\Modules\Payroll\Domain\PayrollLedger;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/payroll/list_slips.php.
 *
 * Saved slips only — the live overview is where unmaterialised months live.
 */
final class ListSlipsController
{
    public function __construct(private readonly PayrollLedger $ledger) {}

    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $month = Value::string($request->query('month'), '') ?: substr(TenantClock::date($tenantId), 0, 7);
        $branchId = Value::int($request->query('branch_id')) ?: null;
        $page = max(1, Value::int($request->query('page'), 1));

        return ApiResponse::success($this->ledger->slipsForMonth($tenantId, $month, $branchId, $page));
    }
}
