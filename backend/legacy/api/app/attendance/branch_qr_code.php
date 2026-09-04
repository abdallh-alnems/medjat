<?php
/**
 * Mints the next rotating code for a branch display.
 *
 * The screen at the branch door polls this every `rotate_in` seconds and renders
 * the returned nonce as a QR image. Employees scan whatever is on screen and
 * send it with their check-in; check_in.php claims it once per employee.
 *
 * AUTHENTICATION — an honest note about what this is and is not.
 *
 * This endpoint authenticates the *administrator* who opened the display page,
 * not the display itself. That is a deliberate first step, not the end state:
 * the page runs in permedjat_central_web where an administrator is already signed
 * in, so it needs no new credential system to be useful today.
 *
 * The cost is real and should be understood before this is rolled out widely: a
 * tablet left on the wall showing this page is a tablet holding a live
 * administrator session. Mitigate it operationally for now — a dedicated
 * low-permission account for the display, and a device that is locked to this
 * one page.
 *
 * The end state is the kiosk credential: `attendance_stations` already models a
 * branch-scoped, hashed, revocable token issued by a pairing exchange
 * (Auth::authenticateKiosk), which is exactly the right shape for a wall
 * display. Moving to it is a follow-up, and this endpoint should accept both
 * when that happens rather than a second bespoke credential being invented.
 *
 * Input:  branch_id
 * Output: nonce, expires_in, rotate_in
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

// Same permission as configuring the branch's attendance method: whoever can
// decide a branch runs on rotating codes can operate the screen that shows them.
PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
Validator::required($branchId, 'branch_id');

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) {
    Response::notFound('Branch');
}

// Refuse rather than mint a code nothing will accept. A display quietly showing
// codes that check_in.php ignores — because the branch is still on the printed
// code — is the kind of failure that gets discovered by a queue at the door.
if (!BranchQrChallengeModel::isEnabledForBranch($branch)) {
    Response::fail(
        'Rotating QR is not enabled for this branch.',
        409,
        'ROTATING_QR_DISABLED'
    );
}

$challenge = BranchQrChallengeModel::issue($tenantId, $branchId, $auth['admin_id'] ?? null);

Response::success([
    'nonce' => $challenge['nonce'],
    // Seconds this code stays valid. Longer than rotate_in on purpose: windows
    // overlap so a code cannot expire between being rendered and being scanned.
    'expires_in' => $challenge['expires_in'],
    // How long the display should wait before asking for the next one.
    'rotate_in' => $challenge['rotate_in'],
    'branch' => $branch['name'],
]);
