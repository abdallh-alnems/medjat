<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'documents_manage_types');

$count = DocumentModel::markExpiredDocuments($tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'documents.mark_expired', null, null, ['count' => $count]);

Response::success(['marked_expired' => $count]);
