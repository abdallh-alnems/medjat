<?php

declare(strict_types=1);

namespace App\Http\Controllers\AdminSupport;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\SuperAdmin;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/admin/devices/register.php.
 *
 * Registers the support-desk app's push token, so an operator hears about a
 * new ticket rather than discovering it next time they open the panel.
 */
final class AdminDeviceController
{
    private const PLATFORMS = ['android', 'ios', 'web'];

    public function __invoke(Request $request): JsonResponse
    {
        $admin = self::admin($request);

        $token = trim(Value::string($request->input('fcm_token')));

        if ($token === '') {
            throw new ApiFailure('fcm_token is required', 422, 'fcm_token_required');
        }

        $platform = trim(Value::string($request->input('platform'), 'android')) ?: 'android';

        if (! in_array($platform, self::PLATFORMS, true)) {
            throw new ApiFailure('platform must be android, ios or web', 422, 'invalid_platform');
        }

        // A device that names itself gets its own row; one that does not shares
        // a per-operator slot, so a client that never sends an id re-registers
        // in place instead of accumulating a row per sign-in.
        $deviceId = trim(Value::string($request->input('device_id'))) ?: 'default_'.$admin->id;

        DB::table('super_admin_devices')->upsert(
            [[
                'admin_id' => $admin->id,
                'device_id' => $deviceId,
                'fcm_token' => $token,
                'platform' => $platform,
                'device_model' => trim(Value::string($request->input('device_model'))) ?: null,
                'app_version' => trim(Value::string($request->input('app_version'))) ?: null,
                // Re-registering revives a device that was deactivated: the app
                // is plainly installed and signed in again.
                'is_active' => 1,
            ]],
            ['admin_id', 'device_id'],
            ['fcm_token', 'platform', 'device_model', 'app_version', 'is_active'],
        );

        return ApiResponse::success(['registered' => true]);
    }

    private static function admin(Request $request): SuperAdmin
    {
        $admin = $request->attributes->get('super_admin');

        if (! $admin instanceof SuperAdmin) {
            throw new ApiFailure('Admin token required', 401, 'admin_token_required');
        }

        return $admin;
    }
}
