<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'add_managers');

$invitationId = (int) ($_GET['id'] ?? 0);
if (!$invitationId) Response::fail('معرّف الدعوة مطلوب', 422, 'invitation_id_required');

$invitation = Database::fetchOne(
    "SELECT id, accepted_at, cancelled_at FROM manager_invitations
     WHERE id = ? AND tenant_id = ? LIMIT 1",
    [$invitationId, $tenantId]
);

if (!$invitation) Response::notFound('الدعوة');
if ($invitation['accepted_at']) Response::fail('الدعوة مقبولة بالفعل', 409, 'invitation_already_accepted');
if ($invitation['cancelled_at']) Response::fail('الدعوة ملغاة بالفعل', 409, 'invitation_already_cancelled');

ManagerInvitationModel::cancel($invitationId, $tenantId);
AuditLogModel::log($tenantId, $auth['admin_id'], 'manager.cancel_invite', 'invitation', $invitationId);

Response::success(['message' => 'تم إلغاء الدعوة']);
