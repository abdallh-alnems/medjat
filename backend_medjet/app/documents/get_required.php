<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$documents = DocumentModel::getAllRequiredByTenant($tenantId);

foreach ($documents as &$doc) {
    if (($doc['scope_type'] ?? 'all') === 'employees') {
        // Detailed (id + name) joined to employees, so only employees that
        // still exist are returned; derive the ids from the same set so the
        // count and the names always match.
        $emps = DocumentModel::getEmployeeScopeDetailed((int) $doc['id'], $tenantId);
        $doc['scope_employees'] = $emps;
        $doc['scope_employee_ids'] = array_map(fn($e) => $e['id'], $emps);
    } else {
        $doc['scope_employees'] = [];
        $doc['scope_employee_ids'] = [];
    }
    if (($doc['scope_type'] ?? 'all') === 'category') {
        $cats = DocumentModel::getCategoryScopeDetailed((int) $doc['id'], $tenantId);
        $doc['scope_categories'] = $cats;
        $doc['scope_category_ids'] = array_map(fn($c) => $c['id'], $cats);
    } else {
        $doc['scope_categories'] = [];
        $doc['scope_category_ids'] = [];
    }
}
unset($doc);

Response::success(['required_documents' => $documents]);
