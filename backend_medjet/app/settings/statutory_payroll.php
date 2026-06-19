<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    PermissionMiddleware::check($auth, 'manage_payroll');

    $settings = PayrollStatutoryModel::get($tenantId) ?? PayrollStatutoryModel::getDefaults();

    // Normalise the stored JSON brackets into a plain array for the client.
    $brackets = $settings['income_tax_brackets'] ?? null;
    if (is_string($brackets)) {
        $brackets = json_decode($brackets, true);
    }
    if (!is_array($brackets)) {
        $brackets = [];
    }

    Response::success([
        'social_insurance_enabled' => (int) ($settings['social_insurance_enabled'] ?? 0) === 1,
        'si_employee_rate' => $settings['si_employee_rate'] !== null ? (float) $settings['si_employee_rate'] : null,
        'si_min_wage' => $settings['si_min_wage'] !== null ? (float) $settings['si_min_wage'] : null,
        'si_max_wage' => $settings['si_max_wage'] !== null ? (float) $settings['si_max_wage'] : null,
        'income_tax_enabled' => (int) ($settings['income_tax_enabled'] ?? 0) === 1,
        'income_tax_brackets' => array_map(static function ($b) {
            // Tolerate the legacy `upto` key from older seed data.
            $upTo = $b['up_to'] ?? $b['upto'] ?? null;
            return [
                'up_to' => $upTo !== null ? (float) $upTo : null,
                'rate' => (float) ($b['rate'] ?? 0),
            ];
        }, $brackets),
        'tax_personal_exemption' => $settings['tax_personal_exemption'] !== null ? (float) $settings['tax_personal_exemption'] : null,
        'eosb_enabled' => (int) ($settings['eosb_enabled'] ?? 0) === 1,
        'eosb_days_per_year' => $settings['eosb_days_per_year'] !== null ? (float) $settings['eosb_days_per_year'] : null,
    ]);
}

