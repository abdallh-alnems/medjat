<?php
// Platform-wide announcement.
//
// This used to push to every row in `admin_devices` and stop there, which is
// the managers' table — every employee on the platform was silently excluded
// from a message the panel called "send to everyone". The audience is now
// explicit, and the response says how many devices each side actually reached.
require_once __DIR__ . '/../../config/bootstrap.php';

class NotificationSendAllApi extends AdminBaseApi {
    protected ?string $minRole = 'admin';

    public function __construct() {
        parent::__construct();
        Auth::requirePost();

        $this->handleRequest(function () {
            $title = $this->getField('title');
            $body = $this->getField('body');
            $data = $this->getField('data');

            Validator::required($title, 'title');
            Validator::required($body, 'body');

            $audience = (string) $this->getField('audience', 'admins');
            if (!in_array($audience, ['admins', 'employees', 'all'], true)) {
                $this->error('الجمهور غير صالح', 422);
            }

            $sentAdmins = 0;
            $sentEmployees = 0;

            if ($audience === 'admins' || $audience === 'all') {
                $tokens = Database::fetchAll(
                    "SELECT ad.fcm_token FROM admin_devices ad
                     JOIN admins a ON a.id = ad.admin_id
                     WHERE ad.is_active = 1 AND a.role NOT IN ('employee', 'pending')"
                );
                $tokenList = array_column($tokens, 'fcm_token');
                if (!empty($tokenList)) {
                    try {
                        $report = FirebaseInit::getMessaging()->sendMulticast([
                            'notification' => ['title' => $title, 'body' => $body],
                            'data' => $data ?: [],
                            'android' => ['priority' => 'high'],
                        ], $tokenList);
                        $sentAdmins = $report->successes()->count();
                    } catch (Exception $e) {
                        error_log('Broadcast notification error: ' . $e->getMessage());
                    }
                }
            }

            if ($audience === 'employees' || $audience === 'all') {
                $sentEmployees = NotificationService::sendToAllEmployees($title, $body, $data ?: null);
            }

            AdminAuth::logAction('notification.send_all', null, null, [
                'title' => $title,
                'audience' => $audience,
                'sent_admins' => $sentAdmins,
                'sent_employees' => $sentEmployees,
            ]);

            $this->success([
                'audience' => $audience,
                'sent_admins' => $sentAdmins,
                'sent_employees' => $sentEmployees,
                'sent' => $sentAdmins + $sentEmployees,
            ]);
        }, 'admin.notifications.send_all');
    }
}

new NotificationSendAllApi();
