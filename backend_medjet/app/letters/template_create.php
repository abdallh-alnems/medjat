<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$input = $auth['input'];
$nameAr = trim((string) ($input['name_ar'] ?? ''));
$bodyAr = trim((string) ($input['body_ar'] ?? ''));

Validator::required($nameAr, 'name_ar');
Validator::required($bodyAr, 'body_ar');
Validator::maxLength($nameAr, 120, 'name_ar');

$id = DocumentTemplateModel::create($tenantId, [
    'name_ar' => $nameAr,
    'name_en' => isset($input['name_en']) ? trim((string) $input['name_en']) : null,
    'body_ar' => $bodyAr,
    'body_en' => isset($input['body_en']) ? trim((string) $input['body_en']) : null,
    'is_active' => isset($input['is_active']) ? (int) (bool) $input['is_active'] : 1,
    'sort_order' => (int) ($input['sort_order'] ?? 0),
]);

AuditLogModel::log($tenantId, $auth['admin_id'], 'document_template.create', 'document_template', $id);

Response::success(['template_id' => $id], 201);
