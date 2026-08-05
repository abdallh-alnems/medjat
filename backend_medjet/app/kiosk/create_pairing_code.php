<?php
/**
 * Generate a pairing code that will bind one tablet to one branch.
 *
 * The plaintext code is returned here and NOWHERE else — `kiosk_codes` stores
 * only its SHA-256. Re-reading the row cannot recover it, which is deliberate:
 * a kiosk credential can record attendance for everyone at a branch, so a
 * database read must not hand anybody the means to create one.
 *
 * Input: branch_id (required), name (optional, e.g. "Main gate")
 */
require_once __DIR__ . '/../../config/bootstrap.php';
require_once __DIR__ . '/../../core/KioskPairing.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'kiosk_devices');

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
Validator::required($branchId, 'branch_id');

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) {
    Response::notFound('Branch');
}

// A tablet paired to a branch that has the kiosk switched off would sit there
// refusing everybody, which looks like a broken device rather than a setting.
if (empty($branch['station_enabled'])) {
    Response::fail(
        I18n::t('kiosk_pair_branch_disabled'),
        422,
        'kiosk_pair_branch_disabled'
    );
}

$issued = KioskPairing::issuePairCode($tenantId, $branchId, (int) $auth['admin_id']);

Response::success([
    'code'       => $issued['code'],
    'expires_at' => $issued['expires_at'],
    'expires_in_seconds' => KioskPairing::PAIR_TTL_SECONDS,
    'branch'     => [
        'id'   => (int) $branch['id'],
        'name' => $branch['name'],
    ],
]);
