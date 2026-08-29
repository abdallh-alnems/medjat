<?php
// Everything we know about one client company, on one screen.
//
// The panel used to show a company's name and whether it was active, and that
// was all — every other question ("how many employees do they have?", "which
// attendance method are they on?", "has anyone used the system this week?")
// meant an SSH session and hand-written SQL, which the project rules forbid.
// This endpoint is the answer to those questions.
//
// Read-only by construction: it selects, it never writes, and `readonly` may
// call it.
require_once __DIR__ . '/../../../config/bootstrap.php';

class TenantDetailApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $id = (int) $this->getField('id');
            if ($id <= 0) {
                $this->error('معرّف الشركة مطلوب', 422);
            }

            $tenant = Database::fetchOne(
                "SELECT id, name, is_active, timezone, timezone_is_explicit, currency, country_code,
                        cycle_start_day, week_start_day, created_at,
                        contact_name, contact_email, contact_phone, ops_notes,
                        attendance_methods, allow_offline_attendance, reject_mock_location,
                        require_local_biometric, web_attendance_enabled,
                        face_match_threshold, face_liveness_required, face_enforce_mode,
                        default_annual_leave_days, last_absence_date,
                        commercial_register, company_address, company_phone
                 FROM tenants WHERE id = ? LIMIT 1",
                [$id]
            );
            if (!$tenant) {
                $this->notFound('Tenant');
            }

            // Time is per tenant: "today" for a Gulf company is not our today.
            $today = TenantClock::date($id);

            $employees = Database::fetchOne(
                "SELECT COUNT(*) AS total,
                        SUM(status = 'active') AS active,
                        SUM(status = 'pending_activation') AS pending,
                        SUM(biometric_enrollment_status <> 'not_enrolled') AS enrolled_biometric
                 FROM employees WHERE tenant_id = ?",
                [$id]
            );

            $admins = Database::fetchOne(
                "SELECT COUNT(*) AS total, SUM(is_active = 1) AS active
                 FROM admins WHERE tenant_id = ?",
                [$id]
            );

            $branchCount = (int) (Database::fetchOne(
                "SELECT COUNT(*) AS c FROM branches WHERE tenant_id = ?",
                [$id]
            )['c'] ?? 0);

            $pendingInvites = (int) (Database::fetchOne(
                "SELECT COUNT(*) AS c FROM manager_invitations
                 WHERE tenant_id = ? AND accepted_at IS NULL AND cancelled_at IS NULL AND expires_at > NOW()",
                [$id]
            )['c'] ?? 0);

            $attendanceToday = (int) (Database::fetchOne(
                "SELECT COUNT(*) AS c FROM attendance
                 WHERE tenant_id = ? AND date = ? AND check_in_time IS NOT NULL",
                [$id, $today]
            )['c'] ?? 0);

            $attendanceWeek = (int) (Database::fetchOne(
                "SELECT COUNT(*) AS c FROM attendance
                 WHERE tenant_id = ? AND date >= DATE_SUB(?, INTERVAL 7 DAY) AND check_in_time IS NOT NULL",
                [$id, $today]
            )['c'] ?? 0);

            $lastAttendance = Database::fetchOne(
                "SELECT MAX(date) AS last_date FROM attendance WHERE tenant_id = ? AND check_in_time IS NOT NULL",
                [$id]
            )['last_date'] ?? null;

            $lastAdminLogin = Database::fetchOne(
                "SELECT MAX(last_login_at) AS last_login FROM admins WHERE tenant_id = ?",
                [$id]
            )['last_login'] ?? null;

            // The people we can actually call, the general manager first — this
            // doubles as the contact list when `tenants.contact_*` is still empty.
            $managers = Database::fetchAll(
                "SELECT id, name, phone, email, role, is_active, last_login_at, created_at
                 FROM admins
                 WHERE tenant_id = ? AND role NOT IN ('employee', 'pending')
                 ORDER BY (role = 'general_manager') DESC, last_login_at IS NULL, last_login_at DESC
                 LIMIT 20",
                [$id]
            );

            $methods = json_decode((string) $tenant['attendance_methods'], true);
            if (!is_array($methods) || !$methods) {
                $methods = ['qr_gps'];
            }

            $this->success([
                'tenant' => [
                    'id' => (int) $tenant['id'],
                    'name' => $tenant['name'],
                    'is_active' => (int) $tenant['is_active'],
                    'timezone' => $tenant['timezone'],
                    'timezone_is_explicit' => (int) $tenant['timezone_is_explicit'],
                    'currency' => $tenant['currency'],
                    'country_code' => $tenant['country_code'],
                    'cycle_start_day' => (int) $tenant['cycle_start_day'],
                    'week_start_day' => (int) $tenant['week_start_day'],
                    'created_at' => $tenant['created_at'],
                    'contact_name' => $tenant['contact_name'],
                    'contact_email' => $tenant['contact_email'],
                    'contact_phone' => $tenant['contact_phone'],
                    'ops_notes' => $tenant['ops_notes'],
                    'company_phone' => $tenant['company_phone'],
                    'company_address' => $tenant['company_address'],
                    'commercial_register' => $tenant['commercial_register'],
                ],
                'settings' => [
                    'attendance_methods' => array_values($methods),
                    'allow_offline_attendance' => (int) $tenant['allow_offline_attendance'],
                    'reject_mock_location' => (int) $tenant['reject_mock_location'],
                    'require_local_biometric' => (int) $tenant['require_local_biometric'],
                    'web_attendance_enabled' => (int) $tenant['web_attendance_enabled'],
                    'face_match_threshold' => (float) $tenant['face_match_threshold'],
                    'face_liveness_required' => (int) $tenant['face_liveness_required'],
                    'face_enforce_mode' => $tenant['face_enforce_mode'],
                    'default_annual_leave_days' => (int) $tenant['default_annual_leave_days'],
                ],
                'stats' => [
                    'employees' => (int) ($employees['total'] ?? 0),
                    'employees_active' => (int) ($employees['active'] ?? 0),
                    'employees_pending' => (int) ($employees['pending'] ?? 0),
                    'employees_biometric' => (int) ($employees['enrolled_biometric'] ?? 0),
                    'branches' => $branchCount,
                    'admins' => (int) ($admins['total'] ?? 0),
                    'admins_active' => (int) ($admins['active'] ?? 0),
                    'pending_invitations' => $pendingInvites,
                    'attendance_today' => $attendanceToday,
                    'attendance_last_7_days' => $attendanceWeek,
                ],
                'activity' => [
                    'today' => $today,
                    'last_attendance_date' => $lastAttendance,
                    'last_admin_login_at' => $lastAdminLogin,
                    'last_absence_run' => $tenant['last_absence_date'],
                ],
                'managers' => array_map(static function (array $m): array {
                    return [
                        'id' => (int) $m['id'],
                        'name' => $m['name'],
                        'phone' => $m['phone'],
                        'email' => $m['email'],
                        'role' => $m['role'],
                        'is_active' => (int) $m['is_active'],
                        'last_login_at' => $m['last_login_at'],
                        'created_at' => $m['created_at'],
                    ];
                }, $managers),
            ]);
        }, 'admin.tenants.detail');
    }
}

new TenantDetailApi();
