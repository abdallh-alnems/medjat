<?php

declare(strict_types=1);

namespace App\Http\Controllers\Payroll;

use App\Domain\Payroll\PayrollCalculator;
use App\Domain\Time\TenantClock;
use App\Exceptions\ApiFailure;
use App\Support\Value;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * Port of api/app/payroll/get_slip_pdf.php.
 *
 * The manager's copy of somebody's payslip. Computed with the same as-of clamp
 * the financial tab uses, so the download matches the screen it was started
 * from rather than quietly showing a fuller month.
 */
final class PayslipPdfController
{
    public function __construct(private readonly PayrollCalculator $calculator) {}

    public function __invoke(Request $request): BinaryFileResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->query('employee_id'));
        $month = Value::string($request->query('month'), '') ?: substr(TenantClock::date($tenantId), 0, 7);

        if ($employeeId <= 0) {
            throw new ApiFailure('Employee ID required', 422, 'employee_id_required');
        }
        if (preg_match('/^\d{4}-\d{2}$/', $month) !== 1) {
            throw new ApiFailure('Invalid month format (expected YYYY-MM)', 422, 'invalid_month_format_expected_yyyy');
        }

        $employee = DB::table('employees as e')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->where('e.id', $employeeId)->where('e.tenant_id', $tenantId)
            ->first(['e.*', 'b.name as branch_name']);

        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        $tenant = DB::table('tenants')->where('id', $tenantId)->first();

        if ($tenant === null) {
            throw new ApiFailure('Tenant not found', 404, 'not_found');
        }

        $breakdown = $this->calculator->calculate($employeeId, $month, $tenantId, TenantClock::date($tenantId));

        return PayslipDownload::stream(
            self::columns($tenant),
            self::columns($employee),
            $breakdown,
            $month,
            $employeeId,
        );
    }

    /**
     * @return array<string, mixed>
     */
    private static function columns(object $row): array
    {
        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }
}
