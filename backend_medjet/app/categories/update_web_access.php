<?php
/**
 * Per-category exception to the company browser-attendance switch.
 *
 * true  = this category may use the browser
 * false = this category may not
 * null  = inherit the company switch (the default, and the reason a company that
 *         simply turns the channel on needs no category configuration at all)
 *
 * Behind `manage_company_settings`, not `manage_employees`: this is the same
 * decision as the company switch taken at a finer grain, and someone who may
 * rename a job category should not thereby be able to open the weakest
 * attendance channel for the people in it.
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

if (!array_key_exists('web_attendance_allowed', $input)) {
    Response::fail('web_attendance_allowed is required (true, false or null)', 422, 'web_attendance_allowed_required');
}

$category = EmployeeCategoryModel::findById($id, $tenantId);
if (!$category) {
    Response::notFound('Category');
}

$raw = $input['web_attendance_allowed'];
if ($raw === null || $raw === '') {
    $value = null;
} else {
    $value = filter_var($raw, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
    if ($value === null) {
        Response::fail('web_attendance_allowed must be true, false or null', 422, 'web_attendance_allowed_bool');
    }
    $value = $value ? 1 : 0;
}

$before = $category['web_attendance_allowed'] !== null
    ? (int) $category['web_attendance_allowed']
    : null;

if ($before !== $value) {
    EmployeeCategoryModel::setWebAccess($id, $tenantId, $value);

    AuditLogModel::log(
        $tenantId,
        $auth['admin_id'],
        'employee_category.web_access',
        'employee_category',
        $id,
        ['from' => $before, 'to' => $value]
    );
}

Response::success([
    'category_id' => $id,
    'web_attendance_allowed' => $value !== null ? (bool) $value : null,
]);
