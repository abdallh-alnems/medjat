<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Domain\Payslip;

use App\Support\Value;
use Illuminate\Support\Facades\Storage;
use Mpdf\Mpdf;
use Mpdf\Output\Destination;
use RuntimeException;

/**
 * A month's payslip as an A4 PDF.
 *
 * Employees hand these to banks and landlords, so it prints the whole story:
 * base, the prorated figure when the cycle is partial, every bonus and
 * deduction line by name, and the net. A slip that shows only totals is one
 * nobody can check, and checking is the entire point.
 */
final class PayslipPdf
{
    /**
     * @param  array<string, mixed>  $tenant
     * @param  array<string, mixed>  $employee
     * @param  array<string, mixed>  $breakdown
     * @return string Absolute path to the written file.
     */
    public static function generate(array $tenant, array $employee, array $breakdown, string $month): string
    {
        $tenantId = Value::int($tenant['id'] ?? null);
        $employeeId = Value::int($employee['id'] ?? null);

        $directory = Storage::disk('uploads')->path('payslips/'.$tenantId);
        $temp = Storage::disk('uploads')->path('.mpdf_tmp');

        foreach ([$directory, $temp] as $path) {
            if (! is_dir($path) && ! mkdir($path, 0755, true) && ! is_dir($path)) {
                throw new RuntimeException('Failed to create payslip directory: '.$path);
            }
        }

        $pdf = new Mpdf([
            'mode' => 'utf-8',
            'format' => 'A4',
            'margin_left' => 16,
            'margin_right' => 16,
            'margin_top' => 18,
            'margin_bottom' => 18,
            'directionality' => 'rtl',
            'autoScriptToLang' => true,
            'autoLangToFont' => true,
            'tempDir' => $temp,
        ]);

        $pdf->SetTitle('قسيمة راتب '.Value::string($employee['name'] ?? null).' - '.$month);
        $pdf->WriteHTML(PayslipHtml::render($tenant, $employee, $breakdown, $month));

        // The timestamp keeps a regenerated slip from overwriting one somebody
        // may still be downloading.
        $path = $directory.'/payslip_'.$employeeId.'_'.$month.'_'.time().'.pdf';
        $pdf->Output($path, Destination::FILE);

        return $path;
    }
}
