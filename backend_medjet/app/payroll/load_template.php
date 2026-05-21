<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
TenantMiddleware::requireTenant();

$country = $_GET['country'] ?? '';

$templates = [
    'EG' => [
        'social_insurance_enabled' => 1,
        'si_employee_rate' => 11.00,
        'si_employer_rate' => 18.75,
        'si_min_wage' => null,
        'si_max_wage' => null,
        'income_tax_enabled' => 1,
        'income_tax_brackets' => [
            ['up_to' => 30000, 'rate' => 0],
            ['up_to' => 45000, 'rate' => 2.5],
            ['up_to' => 60000, 'rate' => 10],
            ['up_to' => 200000, 'rate' => 15],
            ['up_to' => 400000, 'rate' => 20],
            ['up_to' => null, 'rate' => 25],
        ],
        'tax_personal_exemption' => null,
        'eosb_enabled' => 1,
        'eosb_days_per_year' => 21.00,
    ],
];

if ($country === '' || !isset($templates[$country])) {
    Response::fail('Unknown country template. Available: ' . implode(', ', array_keys($templates)), 404);
}

Response::success([
    'country' => $country,
    'template' => $templates[$country],
    'disclaimer' => 'These values are indicative starting points. The user is responsible for updating them according to applicable law.',
]);
