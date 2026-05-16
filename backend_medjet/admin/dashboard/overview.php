<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class AdminDashboardApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $totalTenants = Database::fetchOne("SELECT COUNT(*) as count FROM tenants")['count'];
            $activeTenants = Database::fetchOne("SELECT COUNT(*) as count FROM tenants WHERE is_active = 1")['count'];
            $totalUsers = Database::fetchOne("SELECT COUNT(*) as count FROM users")['count'];
            $totalEmployees = Database::fetchOne("SELECT COUNT(*) as count FROM employees WHERE status = 'active'")['count'];
            $activeSubs = Database::fetchOne("SELECT COUNT(*) as count FROM subscriptions WHERE status = 'active'")['count'];

            $this->success([
                'total_tenants' => (int) $totalTenants,
                'active_tenants' => (int) $activeTenants,
                'total_users' => (int) $totalUsers,
                'total_employees' => (int) $totalEmployees,
                'active_subscriptions' => (int) $activeSubs,
            ]);
        }, 'admin.dashboard.overview');
    }
}

new AdminDashboardApi();
