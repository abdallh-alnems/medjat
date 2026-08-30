<?php

declare(strict_types=1);

namespace App\Http\Controllers\Auth;

use App\Domain\Notifications\EmployeeActivationAlert;
use App\Http\ApiResponse;
use App\Http\Requests\Auth\EmployeeLoginRequest;
use App\Services\Auth\EmployeeLoginAction;
use Illuminate\Http\JsonResponse;

/**
 * Port of api/app/auth/employee_login.php.
 */
final class EmployeeLoginController
{
    public function __construct(
        private readonly EmployeeLoginAction $login,
        private readonly EmployeeActivationAlert $alert,
    ) {}

    public function __invoke(EmployeeLoginRequest $request): JsonResponse
    {
        $result = $this->login->execute(
            phone: $request->phone(),
            code: $request->activationCode(),
            deviceId: $request->deviceId(),
            deviceModel: $request->deviceModel(),
            platform: $request->platform(),
            appVersion: $request->appVersion(),
        );

        // Best-effort and deliberately outside the transaction: a notification
        // that fails to send must not undo a successful sign-in.
        $this->alert->notify($result['model'], $result['was_first_activation']);

        return ApiResponse::success([
            'success' => true,
            'token' => $result['token'],
            'employee' => $result['employee'],
        ]);
    }
}
