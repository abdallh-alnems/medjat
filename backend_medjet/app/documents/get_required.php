<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$documents = DocumentModel::getAllRequiredByTenant($tenantId);

foreach ($documents as &$doc) {
    if (($doc['scope_type'] ?? 'all') === 'employees') {
        $doc['scope_employee_ids'] = DocumentModel::getEmployeeScope((int) $doc['id'], $tenantId);
    } else {
        $doc['scope_employee_ids'] = [];
    }
    if (($doc['scope_type'] ?? 'all') === 'category') {
        $doc['scope_category_ids'] = DocumentModel::getCategoryScope((int) $doc['id'], $tenantId);
    } else {
        $doc['scope_category_ids'] = [];
    }
}
unset($doc);

Response::success(['required_documents' => $documents]);
