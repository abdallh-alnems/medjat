<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Modules\Payroll\Domain\PayrollCalculator;
use App\Modules\Payroll\Domain\PayrollLedger;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * Port of api/app/payroll/get_slip.php.
 *
 * An employee's own payslip. When payroll has not been run for the month there
 * is no saved slip, and the answer is a live preview rather than an error —
 * somebody should always be able to see what they have earned so far, marked
 * clearly as not yet paid.
 *
 * `format=pdf` returns the same slip as a file. The employee app's download
 * button asks for that, and without it the app saved a JSON body under a .pdf
 * name — a file no reader could open.
 */
final class MySlipController
{
    public function __construct(
        private readonly PayrollCalculator $calculator,
        private readonly PayrollLedger $ledger,
    ) {}

    public function __invoke(Request $request): JsonResponse|BinaryFileResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employee = $request->attributes->get('employee');
        if (! $employee instanceof Employee) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        $employeeId = $employee->id;
        $month = Value::string($request->query('month'), '') ?: substr(TenantClock::date($tenantId), 0, 7);
        $wantsPdf = strtolower(Value::string($request->query('format'))) === 'pdf';

        $slip = $this->ledger->slip($employeeId, $month, $tenantId);
        $today = TenantClock::date($tenantId);

        if ($slip === null) {
            $live = $this->calculator->calculate($employeeId, $month, $tenantId, $today);

            if ($live === []) {
                throw new ApiFailure(__('messages.payslip_not_found'), 404, 'not_found');
            }

            if ($wantsPdf) {
                return $this->download($tenantId, $employeeId, $live, $month);
            }

            return ApiResponse::success($live + [
                'status' => 'live',
                'deductions_breakdown' => $live['deductions_breakdown'] ?? [],
                'bonuses_breakdown' => $live['bonuses_breakdown'] ?? [],
            ]);
        }

        $breakdown = self::decode($slip['breakdown'] ?? null);

        if ($wantsPdf) {
            // The frozen figures, so the PDF matches what was approved. A slip
            // saved before breakdowns were stored falls back to a live
            // calculation — which is what its screen shows anyway.
            $figures = $breakdown ?? $this->calculator->calculate($employeeId, $month, $tenantId, $today);

            return $this->download($tenantId, $employeeId, $figures, $month);
        }

        $slip['breakdown'] = $breakdown;
        $slip['deductions_breakdown'] = $breakdown['deductions_breakdown'] ?? [];
        $slip['bonuses_breakdown'] = $breakdown['bonuses_breakdown'] ?? [];

        return ApiResponse::success($slip);
    }

    /**
     * @param  array<string, mixed>  $breakdown
     */
    private function download(int $tenantId, int $employeeId, array $breakdown, string $month): BinaryFileResponse
    {
        $tenant = DB::table('tenants')->where('id', $tenantId)->first();

        if ($tenant === null) {
            throw new ApiFailure(__('messages.tenant_not_found'), 404, 'not_found');
        }

        $employee = DB::table('employees as e')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->where('e.id', $employeeId)->where('e.tenant_id', $tenantId)
            ->first(['e.*', 'b.name as branch_name']);

        if ($employee === null) {
            throw new ApiFailure(__('messages.employee_not_found'), 404, 'not_found');
        }

        return PayslipDownload::stream(
            self::columns($tenant),
            self::columns($employee),
            $breakdown,
            $month,
            $employeeId,
        );
    }

    /**
     * @return array<string, mixed>|null
     */
    private static function decode(mixed $raw): ?array
    {
        if (! is_string($raw) || $raw === '') {
            return null;
        }

        $decoded = json_decode($raw, true);

        if (! is_array($decoded)) {
            return null;
        }

        /** @var array<string, mixed> $breakdown */
        $breakdown = $decoded;

        return $breakdown;
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
