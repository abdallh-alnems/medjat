<?php

declare(strict_types=1);

namespace App\Http\Controllers\Reports;

use App\Domain\Payroll\PayrollLedger;
use App\Domain\Reports\AttendanceReports;
use App\Domain\Reports\StaffReports;
use App\Domain\Time\TenantClock;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Http\Middleware\RequireBranchAccess;
use App\Models\Admin;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Ports of api/app/reports/*.php.
 *
 * Every report here is scoped by branch when one is named, and an
 * administrator pinned to a branch cannot ask about another one — the same
 * rule the screens themselves apply, enforced where it counts.
 */
final class ReportController
{
    public function __construct(private readonly PayrollLedger $payroll) {}

    public function attendance(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        [$from, $to] = $this->window($request, $tenantId);
        $branchId = $this->branch($request);

        return ApiResponse::success([
            'start_date' => $from,
            'end_date' => $to,
            'items' => AttendanceReports::byRange($tenantId, $from, $to, $branchId),
            'summary' => AttendanceReports::summary($tenantId, $from, $to, $branchId),
        ]);
    }

    public function employees(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = $this->branch($request);

        return ApiResponse::success([
            'items' => StaffReports::employees($tenantId, $branchId),
            'summary' => StaffReports::employeeSummary($tenantId, $branchId),
        ]);
    }

    public function leaves(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        [$from, $to] = $this->window($request, $tenantId);
        $branchId = $this->branch($request);

        return ApiResponse::success([
            'start_date' => $from,
            'end_date' => $to,
            'items' => StaffReports::leaves(
                $tenantId, $from, $to, $branchId,
                Value::string($request->query('status')) ?: null,
            ),
            'summary' => StaffReports::leaveSummary($tenantId, $from, $to, $branchId),
        ]);
    }

    /**
     * Overtime and lateness, with an optional drill-down.
     *
     * Naming an employee adds the days behind their totals, which is what turns
     * a row somebody disputes into a conversation about a particular Tuesday.
     */
    public function overtimeAndLate(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        [$from, $to] = $this->window($request, $tenantId);
        $branchId = $this->branch($request);

        if ($from > $to) {
            throw new ApiFailure('Start date must be on or before end date', 422, 'start_date_before_end_date');
        }

        $sort = Value::string($request->query('sort'), 'overtime') ?: 'overtime';

        if (! in_array($sort, ['overtime', 'late', 'name'], true)) {
            throw new ApiFailure('Invalid sort', 422, 'invalid_sort');
        }

        $payload = [
            'start_date' => $from,
            'end_date' => $to,
            'items' => AttendanceReports::overtimeAndLate($tenantId, $from, $to, $branchId, $sort),
            'summary' => AttendanceReports::overtimeAndLateSummary($tenantId, $from, $to, $branchId),
        ];

        $employeeId = Value::int($request->query('employee_id'));

        if ($employeeId > 0) {
            $payload['days'] = AttendanceReports::overtimeAndLateDaily($tenantId, $employeeId, $from, $to);
        }

        return ApiResponse::success($payload);
    }

    public function payroll(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = $this->branch($request);
        $month = Value::string($request->query('month')) ?: substr(TenantClock::date($tenantId), 0, 7);

        if (preg_match('/^\d{4}-\d{2}$/', $month) !== 1) {
            throw new ApiFailure('Invalid month format. Use YYYY-MM', 422, 'invalid_month');
        }

        return ApiResponse::success([
            'month' => $month,
            'items' => $this->payroll->reportRows($tenantId, $month, $branchId),
            'summary' => $this->payroll->summary($tenantId, $month, $branchId),
        ]);
    }

    /**
     * The date window, defaulting to this month so far in the company's own
     * calendar.
     *
     * @return array{0: string, 1: string}
     */
    private function window(Request $request, int $tenantId): array
    {
        $today = TenantClock::date($tenantId);

        $from = Value::string($request->query('start_date')) ?: substr($today, 0, 7).'-01';
        $to = Value::string($request->query('end_date')) ?: $today;

        foreach ([$from, $to] as $date) {
            if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) !== 1) {
                throw new ApiFailure('Dates must be YYYY-MM-DD', 422, 'invalid_date');
            }
        }

        return [$from, $to];
    }

    private function branch(Request $request): ?int
    {
        $branchId = Value::int($request->query('branch_id')) ?: null;

        if ($branchId !== null) {
            RequireBranchAccess::assert(self::admin($request), $branchId);
        }

        return $branchId;
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
