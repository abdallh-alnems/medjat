<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

class ForceUpdateApi extends AdminBaseApi {
    protected ?string $minRole = 'superadmin';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $platform = $this->getField('platform', 'all');
            $minVersion = $this->getField('min_version');
            $message = $this->getField('message', 'Please update the app to continue');

            Validator::required($minVersion, 'min_version');

            Database::execute(
                "INSERT INTO force_updates (platform, min_version, message, is_active) VALUES (?, ?, ?, 1)
                 ON DUPLICATE KEY UPDATE min_version = VALUES(min_version), message = VALUES(message), is_active = 1",
                [$platform, $minVersion, $message]
            );

            AdminAuth::logAction('force_update.trigger', null, null, [
                'platform' => $platform,
                'min_version' => $minVersion,
            ]);

            $this->success(['message' => 'Force update triggered']);
        }, 'admin.force_update.trigger');
    }
}

new ForceUpdateApi();
