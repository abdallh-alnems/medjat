<?php

/**
 * Renders an employee's monthly payroll slip to an A4 PDF using mpdf, mirroring
 * the LetterPdfService setup (RTL, Arabic-friendly fonts, company branding).
 *
 * The slip lists base salary, prorated amount when partial, every bonus and
 * deduction line, statutory items, and the final net — suitable for sharing
 * with the employee, archiving, or submission to banks for credit checks.
 */
final class PayslipPdfService {
    public static function generate(
        array $tenant,
        array $employee,
        array $breakdown,
        string $month
    ): string {
        if (!class_exists('\\Mpdf\\Mpdf')) {
            throw new RuntimeException('PDF engine not installed. Run: composer require mpdf/mpdf');
        }

        $tenantId = (int) ($tenant['id'] ?? 0);
        $outDir = __DIR__ . '/../uploads/payslips/' . $tenantId . '/';
        if (!is_dir($outDir) && !mkdir($outDir, 0755, true) && !is_dir($outDir)) {
            throw new RuntimeException('Failed to create payslips directory');
        }
        $tmpDir = __DIR__ . '/../uploads/.mpdf_tmp';
        if (!is_dir($tmpDir)) {
            @mkdir($tmpDir, 0755, true);
        }

        $html = self::renderHtml($tenant, $employee, $breakdown, $month);

        $mpdf = new \Mpdf\Mpdf([
            'mode' => 'utf-8',
            'format' => 'A4',
            'margin_left' => 16,
            'margin_right' => 16,
            'margin_top' => 18,
            'margin_bottom' => 18,
            'directionality' => 'rtl',
            'autoScriptToLang' => true,
            'autoLangToFont' => true,
            'tempDir' => $tmpDir,
        ]);
        $mpdf->SetTitle('قسيمة راتب ' . ($employee['name'] ?? '') . ' - ' . $month);
        $mpdf->WriteHTML($html);

        $fileName = 'payslip_' . (int) $employee['id'] . '_' . $month . '_' . time() . '.pdf';
        $filePath = $outDir . $fileName;
        $mpdf->Output($filePath, \Mpdf\Output\Destination::FILE);

        return $filePath;
    }

