<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Domain;

use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * Social insurance and income tax.
 *
 * Both are opt-in per company, because they are jurisdiction-specific and a
 * company that has not configured them must not have a number invented on its
 * behalf. Nothing here is enabled by default.
 */
final class StatutoryDeductions
{
    /**
     * @param  list<array<string, mixed>>  $deductions  Appended to in place.
     * @return array{insurance_employee: float, insurance_employer: float, income_tax: float, taxable_income: float}|array{}
     */
    public static function apply(float $baseSalary, array &$deductions, int $tenantId): array
    {
        $settings = DB::table('payroll_statutory_settings')->where('tenant_id', $tenantId)->first();

        if ($settings === null) {
            return [];
        }

        $insuranceOn = Value::int($settings->social_insurance_enabled) === 1;
        $taxOn = Value::int($settings->income_tax_enabled) === 1;

        if (! $insuranceOn && ! $taxOn) {
            return [];
        }

        $statutory = [
            'insurance_employee' => 0.0,
            'insurance_employer' => 0.0,
            'income_tax' => 0.0,
            'taxable_income' => 0.0,
        ];

        $insuranceEmployee = 0.0;

        if ($insuranceOn) {
            $minWage = Value::float($settings->si_min_wage);
            $maxWage = $settings->si_max_wage === null ? PHP_FLOAT_MAX : Value::float($settings->si_max_wage);
            $rate = Value::float($settings->si_employee_rate);

            // The insurable wage is clamped into the statutory band: below the
            // floor everybody contributes the floor, above the ceiling nobody
            // contributes more. Contributions are capped by law, not by salary.
            $insurableWage = max($minWage, min($baseSalary, $maxWage));
            $insuranceEmployee = round($insurableWage * ($rate / 100), 2);

            $deductions[] = [
                'type' => 'social_insurance',
                'date' => null,
                'amount' => $insuranceEmployee,
                'description' => "تأمينات اجتماعية (حصة الموظف {$rate}%)",
                'label_key' => 'payline_social_insurance',
                'label_params' => ['rate' => (string) $rate],
            ];

            $statutory['insurance_employee'] = $insuranceEmployee;
        }

        if ($taxOn) {
            $exemption = Value::float($settings->tax_personal_exemption);

            // Insurance comes off before tax: a contribution the employee never
            // received is not income they can be taxed on.
            $taxableIncome = max(0.0, $baseSalary - $insuranceEmployee - $exemption);
            $statutory['taxable_income'] = round($taxableIncome, 2);

            $brackets = $settings->income_tax_brackets;
            if (is_string($brackets)) {
                $brackets = json_decode($brackets, true);
            }

            $tax = is_array($brackets) && $taxableIncome > 0
                ? round(self::progressiveTax($taxableIncome, $brackets), 2)
                : 0.0;

            $statutory['income_tax'] = $tax;

            if ($tax > 0) {
                $deductions[] = [
                    'type' => 'income_tax',
                    'date' => null,
                    'amount' => $tax,
                    'description' => 'ضريبة دخل',
                    'label_key' => 'payline_income_tax',
                    'label_params' => [],
                ];
            }
        }

        return $statutory;
    }

    /**
     * Progressive tax on the *annual* figure, returned as the monthly share.
     *
     * The brackets are annual because that is how the law states them, so a
     * month's taxable income is annualised, taxed, and divided back. Taxing a
     * month against annual bands directly would put everybody in the lowest one.
     *
     * @param  array<array-key, mixed>  $brackets
     */
    public static function progressiveTax(float $monthlyTaxableIncome, array $brackets): float
    {
        $annual = $monthlyTaxableIncome * 12;
        $tax = 0.0;
        $previousLimit = 0.0;

        foreach ($brackets as $bracket) {
            if (! is_array($bracket)) {
                continue;
            }

            // Older seed data spells the key differently; tolerated rather than
            // silently taxed at zero.
            $upToRaw = $bracket['up_to'] ?? $bracket['upto'] ?? null;
            $upTo = $upToRaw === null ? PHP_FLOAT_MAX : Value::float($upToRaw);
            $rate = Value::float($bracket['rate'] ?? null);

            if ($annual <= $previousLimit) {
                break;
            }

            $inThisBracket = min($annual, $upTo) - $previousLimit;
            if ($inThisBracket > 0) {
                $tax += $inThisBracket * ($rate / 100);
            }

            $previousLimit = $upTo;
        }

        return $tax / 12;
    }
}
