<?php

declare(strict_types=1);

namespace App\Modules\Leave\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Leave\Domain\LeaveBalanceCalculator;
use App\Modules\Leave\Domain\LeaveRequests;
use App\Modules\Leave\Services\ConvertToAbsenceAction;
use App\Modules\Leave\Services\RecordLeaveAction;
use App\Modules\Notifications\Domain\Notifier;
use App\Shared\Access\Permissions;
use App\Shared\Approvals\ApprovalRouter;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/leaves/{list,create,approve,reject,get_balance,convert_to_absence,create_recurring}.php.
 *
 * The management side of leave. Approving or rejecting from here overrides any
 * multi-step chain the company has configured: somebody with the permission has
 * decided, and leaving the chain open would park the request in an approver's
 * inbox for a decision that has already been made.
 */
final class LeaveAdminController
{
    public function __construct(
        private readonly LeaveRequests $leaves,
        private readonly LeaveBalanceCalculator $balances,
        private readonly ApprovalRouter $approvals,
        private readonly RecordLeaveAction $record,
        private readonly ConvertToAbsenceAction $convert,
        private readonly Notifier $notifier,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $status = Value::string($request->query('status')) ?: null;
        $branchId = Value::int($request->query('branch_id')) ?: null;
        $categoryId = Value::int($request->query('category_id')) ?: null;
        $search = trim(Value::string($request->query('q'))) ?: null;

        return ApiResponse::success($this->leaves->forTenant(
            $tenantId,
            max(1, Value::int($request->query('page'), 1)),
            min(500, max(1, Value::int($request->query('limit'), 200))),
            $status,
            $branchId,
            $categoryId,
            $search,
        ));
    }

    public function create(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        $result = $this->record->execute($request->all(), $tenantId, $adminId);

        AuditLog::record(
            $tenantId, $adminId, 'leave.create', 'leave',
            Value::nullableInt($result['leave_id'] ?? null) ?? self::firstSplitId($result),
        );

        return ApiResponse::success($result);
    }

    public function approve(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $leaveId = self::leaveId($request);

        $this->approvals->cancelFor($tenantId, 'leave', $leaveId);
        $this->leaves->approve($leaveId, $tenantId, $adminId);

        AuditLog::record($tenantId, $adminId, 'leave.approve', 'leave', $leaveId);

        $this->tellEmployee(
            $tenantId, $leaveId, 'approve',
            'Leave Approved', 'تم قبول الإجازة',
            'Your leave request has been approved.', 'تم قبول طلب الإجازة الخاص بك.',
        );

        return ApiResponse::success(['message' => 'Leave approved']);
    }

    public function reject(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $leaveId = self::leaveId($request);

        $reason = trim(Value::string($request->input('rejection_reason') ?? $request->input('reason')));

        $this->approvals->cancelFor($tenantId, 'leave', $leaveId);
        $this->leaves->reject($leaveId, $tenantId, $adminId, $reason !== '' ? $reason : null);

        AuditLog::record($tenantId, $adminId, 'leave.reject', 'leave', $leaveId);

        // The reason travels with the refusal. "Rejected" on its own sends the
        // employee to ask a manager what they should have done differently.
        $bodyAr = $reason !== ''
            ? 'تم رفض طلب الإجازة الخاص بك. السبب: '.$reason
            : 'تم رفض طلب الإجازة الخاص بك.';

        $this->tellEmployee(
            $tenantId, $leaveId, 'reject',
            'Leave Rejected', 'تم رفض الإجازة',
            'Your leave request has been rejected.', $bodyAr,
        );

        return ApiResponse::success(['message' => 'Leave rejected']);
    }

    /**
     * A manager reading somebody's balance, or their own when they have an
     * employee record and did not name anybody.
     */
    public function balance(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);
        $requested = Value::int($request->query('employee_id'));

        if ($requested > 0) {
            if (! self::holds($admin, 'manage_leaves')) {
                throw new ApiFailure(__('messages.insufficient_permissions'), 403, 'forbidden');
            }

            $employeeId = $requested;
        } else {
            $employeeId = Value::int(
                DB::table('employees')->where('admin_id', $admin->id)->where('tenant_id', $tenantId)->value('id')
            );
        }

