<?php

declare(strict_types=1);

namespace App\Modules\Assets\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Modules\Assets\Domain\AssetCustody;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Notifications\Domain\ManagerAlert;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Ports of api/app/assets/{my_list,request_return}.php.
 *
 * What an employee holds, and saying they are handing it back.
 */
final class MyAssetsController
{
    public function __construct(private readonly ManagerAlert $alert) {}

    public function index(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        // Scoped to the token holder regardless of any parameter: an employee
        // only ever sees their own custody.
        return ApiResponse::success([
            'items' => AssetCustody::forTenant(
                $tenantId,
                AssetController::status($request->query('status')),
                $employee->id,
            ),
        ]);
    }

    /**
     * Half of a two-step exchange: the employee says they are handing it back,
     * and somebody with the item in front of them confirms it. A one-sided
     * return would let anybody clear their own list without the laptop ever
     * reaching a desk.
     */
    public function requestReturn(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $id = Value::int($request->input('id'));
        $asset = $id > 0 ? AssetCustody::find($id, $tenantId) : null;

        // Somebody else's custody is reported as missing rather than forbidden.
        if ($asset === null || Value::int($asset['employee_id'] ?? null) !== $employee->id) {
            throw new ApiFailure(__('messages.custody_not_found'), 404, 'not_found');
        }

        if (Value::string($asset['status'] ?? null) !== 'assigned') {
            throw new ApiFailure(
                __('messages.custody_not_returnable'),
                409,
                'asset_not_returnable',
            );
        }

        $note = trim(Value::string($request->input('return_note'))) ?: null;

        AssetCustody::requestReturn($id, $tenantId, $note);

        AuditLog::record($tenantId, null, 'asset.return_request', 'asset', $id);

        $name = Value::string($asset['name'] ?? null);

        $this->alert->notify(
            $tenantId,
            'approval',
            'طلب إرجاع عهدة',
            'Custody Return Requested',
            "طلب {$employee->name} إرجاع العهدة: {$name}.",
            "{$employee->name} requested to return: {$name}.",
            $employee->id,
            ['type' => 'asset', 'asset_id' => (string) $id, 'action' => 'return_request'],
        );

        return ApiResponse::success(['message' => 'Return requested']);
    }

    private static function employee(Request $request): Employee
    {
        $employee = $request->attributes->get('employee');

        if (! $employee instanceof Employee) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        return $employee;
    }
}
