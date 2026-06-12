<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

// The activity log exposes every management action across the company, so it is
// gated behind the same permission as the company settings hub.
PermissionMiddleware::check($auth, 'manage_company_settings');

$page = max(1, (int) ($_GET['page'] ?? 1));
$adminId = isset($_GET['admin_id']) && $_GET['admin_id'] !== ''
    ? (int) $_GET['admin_id']
    : null;
$category = isset($_GET['category']) && $_GET['category'] !== ''
    ? (string) $_GET['category']
    : null;

// High-level category -> the `action` prefixes it covers. Keep this in sync
// with the Arabic labels/categories on the client (audit_actions.dart).
$categoryPrefixes = [
    'employees' => [
        'employee.', 'employee_category.', 'document.', 'document_type.',
        'documents.', 'biometric.', 'warning.', 'profile.',
        'onboarding.', 'onboarding_task.', 'onboarding_template.',
    ],
    'attendance' => ['attendance.', 'break.', 'station.'],
    'schedule'   => ['schedule.', 'shift.'],
    'leaves'     => ['leave.'],
    'finance'    => ['loan.', 'deduction.', 'bonus.', 'payroll.', 'settlement.', 'asset.'],
    'recruitment' => ['candidate.', 'job_opening.'],
    'performance' => ['performance_cycle.', 'performance_goal.', 'performance_review.', 'kudos.', 'survey.'],
    'engagement' => ['announcement.', 'analytics.'],
    'settings'   => ['tenant.', 'branch.', 'approval_chain.', 'export_template.', 'manager.', 'admin.'],
];
$prefixes = ($category !== null && isset($categoryPrefixes[$category]))
    ? $categoryPrefixes[$category]
    : null;

$result = AuditLogModel::getFeed($tenantId, $page, 50, $adminId, $prefixes);

$response = [
    'items'    => $result['items'],
    'page'     => $page,
    'has_more' => $result['has_more'],
];
// The actor list only changes slowly; send it once with the first page so the
// client can build its "filter by who" dropdown without an extra round-trip.
if ($page === 1) {
    $response['actors'] = AuditLogModel::getActors($tenantId);
}

Response::success($response);
