<?php

declare(strict_types=1);

namespace App\Modules\Auth\Services;

use App\Exceptions\ApiFailure;
use App\Models\ActivationCode;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Modules\Employees\Domain\EmployeeAccount;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Port of api/app/auth/employee_login.php.
 *
 * An employee signs in with a phone number and a single-use activation code
 * issued by their company. There is no password: the code is the secret, the
 * phone is a sanity check, and what comes back is a long-lived device token.
 *
 * @phpstan-type LoginResult array{token: string, employee: array<string, mixed>, model: Employee, was_first_activation: bool}
 */
final class EmployeeLoginAction
{
    /**
     * @return LoginResult
     *
     * @throws ApiFailure
     */
    public function execute(
        string $phone,
        string $code,
        string $deviceId,
        ?string $deviceModel,
        string $platform,
        ?string $appVersion,
    ): array {
        if ($phone === '' || $code === '' || $deviceId === '') {
            throw new ApiFailure(__('messages.field_required'), 422, 'missing_fields');
        }

        // An unrecognised platform is normalised rather than refused: the value
        // only labels the session, and rejecting a login over it would lock out
        // a client whose build sends something new.
        if (! in_array($platform, EmployeeAuthToken::APP_PLATFORMS, true)) {
            $platform = 'android';
        }

        $demo = $this->resolveDemoLogin($code);
        $activationCode = null;

        if ($demo !== null) {
            $employee = $demo;
        } else {
            $activationCode = ActivationCode::findUsableByCode($code);
            if ($activationCode === null) {
                throw new ApiFailure(__('messages.activation_code_invalid'), 404, 'activation_code_invalid');
            }

            $employee = Employee::query()
                ->forTenant($activationCode->tenant_id)
                ->whereKey($activationCode->employee_id)
                ->first();

            if ($employee === null) {
                throw new ApiFailure(__('messages.employee_not_found'), 404, 'activation_code_invalid');
            }
        }

        if ($employee->isTerminated()) {
            throw new ApiFailure(__('messages.account_suspended'), 403, 'account_suspended');
        }

        if ($demo === null && ! PhoneNumber::matches($phone, (string) $employee->phone)) {
            throw new ApiFailure(__('messages.phone_code_mismatch'), 403, 'phone_code_mismatch');
        }

        return $this->completeSignIn($employee, $activationCode, $deviceId, $deviceModel, $platform, $appVersion);
    }

    /**
     * Everything that happens once the employee is established, whichever way
     * they proved who they are.
     *
     * Shared with the join-link path, where the token is the proof and there is
     * no phone to match — extracted rather than duplicated because the two paths
     * drifting apart is how one of them quietly stops creating the admins row.
     *
     * @return LoginResult
     *
     * @throws ApiFailure
     */
    public function completeSignIn(
        Employee $employee,
        ?ActivationCode $activationCode,
        string $deviceId,
        ?string $deviceModel,
        string $platform,
        ?string $appVersion,
    ): array {
        if (! in_array($platform, EmployeeAuthToken::APP_PLATFORMS, true)) {
            $platform = 'android';
        }

        // Whether the app had already been linked before this request. Managers
        // are alerted on the first activation, not on every later sign-in.
        $linked = $employee->getAttribute('has_linked_account');
        $wasFirstActivation = ! (is_numeric($linked) && (int) $linked === 1);

        try {
            $token = DB::transaction(function () use ($employee, $activationCode, $deviceId, $deviceModel, $platform, $appVersion): string {
                Employee::query()->whereKey($employee->id)->update([
                    'status' => 'active',
                    'has_linked_account' => 1,
                    'updated_at' => DB::raw('NOW()'),
                ]);

                EmployeeAccount::ensureAdminRow($employee);

                // A demo sign-in never consumes an activation row, so the same
                // credentials stay valid for every future store review.
                $activationCode?->consumeForDevice($deviceId);

                return EmployeeAuthToken::issue(
                    $employee->tenant_id,
                    $employee->id,
                    $deviceId,
                    $deviceModel,
                    $platform,
                    $appVersion,
                );
            });
        } catch (Throwable $e) {
            Log::error('Employee login failed', ['employee_id' => $employee->id, 'exception' => $e]);
            throw new ApiFailure(__('messages.sign_in_failed'), 500, 'login_failed');
        }

        return [
            'token' => $token,
            'employee' => $this->presentEmployee($employee),
            // The model as well as the presented block, so a caller can alert
            // on it without re-reading the row it already has.
            'model' => $employee,
            'was_first_activation' => $wasFirstActivation,
        ];
    }

    /**
     * The store-review account.
     *
     * Google Play and the App Store require sign-in details that are reusable
     * and never expire, which a single-use 24-hour activation code is not. One
     * configured phone+code pair signs straight into a designated employee
     * without consuming any activation row. Inert unless both settings are set,
     * which they are not in production.
     */
    private function resolveDemoLogin(string $code): ?Employee
    {
        $demoCode = strtoupper(trim(Config::string('permedjat.review_demo.code')));

        if ($demoCode === '' || $code !== $demoCode) {
            return null;
        }

        return $this->demoEmployee();
    }

    /**
     * The employee behind the store-review credentials, whichever of the two
     * demo paths asked for them.
     */
    public function demoEmployee(): ?Employee
    {
        $demoPhone = trim(Config::string('permedjat.review_demo.phone'));

        if ($demoPhone === '') {
            return null;
        }

        $employee = Employee::query()
            ->whereRaw("REPLACE(REPLACE(phone, '+', ''), ' ', '') LIKE ?", ['%'.PhoneNumber::core($demoPhone)])
            ->orderBy('id')
            ->first();

        if ($employee === null) {
            throw new ApiFailure(__('messages.demo_account_not_configured'), 404, 'activation_code_invalid');
        }

        return $employee;
    }

    /**
     * The employee block the apps expect. Field names and types are part of the
     * wire contract.
     *
     * @return array<string, mixed>
     */
    private function presentEmployee(Employee $employee): array
    {
        $employee->loadMissing([]);

        $branchName = $employee->branch_id === null ? null : DB::table('branches')
            ->where('id', $employee->branch_id)->value('name');
        $tenantName = DB::table('tenants')->where('id', $employee->tenant_id)->value('name');

        return [
            'id' => $employee->id,
            'name' => $employee->name,
            'phone' => $employee->phone,
            'tenant_id' => $employee->tenant_id,
            'tenant_name' => $tenantName,
            'branch_id' => $employee->branch_id,
            'branch_name' => $branchName,
            'job_title' => $employee->getAttribute('job_title'),
            'profile_image' => $employee->getAttribute('profile_image'),
        ];
    }
}
