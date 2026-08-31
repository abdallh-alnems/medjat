<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Models\EmployeeAuthToken;
use App\Shared\Http\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/auth/employee_logout.php.
 *
 * Deliberately not behind AuthenticateEmployee: signing out must work even when
 * the token has already expired or been revoked elsewhere, and an app that
 * cannot sign out is an app that keeps a dead session on the device.
 */
final class EmployeeLogoutController
{
    public function __invoke(Request $request): JsonResponse
    {
        $token = $request->header('X-Employee-Token');

        if (is_string($token) && $token !== '') {
            EmployeeAuthToken::revokeByPlain($token, 'employee_logout');
        }

        return ApiResponse::success(['success' => true]);
    }
}
