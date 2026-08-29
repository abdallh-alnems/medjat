<?php

declare(strict_types=1);

namespace App\Http\Controllers\Auth;

use App\Http\ApiResponse;
use App\Http\Requests\Auth\AdminLoginRequest;
use App\Services\Auth\AdminLoginAction;
use Illuminate\Http\JsonResponse;

/**
 * Port of api/app/auth/login.php.
 */
final class AdminLoginController
{
    public function __construct(private readonly AdminLoginAction $login) {}

    public function __invoke(AdminLoginRequest $request): JsonResponse
    {
        $result = $this->login->execute(
            idToken: $request->idToken(),
            deviceId: $request->deviceId(),
            ip: $request->ip() ?? '',
            userAgent: (string) $request->userAgent(),
        );

        // TODO(auth-port): the new-device alert (in-app notification, FCM push,
        // email) is deferred until the notifications module is ported. It was
        // never on the login critical path in the old backend either — it ran
        // after the response through Background::defer, chiefly because of the
        // SMTP round trip.

        return ApiResponse::success($result['payload']);
    }
}
