<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\WebSessionService;
use App\Shared\Http\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/auth/employee_web_logout.php.
 *
 * Idempotent: logging out twice is a success. A second call arriving because
 * the employee double-tapped, or because the tab was restored, must not greet
 * them with an error on the way out.
 */
final class EmployeeWebLogoutController
{
    public function __invoke(Request $request): JsonResponse
    {
        $token = WebSessionService::currentToken($request);

        if ($token !== null) {
            WebSessionService::revokeCurrent($token, 'web_logout');
        }

        return ApiResponse::success(['success' => true]);
    }
}
