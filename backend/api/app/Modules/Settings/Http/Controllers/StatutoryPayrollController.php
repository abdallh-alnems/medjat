<?php

declare(strict_types=1);

namespace App\Modules\Settings\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Payroll\Domain\PayrollCache;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/settings/statutory_payroll.php.
 *
 * Social insurance, income tax and end-of-service: the three deductions a
 * jurisdiction imposes rather than a company choosing. All three are off until
 * somebody configures them, because a wrong number here is applied to every
 * payslip silently.
 */
final class StatutoryPayrollController
{
    public function show(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $settings = DB::table('payroll_statutory_settings')->where('tenant_id', $tenantId)->first();

        return ApiResponse::success([
            'social_insurance_enabled' => Value::int($settings?->social_insurance_enabled) === 1,
            'si_employee_rate' => Value::nullableFloat($settings?->si_employee_rate),
            'si_min_wage' => Value::nullableFloat($settings?->si_min_wage),
            'si_max_wage' => Value::nullableFloat($settings?->si_max_wage),
            'income_tax_enabled' => Value::int($settings?->income_tax_enabled) === 1,
            'income_tax_brackets' => self::readBrackets($settings?->income_tax_brackets),
            'tax_personal_exemption' => Value::nullableFloat($settings?->tax_personal_exemption),
            'eosb_enabled' => Value::int($settings?->eosb_enabled) === 1,
            'eosb_days_per_year' => Value::nullableFloat($settings?->eosb_days_per_year),
        ]);
    }

    public function save(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);

        $insuranceOn = $request->boolean('social_insurance_enabled');
        $taxOn = $request->boolean('income_tax_enabled');
        $eosbOn = $request->boolean('eosb_enabled');

        $data = [
            'social_insurance_enabled' => $insuranceOn ? 1 : 0,
            'income_tax_enabled' => $taxOn ? 1 : 0,
            'eosb_enabled' => $eosbOn ? 1 : 0,
        ];

        // Turning something off clears its figures rather than leaving them
        // parked: a rate that is stored but not applied is the one somebody
        // re-enables a year later without re-reading.
        $data += $insuranceOn
            ? $this->insurance($request)
            : ['si_employee_rate' => null, 'si_min_wage' => null, 'si_max_wage' => null];

        $data += $taxOn
            ? $this->tax($request)
            : ['tax_personal_exemption' => null, 'income_tax_brackets' => null];

        $data['eosb_days_per_year'] = $eosbOn ? $this->eosbDays($request) : null;

        DB::table('payroll_statutory_settings')->upsert(
            [$data + ['tenant_id' => $tenantId]],
            ['tenant_id'],
            array_keys($data),
        );

        AuditLog::record($tenantId, $admin->id, 'tenant.update_statutory_settings', 'tenant', $tenantId, $data);

