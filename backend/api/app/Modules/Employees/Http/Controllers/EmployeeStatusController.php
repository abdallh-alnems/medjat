<?php

declare(strict_types=1);

namespace App\Modules\Employees\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\ActivationCode;
use App\Models\Admin;
use App\Models\Employee;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Auth\Services\WebSessionService;
use App\Shared\Crew\Crew;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Ports reactivate.php, set_crew_supervisor.php and reset_web_pin.php.
 */
final class EmployeeStatusController
{
    /**
     * Re-hiring somebody whose service ended.
     *
     * The previous end-of-service settlement goes with it, so a future
     * termination starts from a clean draft rather than adding to a figure that
     * was already paid.
     */
    public function reactivate(Request $request): JsonResponse
    {
        [$admin, $tenantId, $employee] = $this->context($request);

        if ($employee->status !== 'terminated') {
            throw new ApiFailure('هذا الموظف ليس منتهي الخدمة', 409, 'not_terminated');
        }

        $reactivated = DB::table('employees')
            ->where('id', $employee->id)->where('tenant_id', $tenantId)->where('status', 'terminated')
            ->update([
                // Pending, not active: the old device token was revoked at
                // termination, so they have to link a device again.
                'status' => 'pending_activation',
                'terminated_at' => null,
                'auto_terminate_at' => null,
                'updated_at' => DB::raw('NOW()'),
            ]) > 0;

        if (! $reactivated) {
            throw new ApiFailure('تعذر إعادة تعيين الموظف', 409, 'reactivate_failed');
        }

        DB::table('employee_settlements')
            ->where('employee_id', $employee->id)->where('tenant_id', $tenantId)->delete();

        $activation = ActivationCode::generateFor($tenantId, $employee->id);

        AuditLog::record($tenantId, $admin->id, 'employee.reactivate', 'employee', $employee->id, [
            'name' => $employee->name,
        ]);

        return ApiResponse::success([
            'message' => 'تمت إعادة تعيين الموظف',
            'activation_code' => $activation['code'],
            'expires_at' => $activation['expires_at'],
        ]);
    }

    /**
     * Who may record this employee's attendance on site.
     *
     * Administrator-only, and that is the point: this is the control deciding
     * who gets the one employee-credential exception in the system, so an
     * employee must never be able to add themselves to a crew or grant
     * themselves one.
     */
    public function setCrewSupervisor(Request $request): JsonResponse
    {
        [$admin, $tenantId, $employee] = $this->context($request);

        // An absent key means "leave it alone"; an explicit null means "clear
        // it". Those are different requests and a bare ?? collapses them.
        if (! $request->has('supervisor_id')) {
            throw new ApiFailure('supervisor_id is required (send null to clear)', 422, 'supervisor_id_required');
        }

        $raw = $request->input('supervisor_id');
        $supervisorId = $raw === null ? null : Value::int($raw);

        if ($supervisorId !== null) {
            if ($supervisorId <= 0) {
                throw new ApiFailure('supervisor_id must be a positive id or null', 422, 'supervisor_id_invalid');
            }

            // Tenant-scoped: without it an administrator could point their
            // employee at somebody in another company, and the crew queries —
            // which filter on tenant — would silently return nothing, looking
            // like a setting that saved but does not work.
            $supervisor = Employee::query()->forTenant($tenantId)->whereKey($supervisorId)->first();
            if ($supervisor === null) {
                throw new ApiFailure('Supervisor not found', 404);
            }

            if ($supervisor->isTerminated()) {
                throw new ApiFailure('لا يمكن اختيار مشرف منتهي الخدمة', 422, 'supervisor_terminated');
            }

            if (Crew::wouldCycle($supervisorId, $employee->id, $tenantId)) {
                throw new ApiFailure('هذا الاختيار ينشئ حلقة إشراف', 422, 'supervisor_cycle');
            }
        }

        DB::table('employees')->where('id', $employee->id)->where('tenant_id', $tenantId)
            ->update(['crew_supervisor_id' => $supervisorId]);

        AuditLog::record($tenantId, $admin->id, 'employee.set_crew_supervisor', 'employee', $employee->id, [
            'supervisor_id' => $supervisorId,
        ]);

        return ApiResponse::success([
            'message' => $supervisorId === null ? 'تم إلغاء المشرف' : 'تم تعيين المشرف',
        ]);
    }

    /**
     * Resetting an employee's browser PIN.
     *
     * Two jobs in one call. Recovery, because a six-digit secret with a
     * five-attempt lockout will be forgotten and will lock people out. And
     * control: this is the single call that severs browser access immediately,
     * for a departing employee, a lost laptop, or a PIN shared with a colleague.
     * That is why live sessions are revoked rather than left to run down — a
     * reset taking effect at the next expiry would leave up to sixteen hours of
     * access after the decision to end it.
     */
    public function resetWebPin(Request $request): JsonResponse
    {
        [$admin, $tenantId, $employee] = $this->context($request);

        try {
            $activation = DB::transaction(function () use ($employee, $tenantId): array {
                DB::table('employee_web_credentials')
                    ->where('employee_id', $employee->id)->where('tenant_id', $tenantId)->delete();

                WebSessionService::revokeAllForEmployee($employee->id, 'admin_reset_web_pin');

                // A fresh single-use code, because setting a new PIN goes
                // through the same door as setting the first one. Without it
                // the employee has no way to establish a new secret.
                return ActivationCode::generateFor($tenantId, $employee->id);
            });
        } catch (Throwable $e) {
            Log::error('Web PIN reset failed', ['employee_id' => $employee->id, 'exception' => $e]);
            throw new ApiFailure('حدث خطأ، حاول مرة أخرى', 500, 'reset_failed');
        }

        AuditLog::record($tenantId, $admin->id, 'employee.web_pin_reset', 'employee', $employee->id);

        return ApiResponse::success([
            'message' => 'تم إعادة تعيين الرقم السري',
            'activation_code' => $activation['code'],
            'expires_at' => $activation['expires_at'],
        ]);
    }

    /**
     * @return array{Admin, int, Employee}
     */
    private function context(Request $request): array
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->input('employee_id'));

        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'missing_fields');
        }

        $employee = Employee::query()->forTenant($tenantId)->whereKey($employeeId)->first();
        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404);
        }

        return [$admin, $tenantId, $employee];
    }
}
