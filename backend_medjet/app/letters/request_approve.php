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
    Response::fail('Only pending requests can be approved', 422);
}

// Allow overriding/adding extra fields at approval time (e.g. bank name).
if (isset($input['extra_fields']) && is_array($input['extra_fields'])) {
    $extra = DocumentRequestModel::decodeExtra($request['extra_fields'] ?? null);
    foreach ($input['extra_fields'] as $k => $v) {
        if (is_string($k)) {
            $extra[$k] = is_scalar($v) ? (string) $v : '';
        }
    }
    $request['extra_fields'] = json_encode($extra, JSON_UNESCAPED_UNICODE);
}

try {
    $pdfPath = LetterPdfService::generateForRequest($request, $tenantId);
} catch (Throwable $e) {
    error_log('Letter PDF generation failed: ' . $e->getMessage());
    Response::error('PDF generation failed: ' . $e->getMessage(), 500);
}

DocumentRequestModel::markApproved($id, $tenantId, $auth['admin_id'], $pdfPath);

AuditLogModel::log($tenantId, $auth['admin_id'], 'document_request.approve', 'document_request', $id);

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'document', 'Document Ready', 'مستندك جاهز', 'Your requested document has been issued.', 'تم إصدار المستند الذي طلبته.', ?, 'in_app', NOW())",
        [$tenantId, (int) $request['employee_id'], json_encode(['request_id' => $id, 'action' => 'approve'])]
    );
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Request approved', 'request_id' => $id]);
