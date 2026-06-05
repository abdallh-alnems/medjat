<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_recruitment');

$candidateId = (int) ($_GET['candidate_id'] ?? 0);
$templateId = (int) ($_GET['template_id'] ?? 0);
Validator::required($candidateId, 'candidate_id');
Validator::required($templateId, 'template_id');

$candidate = CandidateModel::findById($candidateId, $tenantId);
if (!$candidate) {
    Response::notFound('Candidate');
}

$template = DocumentTemplateModel::find($templateId, $tenantId);
if (!$template) {
    Response::notFound('Template');
}

$tenant = TenantModel::findById($tenantId);
if (!$tenant) {
    Response::error('Tenant not found', 500);
}

$employee = null;
if ($candidate['converted_employee_id']) {
    $employee = EmployeeModel::findById((int) $candidate['converted_employee_id'], $tenantId);
}
if (!$employee) {
    $employee = [
        'name' => $candidate['name'],
        'job_title' => null,
        'national_id' => null,
        'iqama_number' => null,
        'nationality' => null,
        'branch_name' => null,
        'hire_date' => null,
        'contract_type' => null,
        'base_salary' => $candidate['expected_salary'] ?? 0,
        'employee_code' => null,
        'department' => null,
    ];
}

$extra = [
    'addressed_to' => $candidate['name'] ?? '',
];

$vars = LetterPdfService::buildVariables($tenant, $employee, $extra);
$bodyText = LetterPdfService::substitute($template['body_ar'] ?? '', $vars);
$titleAr = $template['name_ar'] ?? 'Offer Letter';

$filePath = LetterPdfService::generate($tenant, $employee, $template, $extra, $candidateId);

$downloadName = 'offer_' . $candidateId . '.pdf';

header('Content-Type: application/pdf');
header('Content-Disposition: inline; filename="' . $downloadName . '"');
header('Content-Length: ' . filesize($filePath));
header('Cache-Control: private, max-age=0, must-revalidate');
readfile($filePath);
exit;
