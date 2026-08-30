<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Http\ApiResponse;
use App\Models\Admin;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/auth/logout.php.
 */
final class AdminLogoutController
{
    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');

        if ($admin instanceof Admin) {
            // Clear the active device so no stale one is treated as signed in
            // until the next login.
            Admin::query()->whereKey($admin->id)->update(['active_device_id' => null]);
        }

        return ApiResponse::success(['success' => true]);
    }
}
