<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

// Touches both the leaves and attendance tables.
PermissionMiddleware::check($auth, 'manage_leaves');
PermissionMiddleware::check($auth, 'manage_attendance');

$input = $auth['input'];
$leaveId = (int) ($input['leave_id'] ?? $_GET['id'] ?? 0);
$reason = isset($input['reason']) && trim((string) $input['reason']) !== '' ? trim((string) $input['reason']) : null;
Validator::required($leaveId, 'leave_id');

$result = LeaveModel::convertToAbsence($leaveId, $tenantId, $auth['admin_id'], $reason);

AuditLogModel::log($tenantId, $auth['admin_id'], 'leave.convert_to_absence', 'leave', $leaveId, [
    'days' => $result['days'],
]);

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'leave', 'Leave Changed to Absence', 'تم تحويل الإجازة إلى غياب', 'Your leave was changed to absence.', 'تم تحويل إجازتك إلى غياب.', ?, 'in_app', NOW())",
        [$tenantId, $result['employee_id'], json_encode(['leave_id' => $leaveId, 'action' => 'convert_to_absence'])]
    );
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Leave converted to absence', 'days' => $result['days']]);