        $exists = $employeeId > 0 && DB::table('employees')
            ->where('id', $employeeId)->where('tenant_id', $tenantId)->exists();

        if (! $exists) {
            throw new ApiFailure(__('messages.employee_profile_not_found'), 404, 'employee_profile_not_found');
        }

        $year = Value::int($request->query('year')) ?: (int) substr(TenantClock::date($tenantId), 0, 4);

        return ApiResponse::success($this->balances->forYear($employeeId, $tenantId, $year));
    }

    public function convertToAbsence(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);

        // Two permissions, because this both cancels leave and writes
        // attendance — either alone would let somebody reach past their remit.
        if (! self::holds($admin, 'manage_leaves') || ! self::holds($admin, 'manage_attendance')) {
            throw new ApiFailure(__('messages.insufficient_permissions'), 403, 'forbidden');
        }

        $leaveId = self::leaveId($request);
        $reason = trim(Value::string($request->input('reason'))) ?: null;

        $result = $this->convert->execute($leaveId, $tenantId, $admin->id, $reason);

        AuditLog::record($tenantId, $admin->id, 'leave.convert_to_absence', 'leave', $leaveId, [
            'days' => $result['days'],
        ]);

        $this->notifier->notifyEmployee(
            $tenantId,
            $result['employee_id'],
            'leave',
            'Leave Changed to Absence',
            'تم تحويل الإجازة إلى غياب',
            'Your leave was changed to absence.',
            'تم تحويل إجازتك إلى غياب.',
            ['leave_id' => (string) $leaveId, 'action' => 'convert_to_absence'],
        );

        return ApiResponse::success(['message' => 'Leave converted to absence', 'days' => $result['days']]);
    }

    /**
     * A standing weekly non-working day for a branch, or the whole company.
     */
    public function createRecurring(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $dayOfWeek = Value::string($request->input('day_of_week'));
        $days = ['saturday', 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

        if (! in_array($dayOfWeek, $days, true)) {
            throw new ApiFailure('Invalid day_of_week', 422, 'invalid_day_of_week');
        }

        $id = (int) DB::table('recurring_leaves')->insertGetId([
            'tenant_id' => $tenantId,
            'branch_id' => Value::int($request->input('branch_id')) ?: null,
            'day_of_week' => $dayOfWeek,
            'type' => Value::string($request->input('type'), 'weekly_off') ?: 'weekly_off',
            'reason' => Value::nullableString($request->input('reason')),
            'is_active' => 1,
        ]);

        return ApiResponse::success(['id' => $id, 'message' => 'Recurring leave created']);
    }

    private function tellEmployee(
        int $tenantId,
        int $leaveId,
        string $action,
        string $titleEn,
        string $titleAr,
        string $bodyEn,
        string $bodyAr,
    ): void {
        $employeeId = Value::int(
            DB::table('leaves')->where('id', $leaveId)->where('tenant_id', $tenantId)->value('employee_id')
        );

        if ($employeeId <= 0) {
            return;
        }

        $this->notifier->notifyEmployee(
            $tenantId, $employeeId, 'leave', $titleEn, $titleAr, $bodyEn, $bodyAr,
            ['leave_id' => (string) $leaveId, 'action' => $action, 'type' => 'leave'],
        );
    }

    /**
     * @param  array<string, mixed>  $result
     */
    private static function firstSplitId(array $result): ?int
    {
        $leaves = $result['leaves'] ?? null;

        if (! is_array($leaves)) {
            return null;
        }

        foreach ($leaves as $leave) {
            if (is_array($leave) && $leave['id'] !== null) {
                return Value::int($leave['id']);
            }
        }

        return null;
    }

    private static function holds(Admin $admin, string $permission): bool
    {
        return Permissions::holds($admin->id, $admin->tenant_id ?? 0, $admin->role, $permission);
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        return $admin;
    }

    private static function leaveId(Request $request): int
    {
        $leaveId = Value::int($request->input('leave_id')) ?: Value::int($request->query('id'));

        if ($leaveId <= 0) {
            throw new ApiFailure('leave_id is required', 422, 'leave_id_required');
        }

        return $leaveId;
    }
}
