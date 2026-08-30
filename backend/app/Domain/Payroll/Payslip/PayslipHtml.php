<?php

declare(strict_types=1);

namespace App\Domain\Payroll\Payslip;

use App\Support\Value;

/**
 * The payslip's markup, kept apart from the PDF engine so it can be read,
 * changed, and asserted on without rendering anything.
 */
final class PayslipHtml
{
    /**
     * @param  array<string, mixed>  $tenant
     * @param  array<string, mixed>  $employee
     * @param  array<string, mixed>  $breakdown
     */
    public static function render(array $tenant, array $employee, array $breakdown, string $month): string
    {
        $currency = self::clean(Value::string($tenant['currency'] ?? null, 'EGP'));
        $company = self::clean(Value::string($tenant['name'] ?? null));
        $name = self::clean(Value::string($employee['name'] ?? null));
        $jobTitle = self::clean(Value::string($employee['job_title'] ?? null) ?: '—');
        $branch = self::clean(Value::string($employee['branch_name'] ?? null) ?: '—');
        $hireDate = self::clean(Value::string($employee['hire_date'] ?? null) ?: '—');
        $identity = self::clean(
            Value::string($employee['national_id'] ?? null)
                ?: (Value::string($employee['iqama_number'] ?? null) ?: '—')
        );
        $iban = self::clean(Value::string($employee['bank_iban'] ?? null) ?: '—');
        $bank = self::clean(Value::string($employee['bank_name'] ?? null) ?: '—');

        $base = Value::float($breakdown['base_salary'] ?? null);
        $prorated = Value::float($breakdown['prorated_base_salary'] ?? null);
        $totalBonuses = Value::float($breakdown['total_bonuses'] ?? null);
        $totalDeductions = Value::float($breakdown['total_deductions'] ?? null);
        $daysInCycle = Value::int($breakdown['days_in_cycle'] ?? null);
        $daysElapsed = Value::int($breakdown['days_elapsed'] ?? null);

        // A cycle still running shows what has been earned so far and says so.
        // Printing a full month's net halfway through the month would be a
        // number the employee is not owed yet.
        $partial = $daysInCycle > 0 && $daysElapsed > 0 && $daysElapsed < $daysInCycle;
        $resultLabel = $partial ? 'المستحق حتى اليوم' : 'صافي الراتب';
        $result = Value::float($breakdown[$partial ? 'earned_to_date' : 'net_salary'] ?? null);

        $today = date('Y-m-d');
        $cycleFrom = self::clean(Value::string($breakdown['cycle_start'] ?? null));
        $cycleTo = self::clean(Value::string($breakdown['cycle_end'] ?? null));

        $period = $cycleFrom !== '' && $cycleTo !== ''
            ? '<div class="meta">فترة الاستحقاق: '.$cycleFrom.' → '.$cycleTo.'</div>'
            : '';

        $proratedRow = $partial
            ? '<tr><td>الأساسي حتى اليوم ('.$daysElapsed.'/'.$daysInCycle.')</td>'
                .'<td class="num">'.self::money($prorated).'</td></tr>'
            : '';

        $bonusRows = self::lines($breakdown['bonuses_breakdown'] ?? [], '+', 'pos');
        $deductionRows = self::lines($breakdown['deductions_breakdown'] ?? [], '-', 'neg');
        $empty = '<tr><td colspan="3" class="muted">— لا يوجد —</td></tr>';

        $bonusRowsHtml = $bonusRows !== '' ? $bonusRows : $empty;
        $deductionRowsHtml = $deductionRows !== '' ? $deductionRows : $empty;

        $baseStr = self::money($base).' '.$currency;
        $bonusTotalStr = self::money($totalBonuses).' '.$currency;
        $deductionTotalStr = self::money($totalDeductions).' '.$currency;
        $resultStr = self::money($result).' '.$currency;
        $styles = self::styles();

        return <<<HTML
        <!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
        <style>{$styles}</style></head><body>

        <div class="header">
          <div class="left">
            <div class="company">{$company}</div>
            <div class="meta">تاريخ الإصدار: {$today}</div>
          </div>
        </div>

        <div class="title">قسيمة راتب — {$month}</div>
        {$period}

        <div class="section">
          <h3>بيانات الموظف</h3>
          <table class="info-table">
            <tr><td class="label">الاسم</td><td>{$name}</td>
                <td class="label">المسمى الوظيفي</td><td>{$jobTitle}</td></tr>
            <tr><td class="label">الفرع</td><td>{$branch}</td>
                <td class="label">تاريخ التعيين</td><td>{$hireDate}</td></tr>
            <tr><td class="label">رقم الهوية</td><td>{$identity}</td>
                <td class="label">البنك</td><td>{$bank}</td></tr>
            <tr><td class="label">IBAN</td><td colspan="3">{$iban}</td></tr>
          </table>
        </div>

        <div class="section">
          <h3>الراتب الأساسي</h3>
          <table>
            <tr><td>الراتب الأساسي الشهري</td><td class="num">{$baseStr}</td></tr>
            {$proratedRow}
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
            <tr class="net-row"><td>{$resultLabel}</td><td class="num">{$resultStr}</td></tr>
          </table>
        </div>

        <div class="footer">
          هذه القسيمة مولّدة آلياً من نظام {$company} بتاريخ {$today}.
        </div>

        </body></html>
        HTML;
    }

