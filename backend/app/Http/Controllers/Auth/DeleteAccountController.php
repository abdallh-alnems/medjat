<?php

declare(strict_types=1);

namespace App\Http\Controllers\Auth;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Services\Auth\FirebaseAccountManager;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Port of api/app/auth/delete_account.php.
 *
 * Permanently deletes the signed-in administrator, from the database and from
 * Firebase. If they are the last general manager of their company, the company
 * goes with them: companies have no owner, so one must always have at least one
 * full-access administrator or cease to exist.
 */
final class DeleteAccountController
{
    public function __construct(private readonly FirebaseAccountManager $firebase) {}

    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        try {
            $deletedCompany = DB::transaction(function () use ($admin): bool {
                if ($this->isLastGeneralManager($admin)) {
                    // Every tenant-scoped table, admins included, cascades from
                    // here — which is why this is the only statement needed and
                    // also why it is irreversible.
                    DB::table('tenants')->where('id', $admin->tenant_id)->delete();

                    return true;
                }

                DB::table('admins')->where('id', $admin->id)->delete();

                return false;
            });
        } catch (Throwable $e) {
            Log::error('Delete account failed', ['admin_id' => $admin->id, 'exception' => $e]);
            throw new ApiFailure('Failed to delete account', 500, 'failed_delete_account');
        }

        // Best-effort, and after the transaction: the row is already gone, and
        // failing here would tell someone their deletion did not work when it
        // did.
        $this->firebase->deleteUser((string) $admin->firebase_uid);

        return ApiResponse::success([
            'success' => true,
            'deleted_company' => $deletedCompany,
            'message' => $deletedCompany ? 'Company and account deleted' : 'Account deleted',
        ]);
    }

    private function isLastGeneralManager(Admin $admin): bool
    {
        if ($admin->tenant_id === null || $admin->role !== 'general_manager') {
            return false;
        }

        return ! Admin::query()
            ->where('tenant_id', $admin->tenant_id)
            ->where('role', 'general_manager')
            ->whereKeyNot($admin->id)
            ->exists();
    }
}
