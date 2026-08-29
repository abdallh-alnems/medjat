<?php
// Permanently delete the signed-in admin's account from the database and Firebase.
// If the caller is the last general_manager of their company, the whole company
// (tenant) is deleted with all its data — companies have no owner, so a company
// must always have at least one full-access admin or cease to exist.

require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$auth = Auth::authenticateUser(db());
$adminId = $auth['admin_id'];
$tenantId = $auth['tenant_id'];
$uid = $auth['uid'];

$deletedCompany = false;

$pdo = db();
try {
    $pdo->beginTransaction();

    if ($tenantId && $auth['role'] === 'general_manager') {
        // Is this the last general_manager in the company?
        $others = Database::fetchOne(
            "SELECT COUNT(*) AS cnt FROM admins
             WHERE tenant_id = ? AND role = 'general_manager' AND id <> ?",
            [$tenantId, $adminId]
        );
        if ((int) ($others['cnt'] ?? 0) === 0) {
            // Last full-access admin: delete the entire company.
            // All tenant-scoped tables (including admins) cascade on delete.
            $stmt = $pdo->prepare("DELETE FROM tenants WHERE id = ?");
            $stmt->execute([$tenantId]);
            $deletedCompany = true;
        }
    }

    if (!$deletedCompany) {
        // Delete only this admin. References cascade or null out automatically.
        $stmt = $pdo->prepare("DELETE FROM admins WHERE id = ?");
        $stmt->execute([$adminId]);
    }

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('Delete account failed: ' . $e->getMessage());
    Response::fail('Failed to delete account', 500, 'failed_delete_account');
}

// Remove the Firebase user (best-effort — DB record is already gone).
Auth::deleteFirebaseUser($uid);

Response::success([
    'success' => true,
    'deleted_company' => $deletedCompany,
    'message' => $deletedCompany ? 'Company and account deleted' : 'Account deleted',
]);
