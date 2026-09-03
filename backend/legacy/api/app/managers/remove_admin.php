<?php
// Remove a team member from the company (detaches them; frees their email
// to join another company). Their account itself is preserved.
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'add_managers');

$input = $auth['input'];
$adminId = (int) ($input['admin_id'] ?? 0);
Validator::required($adminId, 'admin_id');

if ($adminId === (int) $auth['admin_id']) {
    Response::forbidden('لا يمكنك إزالة نفسك من الفريق');
}

$admin = Database::fetchOne(
    "SELECT id, name, email, role FROM admins WHERE id = ? AND tenant_id = ? LIMIT 1",
    [$adminId, $tenantId]
);
if (!$admin) {
    Response::notFound('المدير');
}

$inviterPerms = PermissionMiddleware::effectivePermissions(
    $auth['admin_id'], $tenantId, $auth['role']
);
if ($admin['role'] === 'general_manager' && $inviterPerms !== '*') {
    Response::forbidden('لا يمكنك إزالة مدير عام');
}

// Hierarchy guard: you can never remove a team member who is higher than you
// in the admin hierarchy (i.e. holds a permission you don't have).
$targetPerms = PermissionMiddleware::effectivePermissions($adminId, $tenantId, $admin['role']);
if (!PermissionMiddleware::outranks($inviterPerms, $targetPerms)) {
    Response::forbidden('لا يمكنك إزالة مدير يعلوك في الصلاحيات الإدارية');
}

// Never let the company lose its last general manager.
if ($admin['role'] === 'general_manager') {
    $gmCount = Database::fetchOne(
        "SELECT COUNT(*) AS c FROM admins
         WHERE tenant_id = ? AND role = 'general_manager' AND is_active = 1",
        [$tenantId]
    );
    if ((int) ($gmCount['c'] ?? 0) <= 1) {
        Response::fail('لا يمكن إزالة آخر مدير عام للشركة', 409, 'cannot_remove_last_owner');
    }
}

$pdo = db();
try {
    $pdo->beginTransaction();

    // Detach from the company but KEEP the account active, so the person can
    // sign back in and land on onboarding (join / create another company).
    // Reset the role to the no-company default and clear the device binding.
    $stmt = $pdo->prepare(
        "UPDATE admins SET tenant_id = NULL, branch_id = NULL, role = 'pending',
                is_active = 1, active_device_id = NULL
         WHERE id = ? AND tenant_id = ?"
    );
    $stmt->execute([$adminId, $tenantId]);

    $stmt = $pdo->prepare(
        "DELETE FROM custom_roles WHERE admin_id = ? AND tenant_id = ?"
    );
    $stmt->execute([$adminId, $tenantId]);

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log('Remove admin failed: ' . $e->getMessage());
    Response::fail('تعذّر إزالة المدير', 500, 'remove_admin_failed');
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'admin.removed', 'admin', $adminId);

// Notify the removed person (in-app record, FCM push, email) *after* the
// response is sent — these are slow side-effects that must not block the
// request. The app itself force-signs them out on their next call (the backend
// now returns `account_removed`), and this is the heads-up they receive.
$tenantRow = Database::fetchOne(
    "SELECT name FROM tenants WHERE id = ? LIMIT 1",
    [$tenantId]
);
$companyName = $tenantRow['name'] ?? '';
$removedEmail = $admin['email'] ?? '';
$removedName = $admin['name'] ?? '';
$actorId = (int) $auth['admin_id'];

