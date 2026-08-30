<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\ActivationCode;
use App\Models\Employee;
use App\Modules\Auth\Http\Requests\EmployeeActivateTokenRequest;
use App\Modules\Auth\Services\EmployeeLoginAction;
use App\Modules\Notifications\Domain\EmployeeActivationAlert;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Config;

/**
 * Port of api/app/auth/employee_activate_token.php.
 *
 * Activation from a join link or QR code. The token is the secret: long,
 * non-guessable and single-use, so unlike the phone-and-code path there is no
 * phone to match — opening the link is the proof. Consuming the row invalidates
 * the sibling `code` with it, since both name the same activation.
 */
final class EmployeeActivateTokenController
{
    public function __construct(
        private readonly EmployeeLoginAction $login,
        private readonly EmployeeActivationAlert $alert,
    ) {}

    public function __invoke(EmployeeActivateTokenRequest $request): JsonResponse
    {
        $token = $request->token();

        $demo = $this->resolveDemo($token);
        $activationCode = null;

        if ($demo !== null) {
            $employee = $demo;
        } else {
            $activationCode = ActivationCode::findUsableByToken($token);
            if ($activationCode === null) {
                throw new ApiFailure('رابط التفعيل غير صالح أو منتهي', 404, 'join_link_invalid');
            }

            $employee = Employee::query()
                ->forTenant($activationCode->tenant_id)
                ->whereKey($activationCode->employee_id)
                ->first();

            if ($employee === null) {
                throw new ApiFailure('رابط التفعيل غير صالح أو منتهي', 404, 'join_link_invalid');
            }
        }

        if ($employee->isTerminated()) {
            throw new ApiFailure('الحساب موقوف', 403, 'account_suspended');
        }

        $result = $this->login->completeSignIn(
            employee: $employee,
            activationCode: $activationCode,
            deviceId: $request->deviceId(),
            deviceModel: $request->deviceModel(),
            platform: $request->platform(),
            appVersion: $request->appVersion(),
        );

        // The same alert the phone login sends: activating through a join link
        // is still an activation, and HR is waiting to hear about it either way.
        $this->alert->notify($result['model'], $result['was_first_activation']);

        return ApiResponse::success([
            'success' => true,
            'token' => $result['token'],
            'employee' => $result['employee'],
        ]);
    }

    /**
     * The store-review demo QR.
     *
     * Mirrors the phone-and-code demo: one configured token, encoded into a
     * permanent QR, signs into the demo employee without consuming or expiring
     * anything, so reviewers can test the scan flow on every submission. Inert
     * in production, where neither setting is present.
     */
    private function resolveDemo(string $token): ?Employee
    {
        $demoToken = trim(Config::string('medjat.review_demo.token'));

        if ($demoToken === '' || ! hash_equals($demoToken, $token)) {
            return null;
        }

        $employee = $this->login->demoEmployee();

        if ($employee === null) {
            throw new ApiFailure('Demo account not configured', 404, 'join_link_invalid');
        }

        return $employee;
    }
}
