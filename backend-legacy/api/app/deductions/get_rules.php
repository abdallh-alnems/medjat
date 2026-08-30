<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$rules = DeductionRuleModel::getActiveByTenant($tenantId);
$tiers = DeductionRuleModel::getLateTiers($tenantId);

$ruleValue = static function (string $key, $default = null) use ($rules) {
    foreach ($rules as $r) {
        if ($r['rule_key'] === $key) {
            return $r['rule_value'];
        }
    }
    return $default;
};

Response::success([
    'rules' => $rules,
    'config' => [
        'late_type' => $ruleValue('late_type', 'tiered'),
        // Default MUST match PayrollCalculator's absence_multiplier fallback
        // (1.5) so an unconfigured tenant sees the same value the payroll
        // actually applies, and saving it does not silently change deductions.
        'absence_days' => (float) $ruleValue('absence_multiplier', 1.5),
        'tiers' => array_map(static fn($t) => [
            'id' => (int) $t['id'],
            'threshold_minutes' => (int) $t['threshold_minutes'],
            'deduction_days' => (float) $t['deduction_days'],
        ], $tiers),
    ],
]);