        // Every payslip in the company is now computed differently.
        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['message' => 'Statutory payroll settings updated']);
    }

    /**
     * @return array<string, float|null>
     */
    private function insurance(Request $request): array
    {
        $rate = self::rate($request->input('si_employee_rate'), 'si_employee_rate');
        $min = self::money($request->input('si_min_wage'), 'si_min_wage');
        $max = self::money($request->input('si_max_wage'), 'si_max_wage');

        if ($min !== null && $max !== null && $max < $min) {
            throw new ApiFailure(
                'si_max_wage must be greater than or equal to si_min_wage',
                422,
                'si_max_wage_greater_than',
            );
        }

        return ['si_employee_rate' => $rate, 'si_min_wage' => $min, 'si_max_wage' => $max];
    }

    /**
     * @return array<string, string|float|null>
     */
    private function tax(Request $request): array
    {
        $raw = $request->input('income_tax_brackets', []);

        if (! is_array($raw)) {
            throw new ApiFailure('income_tax_brackets must be an array', 422, 'income_tax_brackets_array');
        }

        if ($raw === []) {
            throw new ApiFailure(
                'At least one income tax bracket is required when income tax is enabled',
                422,
                'at_least_one_income_tax',
            );
        }

        $brackets = [];
        $open = 0;

        foreach (array_values($raw) as $i => $bracket) {
            if (! is_array($bracket)) {
                throw new ApiFailure("income_tax_brackets[$i] is invalid", 422, 'income_tax_brackets_invalid');
            }

            $ceilingRaw = $bracket['up_to'] ?? null;
            $ceiling = ($ceilingRaw === null || $ceilingRaw === '') ? null : Value::float($ceilingRaw);

            if ($ceiling !== null && $ceiling < 0) {
                throw new ApiFailure(
                    "income_tax_brackets[$i].up_to must be >= 0 or null",
                    422,
                    'income_tax_brackets_up_0',
                );
            }

            $rate = Value::float($bracket['rate'] ?? null);

            if ($rate < 0 || $rate > 100) {
                throw new ApiFailure(
                    "income_tax_brackets[$i].rate must be between 0 and 100",
                    422,
                    'income_tax_brackets_rate_between',
                );
            }

            $open += $ceiling === null ? 1 : 0;
            $brackets[] = ['up_to' => $ceiling, 'rate' => $rate];
        }

        // An empty ceiling means "and everything above", which only makes sense
        // once — two of them would leave income with no single home.
        if ($open > 1) {
            throw new ApiFailure(
                'Only one income tax bracket may have an empty ceiling',
                422,
                'only_one_income_tax_bracket',
            );
        }

        // The progressive calculator walks the ladder in order with the open
        // bracket last, so storage is sorted to match rather than trusting the
        // order the screen happened to send.
        usort($brackets, static function (array $a, array $b): int {
            if ($a['up_to'] === null) {
                return 1;
            }

            if ($b['up_to'] === null) {
                return -1;
            }

            return $a['up_to'] <=> $b['up_to'];
        });

        $previous = null;

        foreach ($brackets as $bracket) {
            if ($bracket['up_to'] === null) {
                continue;
            }

            if ($previous !== null && $bracket['up_to'] <= $previous) {
                throw new ApiFailure(
                    'Income tax bracket ceilings must be in ascending order with no duplicates',
                    422,
                    'income_tax_bracket_ceilings_ascending',
                );
            }

            $previous = $bracket['up_to'];
        }

        return [
            'tax_personal_exemption' => self::money(
                $request->input('tax_personal_exemption'), 'tax_personal_exemption',
            ),
            'income_tax_brackets' => (string) json_encode($brackets),
        ];
    }

    private function eosbDays(Request $request): float
    {
        $raw = $request->input('eosb_days_per_year');

        if ($raw === null || $raw === '') {
            throw new ApiFailure(
                'eosb_days_per_year is required when EOSB is enabled',
                422,
                'eosb_days_per_year_required',
            );
        }

        $days = Value::float($raw);

        if ($days < 0 || $days > 366) {
            throw new ApiFailure(
                'eosb_days_per_year must be between 0 and 366',
                422,
                'eosb_days_per_year_between',
            );
        }

        return $days;
    }

    /**
     * @return list<array{up_to: float|null, rate: float}>
     */
    private static function readBrackets(mixed $stored): array
    {
        $decoded = is_string($stored) ? json_decode($stored, true) : $stored;

        if (! is_array($decoded)) {
            return [];
        }

        $brackets = [];

        foreach ($decoded as $bracket) {
            if (! is_array($bracket)) {
                continue;
            }

            // `upto` is the spelling older seed data used.
            $ceiling = $bracket['up_to'] ?? $bracket['upto'] ?? null;

            $brackets[] = [
                'up_to' => $ceiling === null ? null : Value::float($ceiling),
                'rate' => Value::float($bracket['rate'] ?? null),
            ];
        }

        return $brackets;
    }

    private static function rate(mixed $raw, string $field): float
    {
        if ($raw === null || $raw === '') {
            throw new ApiFailure("$field is required", 422, 'required');
        }

        $rate = Value::float($raw);

        if ($rate < 0 || $rate > 100) {
            throw new ApiFailure("$field must be between 0 and 100", 422, 'between_0_100');
        }

        return $rate;
    }

    private static function money(mixed $raw, string $field): ?float
    {
        if ($raw === null || $raw === '') {
            return null;
        }

        $amount = Value::float($raw);

        if ($amount < 0) {
            throw new ApiFailure("$field must be >= 0", 422, 'field_min_zero');
        }

        return $amount;
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        return $admin;
    }
}