Background::defer(static function () use (
    $adminId, $tenantId, $actorId, $removedEmail, $removedName, $companyName
) {
    $titleAr = 'تمت إزالتك من الشركة';
    $title = 'You were removed from the company';
    $bodyAr = $companyName !== ''
        ? "تمت إزالتك من فريق «{$companyName}». لم يعد بإمكانك الوصول إلى بيانات الشركة."
        : 'تمت إزالتك من الشركة. لم يعد بإمكانك الوصول إلى بيانات الشركة.';
    $body = $companyName !== ''
        ? "You have been removed from “{$companyName}”. You no longer have access to the company's data."
        : "You have been removed from the company. You no longer have access to the company's data.";

    // In-app notification (push + inbox record).
    try {
        NotificationService::sendToUser($adminId, $titleAr, $bodyAr, ['type' => 'admin_removed']);
        Database::execute(
            "INSERT INTO notifications (tenant_id, admin_id, type, title, title_ar, body, body_ar, data, sent_via)
             VALUES (?, ?, 'system', ?, ?, ?, ?, ?, 'push,email,in_app')",
            [
                $tenantId,
                $adminId,
                $title,
                $titleAr,
                $body,
                $bodyAr,
                json_encode(['type' => 'admin_removed'], JSON_UNESCAPED_UNICODE),
            ]
        );
    } catch (\Throwable $e) {
        error_log('Remove admin notify failed: ' . $e->getMessage());
    }

    // Email.
    if ($removedEmail !== '') {
        try {
            $safeName = htmlspecialchars($removedName !== '' ? $removedName : 'مستخدم Permedjat', ENT_QUOTES, 'UTF-8');
            $safeCompany = htmlspecialchars($companyName, ENT_QUOTES, 'UTF-8');
            $companyLine = $companyName !== ''
                ? "تمت إزالتك من فريق «{$safeCompany}» على Permedjat."
                : 'تمت إزالتك من الشركة على Permedjat.';
            $html = '<!DOCTYPE html><html dir="rtl" lang="ar">'
                . '<head><meta charset="UTF-8"></head>'
                . '<body style="font-family:\'IBM Plex Sans Arabic\',Tahoma,Arial,sans-serif;direction:rtl;text-align:right;padding:24px;background:#f9f9f9;">'
                . '<div style="max-width:480px;margin:0 auto;background:#fff;border-radius:12px;padding:32px;box-shadow:0 2px 8px rgba(0,0,0,0.06);">'
                . '<h2 style="color:#1a1a1a;margin:0 0 16px;">تمت إزالتك من الشركة</h2>'
                . '<p style="color:#444;font-size:15px;line-height:1.7;">مرحباً ' . $safeName . '،</p>'
                . '<p style="color:#444;font-size:15px;line-height:1.7;">' . $companyLine . ' لم يعد بإمكانك الوصول إلى بيانات الشركة، وقد تم تسجيل خروجك من التطبيق.</p>'
                . '<hr style="border:none;border-top:1px solid #eee;margin:20px 0;">'
                . '<p style="color:#888;font-size:13px;line-height:1.6;">إن كنت تعتقد أن ذلك تم عن طريق الخطأ، يُرجى التواصل مع مسؤول الشركة.</p>'
                . '</div></body></html>';
            EmailService::send($removedEmail, 'تمت إزالتك من الشركة في Permedjat', $html);
        } catch (\Throwable $e) {
            error_log('Remove admin email failed: ' . $e->getMessage());
        }
    }

    // Notify the *other* team managers that this person was removed (push +
    // in-app row each). The removed person is already detached (tenant_id NULL)
    // so they're excluded automatically; we also skip the admin who did it.
    try {
        $displayName = $removedName !== ''
            ? $removedName
            : ($removedEmail !== '' ? $removedEmail : 'عضو');

        $teamTitleAr = 'تمت إزالة عضو من الفريق';
        $teamTitle = 'A team member was removed';
        $teamBodyAr = "تمت إزالة {$displayName} من الفريق.";
        $teamBody = "{$displayName} was removed from the team.";

        $others = Database::fetchAll(
            "SELECT id FROM admins
             WHERE tenant_id = ? AND role NOT IN ('employee', 'pending') AND id <> ?",
            [$tenantId, $actorId]
        );
        $otherIds = array_map(static fn($r) => (int) $r['id'], $others);

        if (!empty($otherIds)) {
            NotificationService::sendToManyAdmins(
                $otherIds,
                $teamTitleAr,
                $teamBodyAr,
                ['type' => 'admin_removed_team']
            );

            $dataJson = json_encode(
                ['type' => 'admin_removed_team', 'removed_admin_id' => $adminId],
                JSON_UNESCAPED_UNICODE
            );
            foreach ($otherIds as $mid) {
                Database::execute(
                    "INSERT INTO notifications
                       (tenant_id, admin_id, type, title, title_ar, body, body_ar, data, sent_via)
                     VALUES (?, ?, 'system', ?, ?, ?, ?, ?, 'push,in_app')",
                    [$tenantId, $mid, $teamTitle, $teamTitleAr, $teamBody, $teamBodyAr, $dataJson]
                );
            }
        }
    } catch (\Throwable $e) {
        error_log('Remove admin team-notify failed: ' . $e->getMessage());
    }
});

Response::success(['message' => 'تمت إزالة المدير من الفريق']);
