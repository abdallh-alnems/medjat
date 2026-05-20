<?php

require_once __DIR__ . '/../config/firebase.php';

use Kreait\Firebase\Exception\Auth\FailedToVerifyToken;

final class Auth {
    public static function verifyFirebaseToken(string $token) {
        if (empty($token)) {
            Response::fail('Token is required', 400);
        }

        try {
            return FirebaseInit::getAuth()->verifyIdToken($token, false, 60);
        } catch (FailedToVerifyToken $e) {
            Response::fail('Invalid or expired token', 401);
        } catch (Exception $e) {
            error_log('Token verification error: ' . $e->getMessage());
            Response::fail('Authentication failed', 500);
        }
    }

    public static function authenticateUser(PDO $con): array {
        $input = json_decode(file_get_contents('php://input'), true);
        if (!$input) {
            $input = [];
        }

        $token = $input['token'] ?? $_GET['token'] ?? $_SERVER['HTTP_X_FIREBASE_TOKEN'] ?? null;
        if (!$token) {
            Response::fail('Token is required', 400);
        }

        $verifiedToken = self::verifyFirebaseToken($token);
        $uid = $verifiedToken->claims()->get('sub');

        $admin = Database::fetchOne(
            "SELECT a.id, a.tenant_id, a.branch_id, a.role, a.is_active
             FROM admins a WHERE a.firebase_uid = ? LIMIT 1",
            [$uid]
        );

        if (!$admin) {
            Response::fail('Admin not found', 404);
        }

        if (!$admin['is_active']) {
            Response::fail('Account is deactivated', 403);
        }

        return [
            'admin_id' => (int) $admin['id'],
            'tenant_id' => (int) $admin['tenant_id'],
            'branch_id' => $admin['branch_id'] ? (int) $admin['branch_id'] : null,
            'role' => $admin['role'],
            'uid' => $uid,
            'input' => $input,
        ];
    }

    public static function requirePost(): void {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::fail('Method not allowed. Use POST.', 405);
        }
    }

    public static function requireGet(): void {
        if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
            Response::fail('Method not allowed. Use GET.', 405);
        }
    }

    public static function deleteFirebaseUser(string $uid): bool {
        try {
            FirebaseInit::getAuth()->deleteUser($uid);
            return true;
        } catch (Exception $e) {
            error_log('Firebase delete user error: ' . $e->getMessage());
            return false;
        }
    }
}
