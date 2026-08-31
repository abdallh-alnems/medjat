<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Modules\Attendance\Services\CheckOutAction;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/attendance/check_out.php.
 */
final class CheckOutController
{
    public function __construct(private readonly CheckOutAction $checkOut) {}

    public function __invoke(Request $request): JsonResponse
    {
        $employee = $request->attributes->get('employee');
        if (! $employee instanceof Employee) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        // The channel comes from the session, never the body — see check-in.
        $isWeb = $request->attributes->get('platform') === 'web';

        return ApiResponse::success($this->checkOut->execute(
            employee: $employee,
            tenantId: Value::int($request->attributes->get('tenant_id')),
            input: $request->all(),
            isWeb: $isWeb,
            sessionDeviceId: Value::nullableString($request->attributes->get('device_id')),
        ));
    }
}
