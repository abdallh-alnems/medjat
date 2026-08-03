<?php

require_once __DIR__ . '/../config/firebase.php';
require_once __DIR__ . '/../models/EmployeeAuthTokenModel.php';
require_once __DIR__ . '/../models/EmployeeModel.php';

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
            "SELECT a.id, a.tenant_id, a.branch_id, a.role, a.is_active, a.active_device_id
             FROM admins a WHERE a.firebase_uid = ? LIMIT 1",
            [$uid]
        );

        if (!$admin) {
            Response::fail('Admin not found', 404);
        }

        if (!$admin['is_active']) {
            // Removal no longer disables the account (it only detaches the
            // company), so an inactive account here is a genuine suspension.
            Response::fail('تم إيقاف حسابك من قِبل المسؤول', 403, 'account_deactivated');
        }

        // Membership guard: a detached admin (removed from their company) whose
        // app still carries a stale company context. Reject so the apps drop it
        // and return to onboarding (join / create a company) — and so a lingering
        // session can never touch a company the admin no longer belongs to.
        $requestTenant = $_SERVER['HTTP_X_TENANT_ID']
            ?? ($input['tenant_id'] ?? $_GET['tenant_id'] ?? null);
        if ($requestTenant !== null && $requestTenant !== '' && empty($admin['tenant_id'])) {
            Response::fail('تمت إزالتك من الشركة من قِبل المسؤول', 403, 'account_removed');
        }

        // Single active session: if a newer login set a different active device,
        // sign this device out. Only enforced when both sides carry a device id
        // so older clients (no header) keep working until they re-login.
        $requestDeviceId = $_SERVER['HTTP_X_DEVICE_ID'] ?? ($input['device_id'] ?? $_GET['device_id'] ?? null);
        if (
            !empty($admin['active_device_id'])
            && is_string($requestDeviceId) && $requestDeviceId !== ''
            && $admin['active_device_id'] !== $requestDeviceId
        ) {
            Response::fail('تم تسجيل الدخول من جهاز آخر', 401, 'session_superseded');
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

    public static function authenticateEmployee(PDO $con): array {
        $input = json_decode(file_get_contents('php://input'), true);
        if (!$input) {
            $input = [];
        }

        $token = $_SERVER['HTTP_X_EMPLOYEE_TOKEN'] ?? $input['employee_token'] ?? $_GET['employee_token'] ?? null;
        if (!$token) {
            Response::fail('Employee token is required', 401);
        }

        $activeToken = EmployeeAuthTokenModel::findActiveByPlain($token);
        if (!$activeToken) {
            Response::fail('جلستك انتهت، يرجى تسجيل الدخول مجدداً', 401);
        }

        $employee = EmployeeModel::findById((int) $activeToken['employee_id'], (int) $activeToken['tenant_id']);
        if (!$employee) {
            Response::fail('Employee not found', 404);
        }

        if (($employee['status'] ?? '') === 'terminated') {
            Response::fail('الحساب موقوف', 403);
        }

        return [
            'employee_id' => (int) $employee['id'],
            'employee'    => $employee,
            'tenant_id'   => (int) $activeToken['tenant_id'],
            'branch_id'   => (int) ($employee['branch_id'] ?? 0),
            'admin_id'    => $employee['admin_id'] ? (int) $employee['admin_id'] : null,
            // The channel this request arrived on. Endpoints derive the recorded
            // attendance origin from here and never from the request body — a
            // body field could be forged to make a browser punch look like an
            // app punch, laundering it past a channel restriction.
            'platform'    => $activeToken['platform'] ?? null,
            'device_id'   => $activeToken['device_id'] ?? null,
            'input'       => $input,
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
