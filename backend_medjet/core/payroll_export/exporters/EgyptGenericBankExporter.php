<?php

final class EgyptGenericBankExporter implements PayrollExporter {
    public function key(): string { return 'eg_generic_bank'; }
    public function label(): string { return 'ملف بنكي عام (مصر)'; }
    public function countryCode(): string { return 'EG'; }
    public function fileExtension(): string { return 'csv'; }
    public function mimeType(): string { return 'text/csv; charset=utf-8'; }

    public function write($output, PayrollExportContext $ctx): void {
        fputs($output, "\xEF\xBB\xBF");
        fputcsv($output, ['الاسم','اسم البنك','رقم الحساب','IBAN','المبلغ الصافي','العملة','الشهر']);
        foreach ($ctx->rows as $row) {
            fputcsv($output, [
                $row['employee_name'],
                $row['bank_name'] ?? '',
                $row['bank_account_number'] ?? '',
                $row['bank_iban'] ?? '',
                number_format((float) $row['net_salary'], 2, '.', ''),
                $ctx->currency,
                $ctx->month,
            ]);
        }
    }
}
