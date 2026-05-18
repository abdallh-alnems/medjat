<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class NotificationSendAllApi extends AdminBaseApi {
    protected ?string $minRole = 'admin';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $title = $this->getField('title');
            $body = $this->getField('body');
            $data = $this->getField('data');

            Validator::required($title, 'title');
            Validator::required($body, 'body');

            $tokens = Database::fetchAll("SELECT fcm_token FROM admin_devices WHERE is_active = 1");
            $tokenList = array_column($tokens, 'fcm_token');

            $sent = 0;
            if (!empty($tokenList)) {
                try {
                    $messaging = FirebaseInit::getMessaging();
                    $message = [
                        'notification' => ['title' => $title, 'body' => $body],
                        'data' => $data ?: [],
                        'android' => ['priority' => 'high'],
                    ];
                    $report = $messaging->sendMulticast($message, $tokenList);
                    $sent = $report->successes()->count();
                } catch (Exception $e) {
                    error_log('Broadcast notification error: ' . $e->getMessage());
                }
            }

            AdminAuth::logAction('notification.send_all', null, null, ['title' => $title, 'sent' => $sent]);
            $this->success(['sent' => $sent, 'total' => count($tokenList)]);
        }, 'admin.notifications.send_all');
    }
}

new NotificationSendAllApi();
