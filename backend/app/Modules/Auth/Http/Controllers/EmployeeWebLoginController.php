<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Models\EmployeeWebCredential;
use App\Modules\Attendance\Domain\WebAccessPolicy;
use App\Modules\Auth\Http\Requests\EmployeeWebLoginRequest;
use App\Modules\Auth\Services\PhoneNumber;
use App\Modules\Auth\Services\WebSessionService;
use App\Shared\Http\ApiResponse;
use App\Shared\Security\AttendanceSecurityLog;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;

/**
 * Port of api/app/auth/employee_web_login.php.
 *
 * Everyday browser sign-in: phone plus the PIN set at activation.
 */
final class EmployeeWebLoginController
{
    public function __invoke(EmployeeWebLoginRequest $request): JsonResponse
    {
        $phone = $request->phone();

        // Per-phone as well as per-IP. Rate limiting only slows guessing down;
        // the real bound on a six-digit space is the lockout below.
        $key = 'web_login:'.PhoneNumber::digits($phone);
        if (RateLimiter::tooManyAttempts($key, 20)) {
            throw new ApiFailure('عدد كبير من المحاولات، حاول بعد قليل', 429, 'rate_limited');
        }
        RateLimiter::hit($key, 900);

        $employee = $this->findByPhone($phone);

        if ($employee === null) {
            $this->refuseGenerically();
        }

        $tenantId = $employee->tenant_id;

        if ($employee->isTerminated()) {
            throw new ApiFailure('الحساب موقوف', 403, 'account_suspended');
        }

        $credential = EmployeeWebCredential::findFor($employee->id, $tenantId);
        if ($credential === null) {
            // Distinct from invalid_credentials on purpose: telling someone who
            // has never set a PIN to "check your PIN" sends them in a circle.
            // This leaks only that the number exists, to somebody who already
            // guessed it, and the alternative is a support call for every
            // first-time user.
            throw new ApiFailure('لم يتم تفعيل الدخول من المتصفح لحسابك بعد', 404, 'not_activated');
        }

        if (EmployeeWebCredential::isLocked($employee->id)) {
            AttendanceSecurityLog::record($tenantId, $employee->id, null, 'web_pin_locked', 'blocked');
            throw new ApiFailure('تم قفل الحساب مؤقتاً بعد محاولات خاطئة', 423, 'web_pin_locked');
        }

        if (! $credential->verifyPin($request->pin())) {
            if (EmployeeWebCredential::recordFailure($employee->id)) {
                AttendanceSecurityLog::record($tenantId, $employee->id, null, 'web_pin_locked', 'blocked');
                throw new ApiFailure('تم قفل الحساب مؤقتاً بعد محاولات خاطئة', 423, 'web_pin_locked');
            }
            $this->refuseGenerically();
        }

        // Checked after the PIN so a refusal cannot be used to enumerate which
        // companies have the channel switched on.
        if (! WebAccessPolicy::isAllowed($employee, $tenantId)) {
            WebAccessPolicy::refuse($tenantId, $employee->id, 'web_not_permitted');
        }

        EmployeeWebCredential::recordSuccess($employee->id);
        RateLimiter::clear($key);

        $session = WebSessionService::issue($tenantId, $employee->id, $request->deviceId());

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
     * One response for "no such phone" and for "wrong PIN". Distinguishing them
     * would turn this endpoint into an oracle for which numbers are enrolled,
     * which is worth more to an attacker than any single PIN.
     */
    private function refuseGenerically(): never
    {
        throw new ApiFailure('رقم الهاتف أو الرقم السري غير صحيح', 401, 'invalid_credentials');
    }

    /**
     * Phones are stored E.164 but typed locally, and some legacy rows carry the
     * national zero inside the country code, so the match is on the tail of the
     * significant digits.
     */
    private function findByPhone(string $phone): ?Employee
    {
        $core = PhoneNumber::core($phone);

        if ($core === '') {
            return null;
        }

        /** @var Employee|null */
        return Employee::query()
            ->whereRaw("REPLACE(REPLACE(phone, '+', ''), ' ', '') LIKE ?", ['%'.$core])
            ->orderBy('id')
            ->first();
    }
}
