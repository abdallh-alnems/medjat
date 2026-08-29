<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Exceptions\ApiFailure;
use App\Models\ActivationCode;
use App\Models\Admin;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
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
 * @phpstan-type LoginResult array{token: string, employee: array<string, mixed>, was_first_activation: bool}
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
            throw new ApiFailure('حقل مطلوب', 422, 'missing_fields');
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
                throw new ApiFailure('كود التفعيل غير صالح أو منتهي', 404, 'activation_code_invalid');
            }

            $employee = Employee::query()
                ->forTenant($activationCode->tenant_id)
                ->whereKey($activationCode->employee_id)
                ->first();

            if ($employee === null) {
                throw new ApiFailure('Employee not found', 404, 'activation_code_invalid');
            }
        }

        if ($employee->isTerminated()) {
            throw new ApiFailure('الحساب موقوف', 403, 'account_suspended');
        }

        if ($demo === null && ! PhoneNumber::matches($phone, (string) $employee->phone)) {
            throw new ApiFailure('رقم الهاتف لا يطابق كود التفعيل', 403, 'phone_code_mismatch');
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

                $this->ensureAdminRow($employee);

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
            throw new ApiFailure('تعذّر تسجيل الدخول', 500, 'login_failed');
        }

        return [
            'token' => $token,
            'employee' => $this->presentEmployee($employee),
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
        $demoPhone = trim((string) Config::string('medjat.review_demo.phone'));
        $demoCode = strtoupper(trim((string) Config::string('medjat.review_demo.code')));

        if ($demoPhone === '' || $demoCode === '' || $code !== $demoCode) {
            return null;
        }

        $employee = Employee::query()
            ->whereRaw("REPLACE(REPLACE(phone, '+', ''), ' ', '') LIKE ?", ['%'.PhoneNumber::core($demoPhone)])
            ->orderBy('id')
            ->first();

        if ($employee === null) {
            throw new ApiFailure('Demo account not configured', 404, 'activation_code_invalid');
        }

        return $employee;
    }

    /**
     * Employees carry permissions through an `admins` row with the `employee`
     * role. Created on first sign-in and reused afterwards; the firebase_uid is
     * synthetic because an employee never authenticates through Firebase.
     */
    private function ensureAdminRow(Employee $employee): void
    {
        if ($employee->admin_id !== null) {
            return;
        }

        $existing = Admin::query()
            ->where('tenant_id', $employee->tenant_id)
            ->where('phone', $employee->phone)
            ->where('role', 'employee')
            ->first();

        if ($existing !== null) {
            $adminId = $existing->id;
        } else {
            $adminId = (int) Admin::query()->insertGetId([
                'firebase_uid' => 'employee:'.$employee->id,
                'tenant_id' => $employee->tenant_id,
                'branch_id' => $employee->branch_id,
                'name' => $employee->name,
                'phone' => $employee->phone,
                'role' => 'employee',
            ]);
        }

        Employee::query()->whereKey($employee->id)->update(['admin_id' => $adminId]);
        $employee->admin_id = $adminId;
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
