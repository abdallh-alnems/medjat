<?php

declare(strict_types=1);

namespace App\Modules\Employees\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\ActivationCode;
use App\Models\Admin;
use App\Models\Employee;
use App\Modules\Documents\Domain\DocumentChecklist;
use App\Modules\Employees\Domain\ComplianceExpiry;
use App\Modules\Employees\Domain\Suspension;
use App\Modules\Leave\Domain\LeaveBalance;
use App\Shared\Http\ApiResponse;
use App\Shared\Http\Middleware\RequireBranchAccess;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports get_profile.php, expiring_compliance.php and get_year_to_date.php.
 */
final class EmployeeProfileController
{
    public function show(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $id = Value::int($request->query('id'));

        if ($id <= 0) {
            throw new ApiFailure('Employee ID is required', 422, 'employee_id_required');
        }

        // Reconciled first, then read: the status shown has to reflect the
        // reactivation rather than the state a moment before it.
        Suspension::reconcileExpired($tenantId, date('Y-m-d'));

        $employee = Employee::query()->forTenant($tenantId)->whereKey($id)->first();
        if ($employee === null) {
            throw new ApiFailure(__('messages.employee_profile_not_found'), 404, 'employee_profile_not_found');
        }

        return ApiResponse::success([
            'employee' => $this->present($employee, $tenantId),
            'documents' => DocumentChecklist::forEmployee($employee->id, $tenantId),
            'warnings' => $this->warnings($employee->id, $tenantId),
            'leave_balance' => LeaveBalance::forEmployee($employee->id, $tenantId, (int) date('Y')),
            'activation_code' => $this->pendingCode($employee),
            'categories' => $this->categories($employee->id, $tenantId),
            'cycle_start_day' => $this->cycleStartDay($employee, $tenantId),
            'active_suspension' => Suspension::activeFor($employee->id, $tenantId),
        ]);
    }

    public function expiringCompliance(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $days = max(1, min(365, Value::int($request->query('days'), 30)));
        $branchId = Value::int($request->query('branch_id'));
        $branchId = $branchId > 0 ? $branchId : null;

        if ($branchId !== null) {
            RequireBranchAccess::assert($admin, $branchId);
        }

        // Already-expired items are in unless explicitly excluded: an expired
        // iqama is more urgent than one expiring next week, not less.
        $includeExpired = $request->query('include_expired') !== '0';

        $items = ComplianceExpiry::within($tenantId, $days, $branchId, $includeExpired);
        $expired = count(array_filter($items, static fn (array $i): bool => $i['is_expired'] === true));

        return ApiResponse::success([
            'items' => $items,
            'count' => count($items),
            'expired_count' => $expired,
            'expiring_count' => count($items) - $expired,
            'days' => $days,
        ]);
    }

    /**
     * Everything paid this year, for a tax filing or a bank letter.
     */
    public function yearToDate(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->query('employee_id'));
        $year = Value::int($request->query('year'), (int) date('Y'));

        if ($employeeId <= 0) {
            throw new ApiFailure(__('messages.employee_id_required'), 422, 'employee_id_required');
        }

        if ($year < 2000 || $year > 2100) {
            throw new ApiFailure('Invalid year', 422, 'invalid_year');
        }

        if (! Employee::query()->forTenant($tenantId)->whereKey($employeeId)->exists()) {
            throw new ApiFailure(__('messages.employee_not_found'), 404);
        }

        $rows = DB::table('payroll')
            ->where('tenant_id', $tenantId)
            ->where('employee_id', $employeeId)
            ->where('month', 'like', $year.'-%')
            ->orderBy('month')
            ->get(['month', 'base_salary', 'total_deductions', 'total_bonuses', 'net_salary', 'status', 'approved_at', 'paid_at']);

        $totals = [
            'total_base' => 0.0,
            'total_deductions' => 0.0,
            'total_bonuses' => 0.0,
            'total_net' => 0.0,
            'months_count' => $rows->count(),
            'paid_count' => 0,
            'approved_count' => 0,
            'draft_count' => 0,
        ];

        foreach ($rows as $row) {
            $totals['total_base'] += Value::float($row->base_salary);
            $totals['total_deductions'] += Value::float($row->total_deductions);
            $totals['total_bonuses'] += Value::float($row->total_bonuses);
            $totals['total_net'] += Value::float($row->net_salary);

            $status = Value::string($row->status);
            if (array_key_exists($status.'_count', $totals)) {
                $totals[$status.'_count'] = Value::int($totals[$status.'_count']) + 1;
            }
        }

        return ApiResponse::success([
            'year' => $year,
            'months' => array_values(array_map(static fn (object $r): array => (array) $r, $rows->all())),
            'totals' => $totals,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function present(Employee $employee, int $tenantId): array
    {
        /** @var array<string, mixed> $row */
        $row = $employee->attributesToArray();

        // The model hides these, but the profile is built from the raw
        // attributes, so they are removed explicitly and replaced by the
        // booleans the interface actually wants.
        //
        // face_embedding is the biometric template the server matches against —
        // handing it out gives away the very thing an impersonation would
        // otherwise have to produce. kiosk_pin_hash is a six-digit space, which
        // is a short offline search away from the code itself.
        $row['face_enrolled'] = ! empty($employee->getAttribute('face_embedding'));
        $row['kiosk_pin_set'] = ! empty($employee->getAttribute('kiosk_pin_hash'));
        unset($row['face_embedding'], $row['kiosk_pin_hash'], $row['login_code_hash']);

        $stationId = Value::nullableInt($employee->getAttribute('face_enrolled_by_station_id'));
        if ($stationId !== null) {
            $row['face_enrolled_station_name'] = DB::table('attendance_stations')
                ->where('id', $stationId)->where('tenant_id', $tenantId)->value('name');
        }

        return $row;
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function warnings(int $employeeId, int $tenantId): array
    {
        $rows = DB::table('warnings')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->orderByDesc('created_at')
            ->get();

        /** @var list<array<string, mixed>> */
        return array_values(array_map(static fn (object $r): array => (array) $r, $rows->all()));
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function categories(int $employeeId, int $tenantId): array
    {
        $rows = DB::table('employee_categories as ec')
            ->join('employee_category_assignments as eca', 'eca.category_id', '=', 'ec.id')
            ->where('eca.employee_id', $employeeId)
            ->where('eca.tenant_id', $tenantId)
            ->get(['ec.id', 'ec.name']);

        /** @var list<array<string, mixed>> */
        return array_values(array_map(static fn (object $r): array => (array) $r, $rows->all()));
    }

    private function pendingCode(Employee $employee): ?string
    {
        if ($employee->status !== 'pending_activation') {
            return null;
        }

        $code = ActivationCode::query()
            ->usable()
            ->where('employee_id', $employee->id)
            ->orderByDesc('created_at')
            ->value('code');

        return Value::nullableString($code);
    }

    /** Branch override, else the company default, else the first of the month. */
    private function cycleStartDay(Employee $employee, int $tenantId): int
    {
        if ($employee->branch_id !== null) {
            $branch = DB::table('branches')->where('id', $employee->branch_id)
                ->where('tenant_id', $tenantId)->value('cycle_start_day');

            if ($branch !== null) {
                return Value::int($branch, 1);
            }
        }

        return Value::int(DB::table('tenants')->where('id', $tenantId)->value('cycle_start_day'), 1);
    }
}
