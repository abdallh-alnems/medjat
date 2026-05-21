<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$templateId = (int) ($input['template_id'] ?? 0);
Validator::required($employeeId, 'employee_id');
Validator::required($templateId, 'template_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$template = DocumentTemplateModel::find($templateId, $tenantId);
if (!$template) {
    Response::notFound('Template');
}

$extra = [];
if (isset($input['extra_fields']) && is_array($input['extra_fields'])) {
    foreach ($input['extra_fields'] as $k => $v) {
        if (is_string($k)) {
            $extra[$k] = is_scalar($v) ? (string) $v : '';
        }
    }
}

// Admin-issued requests are created already approved, then the PDF is generated.
$requestId = DocumentRequestModel::create(
    $tenantId,
    $employeeId,
    $templateId,
    $template['template_key'] ?? null,
    $extra,
    'pending',
    false,
    $auth['admin_id']
);

$request = DocumentRequestModel::find($requestId, $tenantId);

try {
    $pdfPath = LetterPdfService::generateForRequest($request, $tenantId);
    DocumentRequestModel::markApproved($requestId, $tenantId, $auth['admin_id'], $pdfPath);
} catch (Throwable $e) {
    error_log('Letter PDF generation failed: ' . $e->getMessage());
    Response::error('Document created but PDF generation failed: ' . $e->getMessage(), 500);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'document_request.issue', 'document_request', $requestId);

Response::success(['request_id' => $requestId, 'status' => 'approved'], 201);