    /**
     * @param  mixed  $items
     */
    private static function lines($items, string $sign, string $class): string
    {
        if (! is_array($items)) {
            return '';
        }

        $html = '';

        foreach ($items as $item) {
            if (! is_array($item)) {
                continue;
            }

            $type = self::clean(self::typeLabel(Value::string($item['type'] ?? null)));
            $description = self::clean(Value::string($item['description'] ?? null) ?: '—');
            $amount = self::money(Value::float($item['amount'] ?? null));

            $html .= '<tr><td>'.$type.'</td><td>'.$description.'</td>'
                .'<td class="num '.$class.'">'.$sign.$amount.'</td></tr>';
        }

        return $html;
    }

    private static function typeLabel(string $type): string
    {
        return match ($type) {
            'absence' => 'غياب',
            'late' => 'تأخير',
            'loan' => 'قسط قرض',
            'social_insurance' => 'تأمينات اجتماعية',
            'income_tax' => 'ضريبة دخل',
            'overtime' => 'إضافي',
            'manual' => 'يدوي',
            'allowance' => 'بدل',
            'suspension' => 'إيقاف عن العمل',
            'permission_hourly' => 'إذن',
            'leave_encashment' => 'تصفية إجازات',
            default => $type,
        };
    }

    /** Whole amounts print without decimals; the rest keep two. */
    private static function money(float $amount): string
    {
        return number_format($amount, $amount === floor($amount) ? 0 : 2);
    }

    private static function clean(string $text): string
    {
        return htmlspecialchars($text, ENT_QUOTES, 'UTF-8');
    }

    private static function styles(): string
    {
        return <<<'CSS'
        body { font-size: 11pt; line-height: 1.6; color: #1a1a1a; }
        .header { display: table; width: 100%; border-bottom: 2px solid #333; padding-bottom: 8px; margin-bottom: 10px; }
        .header .left { display: table-cell; vertical-align: middle; text-align: left; }
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
        .totals td { font-weight: 600; }
        .net-row td { font-size: 13pt; font-weight: 700; color: #2E7D6B; border-top: 2px solid #2E7D6B; border-bottom: none; padding-top: 10px; }
        .info-table td { font-size: 10pt; padding: 4px 8px; border: none; }
        .info-table .label { color: #666; width: 30%; }
        .footer { margin-top: 30px; font-size: 9pt; color: #888; text-align: center; border-top: 1px solid #ddd; padding-top: 8px; }
        CSS;
    }
}
