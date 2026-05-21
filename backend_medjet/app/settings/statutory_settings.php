<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $row = PayrollStatutoryModel::get($tenantId);
    if ($row) {
        if ($row['income_tax_brackets'] !== null) {
            $row['income_tax_brackets'] = json_decode($row['income_tax_brackets'], true);
        }
        Response::success($row);
    } else {
        Response::success(PayrollStatutoryModel::getDefaults());
    }
}

if ($method === 'POST' || $method === 'PUT') {
    PermissionMiddleware::check($auth, 'manage_payroll');

    $input = $auth['input'];

    $data = [
        'social_insurance_enabled' => isset($input['social_insurance_enabled']) ? (int) filter_var($input['social_insurance_enabled'], FILTER_VALIDATE_BOOLEAN) : 0,
        'si_employee_rate' => isset($input['si_employee_rate']) && $input['si_employee_rate'] !== '' ? $input['si_employee_rate'] : null,
        'si_employer_rate' => isset($input['si_employer_rate']) && $input['si_employer_rate'] !== '' ? $input['si_employer_rate'] : null,
        'si_min_wage' => isset($input['si_min_wage']) && $input['si_min_wage'] !== '' ? $input['si_min_wage'] : null,
        'si_max_wage' => isset($input['si_max_wage']) && $input['si_max_wage'] !== '' ? $input['si_max_wage'] : null,
        'income_tax_enabled' => isset($input['income_tax_enabled']) ? (int) filter_var($input['income_tax_enabled'], FILTER_VALIDATE_BOOLEAN) : 0,
        'income_tax_brackets' => $input['income_tax_brackets'] ?? null,
        'tax_personal_exemption' => isset($input['tax_personal_exemption']) && $input['tax_personal_exemption'] !== '' ? $input['tax_personal_exemption'] : null,
        'eosb_enabled' => isset($input['eosb_enabled']) ? (int) filter_var($input['eosb_enabled'], FILTER_VALIDATE_BOOLEAN) : 0,
        'eosb_days_per_year' => isset($input['eosb_days_per_year']) && $input['eosb_days_per_year'] !== '' ? $input['eosb_days_per_year'] : null,
    ];

    if ($data['social_insurance_enabled'] && ($data['si_employee_rate'] === null || (float) $data['si_employee_rate'] <= 0)) {
        Response::fail('si_employee_rate is required when social insurance is enabled', 422);
    }

    if ($data['income_tax_enabled'] && empty($data['income_tax_brackets'])) {
        Response::fail('income_tax_brackets is required when income tax is enabled', 422);
    }

    if ($data['eosb_enabled'] && ($data['eosb_days_per_year'] === null || (float) $data['eosb_days_per_year'] <= 0)) {
        Response::fail('eosb_days_per_year is required when EOSB is enabled', 422);
    }

    PayrollStatutoryModel::upsert($tenantId, $data);

    AuditLogModel::log($tenantId, $auth['admin_id'], 'payroll.update_statutory_settings', 'payroll_statutory_settings', $tenantId);

    Response::success(['message' => 'Statutory settings saved']);
}

Response::fail('Method not allowed', 405);
