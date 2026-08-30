<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Payroll\Domain\PayLineOverrides;
use App\Modules\Payroll\Domain\PayrollCache;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/payroll/override_line.php.
 *
 * Corrects a single computed line for one month: set a different amount, waive
 * it, or drop the correction. Manual lines are not editable here — they are
 * rows the company owns and edits through their own form.
 */
final class OverrideLineController
{
    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $adminId = $admin->id;

        $employeeId = Value::int($request->input('employee_id'));
        $month = Value::string($request->input('month'));
        $kind = Value::string($request->input('line_kind'));
        $type = Value::string($request->input('line_type'));
        $date = Value::string($request->input('line_date'), '') ?: null;
        $description = Value::string($request->input('line_desc'));
        $action = Value::string($request->input('action'));

        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'employee_id_required');
        }
        if (preg_match('/^\d{4}-\d{2}$/', $month) !== 1) {
            throw new ApiFailure('Invalid month format (expected YYYY-MM)', 422, 'invalid_month_format_expected_yyyy');
        }
        if (! in_array($kind, ['deduction', 'bonus'], true)) {
            throw new ApiFailure('line_kind must be deduction or bonus', 422, 'line_kind_deduction_bonus');
        }
        if ($type === '') {
            throw new ApiFailure('line_type is required', 422, 'line_type_required');
        }
        if (! in_array($action, ['set', 'waive', 'clear'], true)) {
            throw new ApiFailure('action must be set, waive or clear', 422, 'action_set_waive_clear');
        }
        if ($type === 'manual') {
            throw new ApiFailure('Manual lines are edited from their own form', 422, 'manual_lines_edited_from_their');
        }

        $exists = DB::table('employees')
            ->where('id', $employeeId)->where('tenant_id', $tenantId)->exists();

        if (! $exists) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        // An approved or paid slip is the source of truth and is not edited in
        // place: the admin reverts it to draft first, which leaves a trail.
        $status = DB::table('payroll')
            ->where('employee_id', $employeeId)->where('month', $month)->where('tenant_id', $tenantId)
            ->value('status');

        if ($status !== null && in_array(Value::string($status), ['approved', 'paid'], true)) {
            throw new ApiFailure(
                'Slip is locked. Revert it to draft before editing lines.',
                409,
                'slip_locked_revert_it_draft',
            );
        }

        if ($action === 'clear') {
            PayLineOverrides::clear($tenantId, $employeeId, $month, $kind, $type, $date, $description);
        } else {
            $waived = $action === 'waive';
            $amount = null;

            if (! $waived) {
                $raw = $request->input('amount');

                if (! is_numeric($raw)) {
                    throw new ApiFailure('amount is required when setting a value', 422, 'amount_required_setting_value');
                }

                $amount = Value::float($raw);

                if ($amount < 0) {
                    throw new ApiFailure('amount must be zero or positive', 422, 'amount_zero_positive');
                }
            }

            $reason = trim(Value::string($request->input('reason'))) ?: null;

            PayLineOverrides::save(
                $tenantId, $employeeId, $month, $kind, $type, $date, $description,
                $waived, $amount, $reason, $adminId,
            );
        }

        AuditLog::record($tenantId, $adminId, 'payroll.line_override', 'employee', $employeeId, [
            'month' => $month, 'kind' => $kind, 'type' => $type, 'action' => $action,
        ]);

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['message' => 'Override saved', 'action' => $action]);
    }
}
