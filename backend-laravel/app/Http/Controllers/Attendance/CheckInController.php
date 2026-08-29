<?php

declare(strict_types=1);

namespace App\Http\Controllers\Attendance;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Employee;
use App\Services\Attendance\CheckInAction;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/attendance/check_in.php.
 */
final class CheckInController
{
    public function __construct(private readonly CheckInAction $checkIn) {}

    public function __invoke(Request $request): JsonResponse
    {
        $employee = $request->attributes->get('employee');
        if (! $employee instanceof Employee) {
            throw new ApiFailure('Authentication required', 401);
        }

        // The channel comes from the authenticated session, never from the
        // request body. A body field could be forged to make a browser punch
        // present itself as an app punch, laundering it past a company that
        // restricted the channel.
        $isWeb = $request->attributes->get('platform') === 'web';

        $result = $this->checkIn->execute(
            employee: $employee,
            tenantId: Value::int($request->attributes->get('tenant_id')),
            input: $request->all(),
            isWeb: $isWeb,
            sessionDeviceId: Value::nullableString($request->attributes->get('device_id')),
        );

        return ApiResponse::success($result);
    }
}
