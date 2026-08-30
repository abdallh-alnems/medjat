<?php

declare(strict_types=1);

namespace App\Modules\AppControl\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\SuperAdmin;
use App\Modules\Notifications\Domain\PushSender;
use App\Modules\SuperAdmin\Domain\SuperAdminAudit;
use App\Shared\RemoteConfig\FirebaseRemoteConfigAdmin;
use App\Shared\RemoteConfig\RemoteConfigAdmin;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Ports of api/app/admin_app_control/{get,set}.php.
 *
 * The minimum build each app may run, and whether it is in maintenance.
 *
 * The most consequential screen in the product: raising a minimum version locks
 * out every installed build below it, and for the kiosk that means somebody has
 * to physically visit each branch. Hence superadmin only, and hence every
 * change carries its previous value into the audit log.
 */
final class AppControlController
{
    public function __construct(
        private readonly RemoteConfigAdmin $config,
        private readonly PushSender $push,
    ) {}

    public function show(): JsonResponse
    {
        return ApiResponse::success(['apps' => $this->config->all()]);
    }

    public function save(Request $request): JsonResponse
    {
        $admin = self::admin($request);

        $app = trim(Value::string($request->input('app')));

        if (! in_array($app, FirebaseRemoteConfigAdmin::apps(), true)) {
            throw new ApiFailure('Invalid app', 422, 'invalid_app');
        }

        $minVersion = $request->has('min_version')
            ? trim(Value::string($request->input('min_version')))
            : '';

        $maintenance = $request->has('maintenance') ? $request->input('maintenance') : null;

        if ($minVersion !== '' && preg_match('/^\d+(\.\d+){0,3}$/', $minVersion) !== 1) {
            throw new ApiFailure(
                'Invalid version format. Use dotted numeric (e.g. 1.2.0)',
                422,
                'invalid_version_format_dotted_numeric',
            );
        }

        if ($maintenance !== null && ! is_bool($maintenance)) {
            throw new ApiFailure('Maintenance must be a boolean', 422, 'maintenance_boolean');
        }

        if ($minVersion === '' && $maintenance === null) {
            throw new ApiFailure(
                'No changes provided. Send min_version and/or maintenance.',
                422,
                'changes_provided_send_min_version',
            );
        }

        $result = ['app' => $app];

        if ($minVersion !== '') {
            $changed = $this->config->setMinVersion($app, $minVersion);
            $result['min_version'] = $changed['min_version'];

            SuperAdminAudit::record($admin->id, 'app_control.set_version', 'remote_config', null, [
                'app' => $app,
                'from' => $changed['previous_min_version'],
                'to' => $minVersion,
            ]);
        }

        if ($maintenance !== null) {
            $changed = $this->config->setMaintenance($app, $maintenance);
            $result['maintenance'] = $changed['maintenance'];

            SuperAdminAudit::record($admin->id, 'app_control.set_maintenance', 'remote_config', null, [
                'app' => $app,
                'from' => $changed['previous_maintenance'],
                'to' => $maintenance,
            ]);

            // An instant signal alongside the config change. Remote Config's
            // realtime stream only reaches an app that is foregrounded, so
            // without this a maintenance switch takes effect whenever each
            // device next happens to look — which is not what anybody means by
            // "enable maintenance".
            $this->push->toTopic("maintenance_{$app}", [
                'type' => 'maintenance_mode',
                'app' => $app,
                'enabled' => $maintenance ? '1' : '0',
            ]);
        }

        return ApiResponse::success($result);
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
