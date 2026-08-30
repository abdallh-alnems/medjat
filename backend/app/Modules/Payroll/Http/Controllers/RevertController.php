<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Payroll\Domain\PayrollCache;
use App\Modules\Payroll\Domain\PayrollLedger;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/payroll/revert.php.
 *
 * Steps a slip one state back so it can be corrected. A draft has nowhere left
 * to go, which is reported rather than treated as success — a "reverted"
 * message for a slip that did not move would send somebody looking for a change
 * that never happened.
 */
final class RevertController
{
    public function __construct(private readonly PayrollLedger $ledger) {}

    public function __invoke(Request $request): JsonResponse
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

        $from = $this->ledger->revert($payrollId, $tenantId);

        if ($from === null) {
            throw new ApiFailure('Slip not found or already in draft', 422, 'slip_not_found_already_draft');
        }

        AuditLog::record($tenantId, $adminId, 'payroll.revert', 'payroll', $payrollId, ['from' => $from]);

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['message' => 'Payroll reverted', 'from' => $from]);
    }
}
