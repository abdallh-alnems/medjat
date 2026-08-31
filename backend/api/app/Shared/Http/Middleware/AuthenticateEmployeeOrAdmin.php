<?php

declare(strict_types=1);

namespace App\Shared\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * For the handful of endpoints both apps call.
 *
 * The employee app presents X-Employee-Token and the management app a Firebase
 * token, so the principal is decided by which credential arrived rather than by
 * anything the caller asks for. Presenting an employee token never grants
 * administrator context, and vice versa — each branch runs its own guard in
 * full, including the membership and single-device checks.
 */
final class AuthenticateEmployeeOrAdmin
{
    public function __construct(
        private readonly AuthenticateEmployee $employee,
        private readonly AuthenticateAdmin $admin,
    ) {}

    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $employeeToken = $request->header('X-Employee-Token')
            ?? $request->input('employee_token')
            ?? $request->query('employee_token');

        $hasEmployeeToken = is_string($employeeToken) && $employeeToken !== '';

        return $hasEmployeeToken
            ? $this->employee->handle($request, $next)
            : $this->admin->handle($request, $next);
    }
}