if ($method === 'POST' || $method === 'PUT') {
    PermissionMiddleware::check($auth, 'manage_payroll');

    $input = $auth['input'];

    $siEnabled = !empty($input['social_insurance_enabled']);
    $taxEnabled = !empty($input['income_tax_enabled']);
    $eosbEnabled = !empty($input['eosb_enabled']);

    $data = [
        'social_insurance_enabled' => $siEnabled ? 1 : 0,
        'income_tax_enabled' => $taxEnabled ? 1 : 0,
        'eosb_enabled' => $eosbEnabled ? 1 : 0,
    ];

    // ── Social insurance ──────────────────────────────────
    if ($siEnabled) {
        $data['si_employee_rate'] = rateField($input['si_employee_rate'] ?? null, 'si_employee_rate');
        $data['si_min_wage'] = moneyField($input['si_min_wage'] ?? null, 'si_min_wage');
        $data['si_max_wage'] = moneyField($input['si_max_wage'] ?? null, 'si_max_wage');

        if ($data['si_min_wage'] !== null && $data['si_max_wage'] !== null
            && $data['si_max_wage'] < $data['si_min_wage']) {
            Response::fail('si_max_wage must be greater than or equal to si_min_wage', 422, 'si_max_wage_greater_than');
        }
    } else {
        $data['si_employee_rate'] = null;
        $data['si_min_wage'] = null;
        $data['si_max_wage'] = null;
    }

    // ── Income tax ────────────────────────────────────────
    if ($taxEnabled) {
        $data['tax_personal_exemption'] = moneyField($input['tax_personal_exemption'] ?? null, 'tax_personal_exemption');

        $rawBrackets = $input['income_tax_brackets'] ?? [];
        if (!is_array($rawBrackets)) {
            Response::fail('income_tax_brackets must be an array', 422, 'income_tax_brackets_array');
        }
        if (count($rawBrackets) === 0) {
            Response::fail('At least one income tax bracket is required when income tax is enabled', 422, 'at_least_one_income_tax');
        }

        $brackets = [];
        foreach ($rawBrackets as $i => $b) {
            if (!is_array($b)) {
                Response::fail("income_tax_brackets[$i] is invalid", 422, 'income_tax_brackets_invalid');
            }
            $upToRaw = $b['up_to'] ?? null;
            $upTo = ($upToRaw === null || $upToRaw === '') ? null : (float) $upToRaw;
            if ($upTo !== null && $upTo < 0) {
                Response::fail("income_tax_brackets[$i].up_to must be >= 0 or null", 422, 'income_tax_brackets_up_0');
            }
            $rate = (float) ($b['rate'] ?? 0);
            if ($rate < 0 || $rate > 100) {
                Response::fail("income_tax_brackets[$i].rate must be between 0 and 100", 422, 'income_tax_brackets_rate_between');
            }
            $brackets[] = ['up_to' => $upTo, 'rate' => $rate];
        }

        // Only one open-ended (empty ceiling) bracket is allowed — it is the
        // top, unbounded tier.
        $openCount = 0;
        foreach ($brackets as $b) {
            if ($b['up_to'] === null) {
                $openCount++;
            }
        }
        if ($openCount > 1) {
            Response::fail('Only one income tax bracket may have an empty ceiling', 422, 'only_one_income_tax_bracket');
        }

        // The progressive-tax calculator assumes ascending ceilings with the
        // open bracket last; sort here so storage always matches that contract.
        usort($brackets, static function ($a, $b) {
            if ($a['up_to'] === null) {
                return 1;
            }
            if ($b['up_to'] === null) {
                return -1;
            }
            return $a['up_to'] <=> $b['up_to'];
        });

        // Ceilings must be strictly increasing (reject duplicates).
        $prev = null;
        foreach ($brackets as $b) {
            if ($b['up_to'] === null) {
                continue;
            }
            if ($prev !== null && $b['up_to'] <= $prev) {
                Response::fail('Income tax bracket ceilings must be in ascending order with no duplicates', 422, 'income_tax_bracket_ceilings_ascending');
            }
            $prev = $b['up_to'];
        }

        $data['income_tax_brackets'] = $brackets;
    } else {
        $data['tax_personal_exemption'] = null;
        $data['income_tax_brackets'] = null;
    }

    // ── End-of-service benefit ────────────────────────────
    if ($eosbEnabled) {
        $days = $input['eosb_days_per_year'] ?? null;
        if ($days === null || $days === '') {
            Response::fail('eosb_days_per_year is required when EOSB is enabled', 422, 'eosb_days_per_year_required');
        }
        $days = (float) $days;
        if ($days < 0 || $days > 366) {
            Response::fail('eosb_days_per_year must be between 0 and 366', 422, 'eosb_days_per_year_between');
        }
        $data['eosb_days_per_year'] = $days;
    } else {
        $data['eosb_days_per_year'] = null;
    }

    PayrollStatutoryModel::upsert($tenantId, $data);

    AuditLogModel::log($tenantId, $auth['admin_id'], 'tenant.update_statutory_settings', 'tenant', $tenantId, $input);

    Response::success(['message' => 'Statutory payroll settings updated']);
}

Response::fail('Method not allowed', 405, 'method_not_allowed');

/** Parse a percentage rate (0–100); required (non-null) for the field. */
function rateField($value, string $field): float {
    if ($value === null || $value === '') {
        Response::fail("$field is required", 422, 'required');
    }
    $n = (float) $value;
    if ($n < 0 || $n > 100) {
        Response::fail("$field must be between 0 and 100", 422, 'between_0_100');
    }
    return $n;
}

/** Parse an optional monetary amount (>= 0); null/empty stays null. */
function moneyField($value, string $field): ?float {
    if ($value === null || $value === '') {
        return null;
    }
    $n = (float) $value;
    if ($n < 0) {
        Response::fail("$field must be >= 0", 422, 'field_min_zero');
    }
    return $n;
}
