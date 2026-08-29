<?php

declare(strict_types=1);

namespace App\Http\Controllers\Attendance;

use App\Domain\Attendance\BranchQrChallenge;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Models\Branch;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/attendance/branch_qr_code.php.
 *
 * Mints the next rotating code for a branch display. The screen polls this every
 * rotate_in seconds and renders the nonce as a QR image.
 *
 * An honest note about what this authenticates. It authenticates the
 * administrator who opened the display page, not the display itself — a
 * deliberate first step rather than the end state, because the page runs where
 * an administrator is already signed in and so needs no new credential system to
 * be useful today. The cost is real: a tablet left on a wall showing this page
 * is a tablet holding a live administrator session, so mitigate it operationally
 * with a dedicated low-permission account and a locked-down device. The end
 * state is the kiosk credential, which already models a branch-scoped, hashed,
 * revocable token; this endpoint should accept both when that lands rather than
 * a second bespoke credential being invented.
 */
final class BranchQrCodeController
{
    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = Value::int($request->input('branch_id'));

        if ($branchId <= 0) {
            throw new ApiFailure('branch_id is required', 422, 'missing_fields');
        }

        $branch = Branch::query()->forTenant($tenantId)->whereKey($branchId)->first();
        if ($branch === null) {
            throw new ApiFailure('Branch not found', 404);
        }

        // Refuse rather than mint a code nothing will accept. A display quietly
        // showing codes the punch path ignores — because the branch is still on
        // the printed one — is the kind of failure discovered by a queue at the
        // door.
        if (! $branch->rotating_qr_enabled) {
            throw new ApiFailure('Rotating QR is not enabled for this branch.', 409, 'ROTATING_QR_DISABLED');
        }

        return ApiResponse::success(BranchQrChallenge::issue($tenantId, $branchId, $admin->id));
    }
}
