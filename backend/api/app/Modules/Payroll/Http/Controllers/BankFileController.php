<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Payroll\Domain\Export\BankExportContext;
use App\Modules\Payroll\Domain\Export\BankExporterRegistry;
use App\Modules\Payroll\Domain\PayrollLedger;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Port of api/app/payroll/bank_file_preview.php and export_bank_file.php.
 *
 * Only approved slips are payable, and only those with somewhere to pay to. The
 * preview exists so nobody discovers the second half at the bank: it names the
 * people with no account on file rather than quietly dropping them from the
 * transfer.
 */
final class BankFileController
{
    public function __construct(private readonly PayrollLedger $ledger) {}

    public function preview(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $month = self::month($request);
        $branchId = Value::int($request->query('branch_id')) ?: null;

        $rows = $this->ledger->approvedForBankFile($tenantId, $month, $branchId);
        [$ready, $missing] = self::split($rows);

        $total = 0.0;
        foreach ($ready as $row) {
            $total += Value::float($row['net_salary'] ?? null);
        }

        return ApiResponse::success([
            'month' => $month,
            'total_employees' => count($rows),
            'total_amount' => round($total, 2),
            'ready_count' => count($ready),
            'missing_bank_count' => count($missing),
            'missing' => $missing,
            'available_exporters' => BankExporterRegistry::availableFor(self::tenant($tenantId)),
        ]);
    }

    public function download(Request $request): StreamedResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $adminId = $admin->id;
        $month = self::month($request);
        $branchId = Value::int($request->query('branch_id')) ?: null;

        $tenant = self::tenant($tenantId);
        $exporter = BankExporterRegistry::resolve(
            Value::string($request->query('exporter'), '') ?: null,
            $tenant,
        );

        if ($exporter === null) {
            throw new ApiFailure(
                'No payroll exporter available for this country/format',
                422,
                'payroll_exporter_available_country_format',
            );
        }

        [$ready] = self::split($this->ledger->approvedForBankFile($tenantId, $month, $branchId));

        $context = new BankExportContext($ready, $tenant, $month, Value::string($tenant['currency'] ?? null, 'EGP'));

        AuditLog::record($tenantId, $adminId, 'payroll.export_bank_file', null, null, [
            'month' => $month,
            'exporter' => $exporter->key(),
            'country' => $tenant['country_code'] ?? null,
        ]);

        $filename = "payroll_{$exporter->key()}_{$month}.{$exporter->fileExtension()}";

        return new StreamedResponse(
            static function () use ($exporter, $context): void {
                $output = fopen('php://output', 'w');

                if ($output === false) {
                    return;
                }

                $exporter->write($output, $context);
                fclose($output);
            },
            200,
            [
                'Content-Type' => $exporter->mimeType(),
                'Content-Disposition' => "attachment; filename=\"{$filename}\"",
                'X-Content-Type-Options' => 'nosniff',
            ],
        );
    }

    /**
     * Payable rows and unpayable people, kept apart.
     *
     * @param  list<array<string, mixed>>  $rows
     * @return array{0: list<array<string, mixed>>, 1: list<array{id: mixed, name: mixed}>}
     */
    private static function split(array $rows): array
    {
        $ready = [];
        $missing = [];

        foreach ($rows as $row) {
            $account = Value::string($row['bank_account_number'] ?? null);
            $iban = Value::string($row['bank_iban'] ?? null);

            if ($account !== '' || $iban !== '') {
                $ready[] = $row;
            } else {
                $missing[] = ['id' => $row['employee_id'] ?? null, 'name' => $row['employee_name'] ?? null];
            }
        }

        return [$ready, $missing];
    }

    /**
     * @return array<string, mixed>
     */
    private static function tenant(int $tenantId): array
    {
        $tenant = DB::table('tenants')->where('id', $tenantId)->first();

        if ($tenant === null) {
            throw new ApiFailure('Tenant not found', 404, 'not_found');
        }

        /** @var array<string, mixed> $columns */
        $columns = (array) $tenant;

        return $columns;
    }

    private static function month(Request $request): string
    {
        $month = Value::string($request->query('month'));

        if ($month === '') {
            throw new ApiFailure('month is required', 422, 'month_required');
        }

        if (preg_match('/^\d{4}-\d{2}$/', $month) !== 1) {
            throw new ApiFailure('Invalid month format. Use YYYY-MM', 400, 'invalid_month_format_yyyy_mm');
        }

        return $month;
    }
}
