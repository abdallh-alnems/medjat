<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\ActivationCode;
use App\Models\Employee;
use App\Models\EmployeeWebCredential;
use App\Modules\Attendance\Domain\WebAccessPolicy;
use App\Modules\Auth\Http\Requests\EmployeeWebActivateRequest;
use App\Modules\Auth\Services\PhoneNumber;
use App\Modules\Auth\Services\WebSessionService;
use App\Modules\Employees\Domain\EmployeeAccount;
use App\Shared\Access\PinPolicy;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;
use Throwable;

/**
 * Port of api/app/auth/employee_web_activate.php.
 *
 * First-ever browser sign-in: the single-use activation code is exchanged for a
 * PIN. That is the whole point — a browser session ends at check-out, so the
 * employee needs something reusable tomorrow, and the code cannot serve: it is
 * consumed on first use and lapses after 24 hours.
 */
final class EmployeeWebActivateController
{
    public function __invoke(EmployeeWebActivateRequest $request): JsonResponse
    {
        $phone = $request->phone();

        // Keyed on the phone as well as the IP. Someone spreading attempts
        // across addresses would sail past an IP-only limit, and this endpoint
        // is reachable by anyone holding the link — which the app's login never
        // really was.
        $key = 'web_activate:'.PhoneNumber::digits($phone);
        if (RateLimiter::tooManyAttempts($key, 10)) {
            throw new ApiFailure('عدد كبير من المحاولات، حاول لاحقاً', 429, 'rate_limited');
        }
        RateLimiter::hit($key, 3600);

        $code = ActivationCode::findUsableByCode($request->activationCode());
        if ($code === null) {
            $this->refuse();
        }

        $employee = Employee::query()
            ->forTenant($code->tenant_id)
            ->whereKey($code->employee_id)
            ->first();

        if ($employee === null) {
            $this->refuse();
        }

        if ($employee->isTerminated()) {
            throw new ApiFailure('الحساب موقوف', 403, 'account_suspended');
        }

        if (! PhoneNumber::matches($phone, (string) $employee->phone)) {
            $this->refuse();
        }

        $tenantId = $employee->tenant_id;

        // Checked before the code is consumed. Burning an activation code for a
        // company that does not allow the channel would leave the employee
        // unable to activate on their phone either.
        if (! WebAccessPolicy::isAllowed($employee, $tenantId)) {
            WebAccessPolicy::refuse($tenantId, $employee->id, 'web_not_permitted');
        }

        // Now that the employee is known, the PIN can also be checked against
        // their phone number — which is their username here.
        $reason = PinPolicy::rejectReason($request->pin(), (string) $employee->phone);
        if ($reason !== null) {
            throw new ApiFailure(PinPolicy::message($reason), 422, 'invalid_pin_format');
        }

        if (EmployeeWebCredential::findFor($employee->id, $tenantId) !== null) {
            throw new ApiFailure('تم تفعيل الدخول من المتصفح لحسابك مسبقاً', 409, 'already_activated');
        }

        try {
            $session = DB::transaction(function () use ($employee, $tenantId, $code, $request): array {
                // Also creates the `admins` row the employee's permissions
                // hang off. Omitting it here is what made an account differ
                // depending on whether the person first activated on a phone or
                // in a browser.
                EmployeeAccount::activate($employee);

                EmployeeWebCredential::query()->create([
                    'tenant_id' => $tenantId,
                    'employee_id' => $employee->id,
                    'pin_hash' => password_hash($request->pin(), PASSWORD_DEFAULT),
                    'failed_attempts' => 0,
                    'pin_set_at' => DB::raw('NOW()'),
                ]);

                $code->consumeForDevice($request->deviceId());

                // Issued inside the transaction with the credential: a consumed
                // code that produced no credential would strand the employee
                // with nothing to sign in with and no way to get another except
                // through their administrator.
                return WebSessionService::issue($tenantId, $employee->id, $request->deviceId());
            });
        } catch (Throwable $e) {
            Log::error('Employee web activation failed', ['employee_id' => $employee->id, 'exception' => $e]);
            throw new ApiFailure('حدث خطأ، حاول مرة أخرى', 500, 'activation_failed');
        }

        RateLimiter::clear($key);

        return ApiResponse::success([
            'token' => $session['token'],
            'expires_at' => $session['expires_at'],
            'employee' => [
                'id' => $employee->id,
                'name' => $employee->name,
                'branch_id' => $employee->branch_id,
                'branch_name' => $employee->branch_id === null ? null : Value::nullableString(
                    DB::table('branches')->where('id', $employee->branch_id)->value('name')
                ),
                'tenant_name' => Value::nullableString(
                    DB::table('tenants')->where('id', $tenantId)->value('name')
                ),
            ],
        ]);
    }

    /**
     * One message for an unknown code, a code belonging to someone else, and a
     * mismatched phone. Telling them apart would let the link's holder probe
     * which codes and numbers exist.
     */
    private function refuse(): never
    {
        throw new ApiFailure('بيانات التفعيل غير صحيحة', 401, 'invalid_activation');
    }
}
