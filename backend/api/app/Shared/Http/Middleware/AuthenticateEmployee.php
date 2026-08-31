<?php

declare(strict_types=1);

namespace App\Shared\Http\Middleware;

use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Shared\Http\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Authenticates the employee apps and the browser attendance channel.
 *
 * Replaces Auth::authenticateEmployee(). The token is accepted from the header
 * or the body because builds already in the stores send it both ways.
 */
final class AuthenticateEmployee
{
    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->header('X-Employee-Token')
            ?? $request->input('employee_token')
            ?? $request->query('employee_token');

        if (! is_string($token) || $token === '') {
            return ApiResponse::fail('Employee token is required', 401);
        }

        $authToken = EmployeeAuthToken::findActiveByPlain($token);
        if ($authToken === null) {
            return ApiResponse::fail('جلستك انتهت، يرجى تسجيل الدخول مجدداً', 401);
        }

        $employee = Employee::query()
            ->forTenant($authToken->tenant_id)
            ->whereKey($authToken->employee_id)
            ->first();

        if ($employee === null) {
            return ApiResponse::fail('Employee not found', 404);
        }

        if ($employee->isTerminated()) {
            return ApiResponse::fail('الحساب موقوف', 403);
        }

        // The channel is taken from the session, never from the request body.
        // A body field could be forged to make a browser request present itself
        // as an app request and slip past a company that restricted the channel.
        $request->attributes->set('employee', $employee);
        $request->attributes->set('tenant_id', $authToken->tenant_id);
        $request->attributes->set('platform', $authToken->platform);
        $request->attributes->set('device_id', $authToken->device_id);

        return $next($request);
    }
}
