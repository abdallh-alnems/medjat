<?php
/**
 * Approves a batch of networks for a branch and optionally switches the WiFi
 * enforcement mode.
 *
 * Input:  branch_id,
 *         approve[]   — [{kind, value, label}] to approve/reactivate
 *         deactivate[] — branch_network ids to switch off
 *         wifi_mode, wifi_match (optional)
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
Validator::required($branchId, 'branch_id');

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) {
    Response::notFound('Branch');
}
PermissionMiddleware::checkBranchAccess($auth, $branchId);

$approved = 0;
foreach (($input['approve'] ?? []) as $item) {
    if (!is_array($item)) {
        continue;
    }
    $kind = $item['kind'] ?? 'bssid';
    if (!in_array($kind, ['bssid', 'ip_v4', 'ip_cidr'], true)) {
        Response::fail('Invalid network kind: ' . $kind, 422, 'invalid_network_kind');
    }

    $value = (string) ($item['value'] ?? '');
    if ($kind === 'bssid') {
        $normalised = NetworkVerifier::normaliseBssid($value);
        if ($normalised === null) {
            Response::fail('Invalid BSSID: ' . $value, 422, 'invalid_bssid');
        }
        $value = $normalised;
    } elseif ($kind === 'ip_v4') {
        if (!filter_var($value, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            Response::fail('Invalid IPv4 address: ' . $value, 422, 'invalid_ip');
        }
    } else {
        [$subnet, $bits] = array_pad(explode('/', $value, 2), 2, null);
        if (!filter_var((string) $subnet, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)
            || $bits === null || !ctype_digit((string) $bits) || (int) $bits > 32) {
            Response::fail('Invalid CIDR range: ' . $value, 422, 'invalid_cidr');
        }
    }

    $label = isset($item['label']) ? mb_substr((string) $item['label'], 0, 100) : null;
    BranchNetworkModel::approve(
        $tenantId,
        $branchId,
        $kind,
        $value,
        $label !== '' ? $label : null,
        $item['source'] ?? 'discovered',
        $auth['admin_id']
    );
    $approved++;
}

$deactivated = 0;
if (!empty($input['deactivate']) && is_array($input['deactivate'])) {
    $deactivated = BranchNetworkModel::deactivate($tenantId, $branchId, $input['deactivate']);
}

if (array_key_exists('wifi_mode', $input) || array_key_exists('wifi_match', $input)) {
    $mode = $input['wifi_mode'] ?? $branch['wifi_mode'];
    if ($mode !== null && !in_array($mode, ['learning', 'enforcing', 'optional'], true)) {
        Response::fail('wifi_mode must be learning, enforcing or optional', 422, 'invalid_wifi_mode');
    }

    $match = $input['wifi_match'] ?? ($branch['wifi_match'] ?? 'bssid');
    if (!in_array($match, ['bssid', 'ip', 'either'], true)) {
        Response::fail('wifi_match must be bssid, ip or either', 422, 'invalid_wifi_match');
    }

    // Enforcing with nothing approved would lock every employee out of the
    // branch. The admin has to approve at least one network first.
    if ($mode === 'enforcing' && !BranchNetworkModel::hasAnyApproved($branchId, $tenantId)) {
        Response::fail(
            'Approve at least one network before enabling enforcement',
            422,
            'no_approved_networks'
        );
    }

    BranchModel::updateWifiSettings($branchId, $tenantId, $mode, $match);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'branch.approve_networks', 'branch', $branchId, [
    'approved' => $approved,
    'deactivated' => $deactivated,
    'wifi_mode' => $input['wifi_mode'] ?? null,
]);

Response::success([
    'approved' => $approved,
    'deactivated' => $deactivated,
    'networks' => BranchNetworkModel::approvedFor($branchId, $tenantId),
]);
