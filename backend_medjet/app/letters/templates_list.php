<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

// Seed the built-in templates on first access for this tenant.
DocumentTemplateModel::ensureDefaults($tenantId);

$templates = DocumentTemplateModel::getByTenant($tenantId);

Response::success([
    'templates' => $templates,
    'variables' => LetterPdfService::availableVariables(),
]);
