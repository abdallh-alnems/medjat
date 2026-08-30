<?php

declare(strict_types=1);

namespace App\Domain\Payroll\Export\Exporters;

use App\Domain\Payroll\Export\BankExportContext;
use App\Domain\Payroll\Export\BankExporter;
use App\Support\Value;

/**
 * A plain CSV most Egyptian banks will accept for a bulk transfer.
 */
final class EgyptGenericBankExporter implements BankExporter
{
    public function key(): string
    {
        return 'eg_generic_bank';
    }

    public function label(): string
    {
        return 'ملف بنكي عام (مصر)';
    }

    public function countryCode(): string
    {
        return 'EG';
    }

    public function fileExtension(): string
    {
        return 'csv';
    }

    public function mimeType(): string
    {
        return 'text/csv; charset=utf-8';
    }

    /**
     * @param  resource  $output
     */
    public function write($output, BankExportContext $context): void
    {
        // A BOM, because the people opening this file open it in Excel, and
        // Excel reads a UTF-8 CSV as mojibake without one.
        fwrite($output, "\xEF\xBB\xBF");

        fputcsv($output, ['الاسم', 'اسم البنك', 'رقم الحساب', 'IBAN', 'المبلغ الصافي', 'العملة', 'الشهر']);

        foreach ($context->rows as $row) {
            fputcsv($output, [
                Value::string($row['employee_name'] ?? null),
                Value::string($row['bank_name'] ?? null),
                Value::string($row['bank_account_number'] ?? null),
                Value::string($row['bank_iban'] ?? null),
                // Fixed two decimals with a dot, whatever the server's locale:
                // a comma here would split the amount across two columns.
                number_format(Value::float($row['net_salary'] ?? null), 2, '.', ''),
                $context->currency,
                $context->month,
            ]);
        }
    }
}
