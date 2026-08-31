<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Models\Employee;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/auth/update_fcm_token.php.
 *
 * Shared by both apps: the employee app arrives holding an employee token and
 * the management app a Firebase one. Either way the push token lands in
 * admin_devices against the same admins row, because that is where an employee's
 * identity lives too.
 */
final class UpdateFcmTokenController
{
    public function __invoke(Request $request): JsonResponse
    {
        $adminId = $this->adminId($request);

        $fcmToken = trim(Value::string($request->input('fcm_token')));
        if ($fcmToken === '') {
            throw new ApiFailure('fcm_token is required', 400, 'fcm_token_required');
        }

        $platform = Value::string($request->input('platform'), 'android');
        $deviceId = Value::nullableString($request->input('device_id'));

        $existingId = DB::table('admin_devices')
            ->where('admin_id', $adminId)
            ->where('fcm_token', $fcmToken)
            ->value('id');

        if ($existingId !== null) {
            DB::table('admin_devices')->where('id', $existingId)->update([
                'is_active' => 1,
                'platform' => $platform,
                'device_id' => $deviceId,
                'updated_at' => DB::raw('NOW()'),
            ]);
        } else {
            DB::table('admin_devices')->upsert(
                [[
                    'admin_id' => $adminId,
                    'fcm_token' => $fcmToken,
                    'platform' => $platform,
                    'device_id' => $deviceId,
                    'is_active' => 1,
                ]],
                ['fcm_token'],
                ['platform', 'is_active', 'updated_at'],
            );
        }

        // One active token per account. A stale one left active means the same
        // handset receives every push more than once.
        DB::table('admin_devices')
            ->where('admin_id', $adminId)
            ->where('fcm_token', '!=', $fcmToken)
            ->update(['is_active' => 0]);

        return ApiResponse::success(['message' => 'FCM token updated']);
    }

    private function adminId(Request $request): int
    {
        $employee = $request->attributes->get('employee');
        $admin = $request->attributes->get('admin');

        $adminId = match (true) {
            $employee instanceof Employee => $employee->admin_id,
            $admin instanceof Admin => $admin->id,
            default => null,
        };

        if ($adminId === null) {
            throw new ApiFailure(
                __('messages.no_account_for_notifications'),
                422,
                'account_linked_receive_notifications'
            );
        }

        return $adminId;
    }
}
