<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'add_managers');

// Only management roles belong on the team page — employees live in the same
// table but must never appear here.
$admins = Database::fetchAll(
    "SELECT a.id, a.name, a.email, a.phone, a.role, a.branch_id, a.is_active,
            a.last_login_at, a.created_at, b.name as branch_name
     FROM admins a
     LEFT JOIN branches b ON b.id = a.branch_id
     WHERE a.tenant_id = ?
       AND a.role IN ('general_manager', 'hr', 'branch_manager', 'attendance', 'viewer')
     ORDER BY a.created_at DESC",
    [$tenantId]
);

Response::success(['items' => $admins]);
