<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$input = $auth['input'];
$id = (int) ($input['request_id'] ?? $_GET['id'] ?? 0);
Validator::required($id, 'request_id');

$request = DocumentRequestModel::find($id, $tenantId);
if (!$request) {
    Response::notFound('Request');
}
if ($request['status'] !== 'pending') {
    Response::fail('Only pending requests can be rejected', 422);
}

$reason = isset($input['rejection_reason']) ? trim((string) $input['rejection_reason']) : null;

DocumentRequestModel::markRejected($id, $tenantId, $auth['admin_id'], $reason);

AuditLogModel::log($tenantId, $auth['admin_id'], 'document_request.reject', 'document_request', $id);

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'document', 'Document Request Rejected', 'تم رفض طلب المستند', 'Your document request has been rejected.', 'تم رفض طلب المستند الخاص بك.', ?, 'in_app', NOW())",
        [$tenantId, (int) $request['employee_id'], json_encode(['request_id' => $id, 'action' => 'reject'])]
    );
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Request rejected', 'request_id' => $id]);
