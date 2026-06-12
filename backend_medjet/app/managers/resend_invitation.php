<?php
// Regenerate a fresh code for an existing (pending/expired/cancelled) invitation
// and extend its validity. Accepted invitations cannot be regenerated.
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'add_managers');

$input = $auth['input'];
$invitationId = (int) ($_GET['id'] ?? $input['id'] ?? 0);
if (!$invitationId) Response::fail('معرّف الدعوة مطلوب', 422);

$invitation = Database::fetchOne(
    "SELECT id, accepted_at FROM manager_invitations WHERE id = ? AND tenant_id = ? LIMIT 1",
    [$invitationId, $tenantId]
);
if (!$invitation) Response::notFound('الدعوة');
if ($invitation['accepted_at']) Response::fail('الدعوة مقبولة بالفعل', 409);

$result = ManagerInvitationModel::regenerate($invitationId, $tenantId);
if (!$result) Response::fail('تعذّر إعادة إنشاء الدعوة', 500);

AuditLogModel::log($tenantId, $auth['admin_id'], 'manager.resend_invite', 'invitation', $invitationId);

Response::success([
    'invitation_id' => $invitationId,
    'invitation_code' => $result['code'],
    'expires_at' => $result['expires_at'],
    'expires_in_hours' => 72,
]);
