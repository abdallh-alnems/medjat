<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_deduction_rules');

$input = $auth['input'];
$absenceDays = (float) ($input['absence_days'] ?? 0);
$rawTiers = $input['tiers'] ?? [];

if ($absenceDays < 0) {
    Response::error('يجب أن يكون خصم الغياب صفراً أو أكثر', 422);
}
if (!is_array($rawTiers)) {
    Response::error('صيغة الشرائح غير صحيحة', 422);
}

// Normalise + validate the tier ladder. Thresholds must be unique positive
// integers; deduction values are positive fractions of a working day.
$tiers = [];
$seen = [];
foreach ($rawTiers as $tier) {
    $minutes = (int) ($tier['threshold_minutes'] ?? $tier['minutes'] ?? 0);
    $days = (float) ($tier['deduction_days'] ?? $tier['days'] ?? 0);
    if ($minutes <= 0) {
        Response::error('عتبة الدقائق يجب أن تكون أكبر من صفر', 422);
    }
    if ($days <= 0) {
        Response::error('قيمة الخصم يجب أن تكون أكبر من صفر', 422);
    }
    if (isset($seen[$minutes])) {
        Response::error("عتبة الدقائق {$minutes} مكررة", 422);
    }
    $seen[$minutes] = true;
    $tiers[] = ['threshold_minutes' => $minutes, 'deduction_days' => $days];
}

DeductionRuleModel::saveConfig($tenantId, $tiers, $absenceDays);

AuditLogModel::log($tenantId, $auth['admin_id'], 'deduction.rules_updated', 'tenant', $tenantId, [
    'tiers' => count($tiers),
    'absence_days' => $absenceDays,
]);

PayrollCache::invalidate($tenantId);

Response::success(['message' => 'تم حفظ قواعد الخصم']);
