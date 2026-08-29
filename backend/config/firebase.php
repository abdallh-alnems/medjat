<?php

require_once __DIR__ . '/../vendor/autoload.php';

use Kreait\Firebase\Factory;
use Kreait\Firebase\Auth;
use Kreait\Firebase\Messaging;

final class FirebaseInit {
    private static ?Auth $auth = null;
    private static ?Messaging $messaging = null;

    public static function getAuth(): Auth {
        if (self::$auth === null) {
            $credentialsPath = getenv('FIREBASE_CREDENTIALS_PATH')
                ?: __DIR__ . '/../core/firebase_credentials.json';

            if (!file_exists($credentialsPath)) {
                error_log('Firebase credentials file not found: ' . $credentialsPath);
                return self::$auth;
            }

            $factory = (new Factory)->withServiceAccount($credentialsPath);
            self::$auth = $factory->createAuth();
        }
        return self::$auth;
    }

    public static function getMessaging(): Messaging {
        if (self::$messaging === null) {
            $credentialsPath = getenv('FIREBASE_CREDENTIALS_PATH')
                ?: __DIR__ . '/../core/firebase_credentials.json';

            $factory = (new Factory)->withServiceAccount($credentialsPath);
            self::$messaging = $factory->createMessaging();
        }
        return self::$messaging;
    }
}
