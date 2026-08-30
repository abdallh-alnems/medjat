<?php

declare(strict_types=1);

namespace App\Http\Controllers\Auth;

use App\Domain\Notifications\LoginAlert;
use App\Http\ApiResponse;
use App\Http\Requests\Auth\AdminLoginRequest;
use App\Services\Auth\AdminLoginAction;
use Illuminate\Http\JsonResponse;

/**
 * Port of api/app/auth/login.php.
 */
final class AdminLoginController
{
    public function __construct(
        private readonly AdminLoginAction $login,
        private readonly LoginAlert $alert,
    ) {}

    public function __invoke(AdminLoginRequest $request): JsonResponse
    {
        $result = $this->login->execute(
            idToken: $request->idToken(),
            deviceId: $request->deviceId(),
            ip: $request->ip() ?? '',
            userAgent: (string) $request->userAgent(),
        );

        // After the session exists, and best-effort throughout: an alert that
        // fails must not fail the sign-in it was about.
        $this->alert->handle(
            $result['admin'],
            $request->ip() ?? '',
            (string) $request->userAgent(),
        );

        return ApiResponse::success($result['payload']);
    }
}
