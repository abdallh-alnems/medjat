<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$requiredDocumentId = (int) ($input['required_document_id'] ?? 0);
$customName = trim((string) ($input['name'] ?? ''));

Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

// ── Custom request: an ad-hoc document specific to this employee, with its
// details entered by hand and not tied to the company's document catalog. ──
if ($requiredDocumentId <= 0 && $customName !== '') {
    $fields = [
        'name' => mb_substr($customName, 0, 100),
        'description' => ($input['description'] ?? null) ?: null,
        'scope_type' => 'employees',
        'scope_branch_id' => null,
        'is_required' => isset($input['is_required']) && !$input['is_required'] ? 0 : 1,
    ];

    if (!empty($input['category'])) {
        Validator::enum($input['category'],
            ['identity', 'contract', 'certificate', 'insurance', 'general'], 'category');
        $fields['category'] = $input['category'];
    }

    if (isset($input['expiry_days']) && $input['expiry_days'] !== '' && $input['expiry_days'] !== null) {
        $fields['expiry_days'] = (int) $input['expiry_days'] ?: null;
    }

    $resultId = DocumentModel::addRequiredFull($tenantId, $fields);
    DocumentModel::setEmployeeScope($resultId, $tenantId, [$employeeId]);

    AuditLogModel::log($tenantId, $auth['admin_id'], 'document.request', 'employee', $employeeId, [
        'required_document_id' => $resultId,
        'custom' => true,
    ]);

    Response::success([
        'required_document_id' => $resultId,
        'already_requested' => false,
        'custom' => true,
    ]);
}

// ── Catalog request: attach an existing company document type to this
// employee. ──
Validator::required($requiredDocumentId, 'required_document_id');

$type = DocumentModel::getRequiredById($requiredDocumentId, $tenantId);
if (!$type) {
    Response::notFound('Document type');
}

// Idempotent: if the chosen type already applies to this employee (via any
// scope), there is nothing to request — surface it as already requested.
$alreadyRequired = false;
foreach (DocumentModel::getRequiredForEmployee($employeeId, $tenantId) as $rd) {
    if ((int) $rd['id'] === $requiredDocumentId) {
        $alreadyRequired = true;
        break;
    }
}

if ($alreadyRequired) {
    Response::success([
        'required_document_id' => $requiredDocumentId,
        'already_requested' => true,
    ]);
}

if (($type['scope_type'] ?? 'all') === 'employees') {
    // The type is already an employee-scoped catalog entry — just attach this
    // employee to its list.
    DocumentModel::addEmployeeToScope($requiredDocumentId, $tenantId, $employeeId);
    $resultId = $requiredDocumentId;
} else {
    // A broad type (all/branch/category) that does not currently cover this
    // employee. Materialise an employee-scoped copy so the requirement applies
    // to this person only, without altering the shared rule.
    $resultId = DocumentModel::addRequiredFull($tenantId, [
        'name' => $type['name'],
        'description' => $type['description'] ?? null,
        'category' => $type['category'] ?? 'general',
        'expiry_days' => $type['expiry_days'] ?? null,
        'notification_days_before' => $type['notification_days_before'] ?? 30,
        'is_required' => (int) ($type['is_required'] ?? 1) ? 1 : 0,
        'scope_type' => 'employees',
        'scope_branch_id' => null,
    ]);
    DocumentModel::setEmployeeScope($resultId, $tenantId, [$employeeId]);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'document.request', 'employee', $employeeId, [
    'required_document_id' => $resultId,
    'source_type_id' => $requiredDocumentId,
]);

Response::success([
    'required_document_id' => $resultId,
    'already_requested' => false,
]);