    private static function renderHtml(array $tenant, array $employee, array $b, string $month): string {
        $currency = self::clean($tenant['currency'] ?? 'EGP');
        $companyName = self::clean($tenant['name'] ?? '');
        $employeeName = self::clean($employee['name'] ?? '');
        $jobTitle = self::clean($employee['job_title'] ?? '—');
        $branchName = self::clean($employee['branch_name'] ?? '—');
        $hireDate = self::clean($employee['hire_date'] ?? '—');
        $nationalId = self::clean($employee['national_id'] ?? ($employee['iqama_number'] ?? '—'));
        $iban = self::clean($employee['bank_iban'] ?? '—');
        $bankName = self::clean($employee['bank_name'] ?? '—');

        $base = (float) ($b['base_salary'] ?? 0);
        $prorated = (float) ($b['prorated_base_salary'] ?? 0);
        $totalBonuses = (float) ($b['total_bonuses'] ?? 0);
        $totalDeductions = (float) ($b['total_deductions'] ?? 0);
        $net = (float) ($b['net_salary'] ?? 0);
        $earned = (float) ($b['earned_to_date'] ?? 0);
        $daysInCycle = (int) ($b['days_in_cycle'] ?? 0);
        $daysElapsed = (int) ($b['days_elapsed'] ?? 0);
        $partial = $daysInCycle > 0 && $daysElapsed > 0 && $daysElapsed < $daysInCycle;
        $cycleFrom = self::clean($b['cycle_start'] ?? '');
        $cycleTo = self::clean($b['cycle_end'] ?? '');

        $logo = self::imageTag($tenant['logo_url'] ?? null, 70);
        $today = date('Y-m-d');

        // Rows for bonuses and deductions
        $bonusRows = self::rowsHtml($b['bonuses_breakdown'] ?? [], '+', '#0E7C66');
        $deductionRows = self::rowsHtml($b['deductions_breakdown'] ?? [], '-', '#C0392B');
        $bonusRowsHtml = $bonusRows !== '' ? $bonusRows
            : '<tr><td colspan="3" class="muted">— لا يوجد —</td></tr>';
        $deductionRowsHtml = $deductionRows !== '' ? $deductionRows
            : '<tr><td colspan="3" class="muted">— لا يوجد —</td></tr>';

        $proratedBlock = $partial
            ? '<tr><td>الأساسي حتى اليوم (' . $daysElapsed . '/' . $daysInCycle . ')</td>'
              . '<td class="num">' . self::money($prorated) . '</td></tr>'
            : '';
        $resultLabel = $partial ? 'المستحق حتى اليوم' : 'صافي الراتب';
        $resultAmount = $partial ? $earned : $net;

        // Pre-compute strings since heredoc only interpolates simple variables.
        $baseStr = self::money($base) . ' ' . $currency;
        $bonusTotalStr = self::money($totalBonuses) . ' ' . $currency;
        $deductionTotalStr = self::money($totalDeductions) . ' ' . $currency;
        $resultStr = self::money($resultAmount) . ' ' . $currency;

        $periodLine = '';
        if ($cycleFrom !== '' && $cycleTo !== '') {
            $periodLine = '<div class="meta">فترة الاستحقاق: ' . $cycleFrom . ' → ' . $cycleTo . '</div>';
        }

        return <<<HTML
<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<style>
  body { font-size: 11pt; line-height: 1.6; color: #1a1a1a; }
  .header { display: table; width: 100%; border-bottom: 2px solid #333; padding-bottom: 8px; margin-bottom: 10px; }
  .header .left, .header .right { display: table-cell; vertical-align: middle; }
  .header .right { text-align: left; }
  .company { font-size: 16pt; font-weight: bold; }
  .title { text-align: center; font-size: 14pt; font-weight: bold; margin: 10px 0 6px; }
  .meta { font-size: 9.5pt; color: #555; text-align: center; }
  .section { margin-top: 14px; }
  .section h3 { font-size: 12pt; margin: 0 0 6px; padding: 6px 8px; background: #f4f5f7; border-right: 3px solid #2E7D6B; }
  table { width: 100%; border-collapse: collapse; font-size: 10.5pt; }
  td, th { padding: 6px 8px; border-bottom: 1px solid #eee; }
  th { background: #fafbfc; text-align: right; font-weight: 600; }
  .num { text-align: left; font-family: monospace; font-weight: 600; }
  .pos { color: #0E7C66; }
  .neg { color: #C0392B; }
  .muted { color: #999; text-align: center; font-style: italic; }
  .totals { margin-top: 10px; }
  .totals td { font-weight: 600; }
  .net-row td { font-size: 13pt; font-weight: 700; color: #2E7D6B; border-top: 2px solid #2E7D6B; border-bottom: none; padding-top: 10px; }
  .info-table td { font-size: 10pt; padding: 4px 8px; border: none; }
  .info-table .label { color: #666; width: 30%; }
  .footer { margin-top: 30px; font-size: 9pt; color: #888; text-align: center; border-top: 1px solid #ddd; padding-top: 8px; }
</style></head><body>

<div class="header">
  <div class="right">{$logo}</div>
  <div class="left">
    <div class="company">{$companyName}</div>
    <div class="meta">تاريخ الإصدار: {$today}</div>
  </div>
</div>

<div class="title">قسيمة راتب — {$month}</div>
{$periodLine}

<div class="section">
  <h3>بيانات الموظف</h3>
  <table class="info-table">
    <tr><td class="label">الاسم</td><td>{$employeeName}</td>
        <td class="label">المسمى الوظيفي</td><td>{$jobTitle}</td></tr>
    <tr><td class="label">الفرع</td><td>{$branchName}</td>
        <td class="label">تاريخ التعيين</td><td>{$hireDate}</td></tr>
    <tr><td class="label">رقم الهوية</td><td>{$nationalId}</td>
        <td class="label">البنك</td><td>{$bankName}</td></tr>
    <tr><td class="label">IBAN</td><td colspan="3">{$iban}</td></tr>
  </table>
</div>

<div class="section">
  <h3>الراتب الأساسي</h3>
  <table>
    <tr><td>الراتب الأساسي الشهري</td>
        <td class="num">{$baseStr}</td></tr>
    {$proratedBlock}
  </table>
</div>

<div class="section">
  <h3>الإضافات والمكافآت</h3>
  <table>
    <tr><th style="width:25%">النوع</th><th>الوصف</th><th class="num" style="width:25%">المبلغ</th></tr>
    {$bonusRowsHtml}
    <tr class="totals"><td colspan="2">إجمالي الإضافات</td>
        <td class="num pos">+{$bonusTotalStr}</td></tr>
  </table>
</div>

<div class="section">
  <h3>الخصومات</h3>
  <table>
    <tr><th style="width:25%">النوع</th><th>الوصف</th><th class="num" style="width:25%">المبلغ</th></tr>
    {$deductionRowsHtml}
    <tr class="totals"><td colspan="2">إجمالي الخصومات</td>
        <td class="num neg">-{$deductionTotalStr}</td></tr>
  </table>
</div>

<div class="section">
  <table>
    <tr class="net-row">
      <td>{$resultLabel}</td>
      <td class="num">{$resultStr}</td>
    </tr>
  </table>
</div>

<div class="footer">
  هذه القسيمة مولّدة آلياً من نظام {$companyName} بتاريخ {$today}.
</div>

</body></html>
HTML;
    }

    private static function rowsHtml(array $items, string $sign, string $color): string {
        $out = '';
        foreach ($items as $item) {
            $type = self::clean(self::translateType((string) ($item['type'] ?? '')));
            $desc = self::clean((string) ($item['description'] ?? '—'));
            $amount = (float) ($item['amount'] ?? 0);
            $cls = $sign === '+' ? 'pos' : 'neg';
            $out .= '<tr><td>' . $type . '</td><td>' . $desc . '</td>'
                  . '<td class="num ' . $cls . '">' . $sign . self::money($amount) . '</td></tr>';
        }
        return $out;
    }

    private static function translateType(string $type): string {
        switch ($type) {
            case 'absence': return 'غياب';
            case 'late': return 'تأخير';
            case 'loan': return 'قسط قرض';
            case 'social_insurance': return 'تأمينات اجتماعية';
            case 'income_tax': return 'ضريبة دخل';
            case 'overtime': return 'إضافي';
            case 'manual': return 'يدوي';
            default: return $type;
        }
    }

    private static function money(float $v): string {
        return number_format($v, $v == floor($v) ? 0 : 2);
    }

    private static function clean(?string $s): string {
        return htmlspecialchars((string) $s, ENT_QUOTES, 'UTF-8');
    }

    private static function imageTag(?string $url, int $maxHeight): string {
        if (!$url) return '';
        $safe = self::clean($url);
        return '<img src="' . $safe . '" style="max-height:' . $maxHeight . 'px;" />';
    }
}
