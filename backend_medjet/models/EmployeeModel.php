<?php

final class EmployeeModel {
    /** Compliance / legal credential columns, used for create, update and expiry alerts. */
    public const COMPLIANCE_FIELDS = [
        'nationality',
        'iqama_number',
        'iqama_expiry',
        'passport_number',
        'passport_expiry',
        'work_permit_number',
        'work_permit_expiry',
        'contract_type',
        'contract_start',
        'contract_end',
        'health_insurance_expiry',
    ];

    /** Valid recurring weekly off days; matches the `weekly_off_days` SET column. */
    public const WEEKLY_OFF_DAYS = [
        'saturday', 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday',
    ];

    /**
     * Normalize a caller-supplied weekly-off value (array or comma string) into a
     * comma-joined string of valid, de-duplicated days for the SET column.
     * Returns null when nothing valid is supplied (clears the value).
     */
    public static function normalizeWeeklyOffDays(mixed $value): ?string {
        if (is_string($value)) {
            $value = $value === '' ? [] : explode(',', $value);
        }
        if (!is_array($value)) {
            return null;
        }
        $days = array_values(array_unique(array_intersect(
            self::WEEKLY_OFF_DAYS,
            array_map(static fn($d) => is_string($d) ? trim($d) : $d, $value)
        )));
        return $days ? implode(',', $days) : null;
    }

    /** Credential => [number column (or null), expiry column]; drives expiry alerts. */
    public const COMPLIANCE_CREDENTIALS = [
        'iqama'            => ['iqama_number', 'iqama_expiry'],
        'passport'         => ['passport_number', 'passport_expiry'],
        'work_permit'      => ['work_permit_number', 'work_permit_expiry'],
        'contract'         => [null, 'contract_end'],
        'health_insurance' => [null, 'health_insurance_expiry'],
    ];

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT e.*, s.start_time AS shift_start, s.end_time AS shift_end,
                    s.name AS shift_name, b.name AS branch_name
             FROM employees e
             LEFT JOIN shifts s ON s.id = e.shift_id
             LEFT JOIN branches b ON b.id = e.branch_id
             WHERE e.id = ? AND e.tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function findByAdminId(int $adminId, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM employees WHERE admin_id = ? AND tenant_id = ? LIMIT 1",
            [$adminId, $tenantId]
        );
    }

    /**
     * Active (non-terminated) employees matching a bulk-adjustment scope.
     * Returns id + admin_id + base_salary so callers can fan out payroll
     * lines (fixed manual bonus/deduction, or a percentage of base_salary)
     * and notify each linked employee account.
     *
     * $scopeType: 'branch' | 'shift' | 'category'. Unknown types yield [].
     */
    public static function listForScope(string $scopeType, int $scopeId, int $tenantId): array {
        switch ($scopeType) {
            case 'branch':
                $sql = "SELECT id, admin_id, base_salary FROM employees
                        WHERE tenant_id = ? AND branch_id = ? AND status != 'terminated'";
                break;
            case 'shift':
                $sql = "SELECT id, admin_id, base_salary FROM employees
                        WHERE tenant_id = ? AND shift_id = ? AND status != 'terminated'";
                break;
            case 'category':
                $sql = "SELECT e.id, e.admin_id, e.base_salary FROM employees e
                        JOIN employee_category_assignments eca
                          ON eca.employee_id = e.id AND eca.tenant_id = e.tenant_id
                        WHERE e.tenant_id = ? AND eca.category_id = ?
                          AND e.status != 'terminated'";
                break;
            default:
                return [];
        }
        return Database::fetchAll($sql, [$tenantId, $scopeId]);
    }

    public static function create(int $tenantId, array $data): int {
        $columns = [
            'tenant_id', 'branch_id', 'admin_id', 'name', 'phone', 'job_title',
            'base_salary', 'hire_date', 'work_start_time', 'work_end_time',
            'annual_leave_days', 'shift_id', 'national_id', 'status',
            'bank_name', 'bank_account_number', 'bank_iban', 'bank_swift',
        ];
        $values = [
            $tenantId,
            $data['branch_id'],
            $data['admin_id'] ?? null,
            $data['name'],
            $data['phone'] ?? null,
            $data['job_title'] ?? null,
            $data['base_salary'] ?? 0,
            $data['hire_date'] ?? date('Y-m-d'),
            $data['work_start_time'] ?? '09:00:00',
            $data['work_end_time'] ?? '17:00:00',
            $data['annual_leave_days'] ?? null,
            $data['shift_id'] ?? null,
            $data['national_id'] ?? null,
            $data['status'] ?? 'active',
            $data['bank_name'] ?? null,
            $data['bank_account_number'] ?? null,
            $data['bank_iban'] ?? null,
            $data['bank_swift'] ?? null,
        ];

        if (array_key_exists('weekly_off_days', $data)) {
            $columns[] = 'weekly_off_days';
            $values[] = self::normalizeWeeklyOffDays($data['weekly_off_days']);
        }

        if (array_key_exists('auto_terminate_at', $data)) {
            $columns[] = 'auto_terminate_at';
            $values[] = $data['auto_terminate_at'] !== '' ? $data['auto_terminate_at'] : null;
        }

        // Optional compliance / legal credential fields.
        foreach (self::COMPLIANCE_FIELDS as $field) {
            if (array_key_exists($field, $data)) {
                $columns[] = $field;
                $values[] = $data[$field] !== '' ? $data[$field] : null;
            }
        }

        $placeholders = implode(', ', array_fill(0, count($columns), '?'));
        Database::execute(
            'INSERT INTO employees (' . implode(', ', $columns) . ") VALUES ($placeholders)",
            $values
        );
        return (int) Database::lastInsertId();
    }

    /**
     * Employees with a compliance credential expiring within $daysAhead days
     * (or already expired when $includeExpired is true). One row per credential.
     */
    public static function getExpiringCompliance(int $tenantId, int $daysAhead = 30, ?int $branchId = null, bool $includeExpired = true): array {
        $employees = self::expiringComplianceRows($tenantId, $daysAhead, $branchId, $includeExpired);

        $today = new DateTime('today');
        $results = [];
        foreach ($employees as $e) {
            foreach (self::COMPLIANCE_CREDENTIALS as $credential => [$numberCol, $expiryCol]) {
                $expiry = $e[$expiryCol] ?? null;
                if (!$expiry) {
                    continue;
                }
                $expiryDate = DateTime::createFromFormat('Y-m-d', $expiry);
                if (!$expiryDate) {
                    continue;
                }
                $daysLeft = (int) $today->diff($expiryDate)->format('%r%a');
                if ($daysLeft > $daysAhead) {
                    continue;
                }
                if ($daysLeft < 0 && !$includeExpired) {
                    continue;
                }
                $results[] = [
                    'employee_id'   => (int) $e['id'],
                    'employee_name' => $e['name'],
                    'branch_id'     => $e['branch_id'] !== null ? (int) $e['branch_id'] : null,
                    'branch_name'   => $e['branch_name'] ?? null,
                    'credential'    => $credential,
                    'number'        => $numberCol ? ($e[$numberCol] ?? null) : null,
                    'expires_at'    => $expiry,
                    'days_left'     => $daysLeft,
                    'is_expired'    => $daysLeft < 0,
                ];
            }
        }

        usort($results, static fn($a, $b) => $a['days_left'] <=> $b['days_left']);
        return $results;
    }

    private static function expiringComplianceRows(int $tenantId, int $daysAhead, ?int $branchId, bool $includeExpired): array {
        $expiryCols = array_column(self::COMPLIANCE_CREDENTIALS, 1);
        $lower = $includeExpired ? null : 'CURDATE()';
        $upper = 'DATE_ADD(CURDATE(), INTERVAL ? DAY)';

        $conditions = [];
        $params = [$tenantId];
        foreach ($expiryCols as $col) {
            if ($lower === null) {
                $conditions[] = "(e.`$col` IS NOT NULL AND e.`$col` <= $upper)";
            } else {
                $conditions[] = "(e.`$col` IS NOT NULL AND e.`$col` BETWEEN $lower AND $upper)";
            }
            $params[] = $daysAhead;
        }

        $sql = "SELECT e.*, b.name AS branch_name
                FROM employees e
                LEFT JOIN branches b ON b.id = e.branch_id
                WHERE e.tenant_id = ? AND e.status != 'terminated'
                  AND (" . implode(' OR ', $conditions) . ')';
        if ($branchId) {
            $sql .= ' AND e.branch_id = ?';
            $params[] = $branchId;
        }
        return Database::fetchAll($sql, $params);
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $fields = [];
        $values = [];
        foreach ($data as $key => $value) {
            $fields[] = "{$key} = ?";
            $values[] = $value;
        }
        $values[] = $id;
        $values[] = $tenantId;
        Database::execute(
            "UPDATE employees SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function delete(int $id, int $tenantId): bool {
        return Database::execute(
            "UPDATE employees SET status = 'terminated', terminated_at = CURDATE(), deleted_at = NOW() WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    /**
     * End an employee's service with an explicit termination date (the last
     * working day). Same effect as delete() but the termination date is the
     * settlement's last working day rather than today. Used when approving an
     * end-of-service settlement.
     */
    public static function terminate(int $id, int $tenantId, string $terminationDate): bool {
        return Database::execute(
            "UPDATE employees SET status = 'terminated', terminated_at = ?, deleted_at = NOW()
             WHERE id = ? AND tenant_id = ?",
            [$terminationDate, $id, $tenantId]
        ) > 0;
    }

    /**
     * Fixed-term employees whose end date has passed and who are still active.
     * Used by the daily cron to auto-terminate them.
     */
    public static function dueForAutoTermination(int $tenantId, string $today): array {
        return Database::fetchAll(
            "SELECT id, name, branch_id, auto_terminate_at
             FROM employees
             WHERE tenant_id = ?
               AND auto_terminate_at IS NOT NULL
               AND auto_terminate_at < ?
               AND status NOT IN ('terminated')
               AND deleted_at IS NULL",
            [$tenantId, $today]
        );
    }

    /**
     * Fixed-term employees ending within the next $daysAhead days (today inclusive),
     * still active. Used by the cron to warn admins before the end date.
     */
    public static function upcomingAutoTermination(int $tenantId, string $today, int $daysAhead): array {
        return Database::fetchAll(
            "SELECT id, name, branch_id, auto_terminate_at,
                    DATEDIFF(auto_terminate_at, ?) AS days_left
             FROM employees
             WHERE tenant_id = ?
               AND auto_terminate_at IS NOT NULL
               AND auto_terminate_at >= ?
               AND auto_terminate_at <= DATE_ADD(?, INTERVAL ? DAY)
               AND status NOT IN ('terminated')
               AND deleted_at IS NULL",
            [$today, $tenantId, $today, $today, $daysAhead]
        );
    }

    /** Flip an employee to 'terminated' because their fixed term ended. */
    public static function autoTerminate(int $id, int $tenantId): void {
        Database::execute(
            "UPDATE employees SET status = 'terminated', terminated_at = CURDATE(), updated_at = NOW()
             WHERE id = ? AND tenant_id = ? AND status NOT IN ('terminated')",
            [$id, $tenantId]
        );
    }

    /** Employment statuses that can be filtered on (terminated is hidden by default). */
    public const FILTERABLE_STATUSES = ['active', 'suspended', 'on_leave', 'pending_activation'];

    /** Whitelisted sort keys → safe ORDER BY column. Direction is applied separately. */
    private const SORT_COLUMNS = [
        'name' => 'e.name',
        'hire_date' => 'e.hire_date',
    ];

    public static function getByTenant(
        int $tenantId,
        int $page = 1,
        int $limit = 20,
        ?int $branchId = null,
        ?string $search = null,
        ?string $status = null,
        string $sort = 'name',
        ?int $shiftId = null,
        ?int $categoryId = null,
        ?int $expiringWithin = null,
        string $dir = 'asc'
    ): array {
        $sql = "SELECT e.*, s.start_time AS shift_start, s.end_time AS shift_end,
                       s.name AS shift_name
                FROM employees e
                LEFT JOIN shifts s ON s.id = e.shift_id
                WHERE e.tenant_id = ? AND e.status != 'terminated'";
        $params = [$tenantId];

        if ($branchId) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }

        if ($shiftId) {
            $sql .= " AND e.shift_id = ?";
            $params[] = $shiftId;
        }

        // Many-to-many: keep only employees assigned to the given category.
        if ($categoryId) {
            $sql .= " AND EXISTS (SELECT 1 FROM employee_category_assignments eca
                                  WHERE eca.employee_id = e.id
                                    AND eca.category_id = ?
                                    AND eca.tenant_id = e.tenant_id)";
            $params[] = $categoryId;
        }

        // Filter by a specific employment status (terminated is never listed).
        if ($status !== null && $status !== '' && in_array($status, self::FILTERABLE_STATUSES, true)) {
            $sql .= " AND e.status = ?";
            $params[] = $status;
        }

        // "Expiring documents" filter: any of iqama / passport / work permit
        // expiring within the given number of days (already-expired included).
        if ($expiringWithin !== null && $expiringWithin > 0) {
            $sql .= " AND (
                (e.iqama_expiry IS NOT NULL AND e.iqama_expiry <= DATE_ADD(CURDATE(), INTERVAL ? DAY))
                OR (e.passport_expiry IS NOT NULL AND e.passport_expiry <= DATE_ADD(CURDATE(), INTERVAL ? DAY))
                OR (e.work_permit_expiry IS NOT NULL AND e.work_permit_expiry <= DATE_ADD(CURDATE(), INTERVAL ? DAY))
            )";
            $params[] = $expiringWithin;
            $params[] = $expiringWithin;
            $params[] = $expiringWithin;
        }

        if ($search) {
            $sql .= " AND (name LIKE ? OR phone LIKE ? OR national_id LIKE ? OR job_title LIKE ?)";
            $searchParam = "%{$search}%";
            $params[] = $searchParam;
            $params[] = $searchParam;
            $params[] = $searchParam;
            $params[] = $searchParam;
        }

        $sortCol = self::SORT_COLUMNS[$sort] ?? self::SORT_COLUMNS['name'];
        $direction = strtolower($dir) === 'desc' ? 'DESC' : 'ASC';
        $orderBy = "{$sortCol} {$direction}";
        // Stable tiebreaker so equal hire dates keep a deterministic order.
        if ($sort === 'hire_date') {
            $orderBy .= ", e.name ASC";
        }
        $offset = ($page - 1) * $limit;
        $sql .= " ORDER BY {$orderBy} LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;

        $items = Database::fetchAll($sql, $params);
        return ['items' => $items, 'page' => $page];
    }

    /**
     * Headcount grouped by employment status (terminated excluded), honouring
     * an optional branch scope. Powers the employees list stats header.
     * Always returns the full set of keys so the UI can render fixed chips.
     */
    public static function statusCounts(int $tenantId, ?int $branchId = null): array {
        $sql = "SELECT status, COUNT(*) AS c FROM employees
                WHERE tenant_id = ? AND status != 'terminated'";
        $params = [$tenantId];
        if ($branchId) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }
        $sql .= " GROUP BY status";

        $counts = [
            'total' => 0,
            'active' => 0,
            'on_leave' => 0,
            'pending_activation' => 0,
            'suspended' => 0,
        ];
        foreach (Database::fetchAll($sql, $params) as $row) {
            $key = $row['status'];
            $c = (int) $row['c'];
            if (array_key_exists($key, $counts)) {
                $counts[$key] = $c;
            }
            $counts['total'] += $c;
        }
        return $counts;
    }

    public static function countByTenant(int $tenantId, ?int $branchId = null): int {
        $sql = "SELECT COUNT(*) as count FROM employees WHERE tenant_id = ? AND status != 'terminated'";
        $params = [$tenantId];
        if ($branchId) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }
        return (int) (Database::fetchOne($sql, $params)['count'] ?? 0);
    }

    public static function getReport(int $tenantId, ?int $branchId = null): array {
        $sql = "SELECT
                    e.id as employee_id,
                    e.name as employee_name,
                    e.job_title,
                    e.phone,
                    e.base_salary,
                    e.hire_date,
                    e.status,
                    b.name as branch_name,
                    s.name as shift_name,
                    COALESCE(SUM(CASE WHEN a.status = 'present' AND a.late_minutes = 0 THEN 1 END), 0) as days_present,
                    COALESCE(SUM(CASE WHEN a.status = 'present' AND a.late_minutes > 0 THEN 1 END), 0) as days_late,
                    COALESCE(SUM(CASE WHEN a.status = 'absent' THEN 1 END), 0) as days_absent,
                    COALESCE(SUM(CASE WHEN a.status = 'leave' THEN 1 END), 0) as days_leave,
                    COALESCE(SUM(a.worked_minutes), 0) as total_minutes_worked,
                    DATE_FORMAT(NOW(), '%Y-%m') as current_month
                FROM employees e
                LEFT JOIN branches b ON b.id = e.branch_id
                LEFT JOIN shifts s ON s.id = e.shift_id
                LEFT JOIN attendance a ON a.employee_id = e.id
                    AND DATE_FORMAT(a.date, '%Y-%m') = DATE_FORMAT(NOW(), '%Y-%m')
                WHERE e.tenant_id = ? AND e.status != 'terminated'";
        $params = [$tenantId];
        if ($branchId !== null) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        $sql .= " GROUP BY e.id ORDER BY e.name ASC";
        return Database::fetchAll($sql, $params);
    }

    public static function getReportSummary(int $tenantId, ?int $branchId = null): array {
        $sql = "SELECT
                    COUNT(*) as total_employees,
                    COUNT(CASE WHEN status = 'active' THEN 1 END) as active_count,
                    COUNT(CASE WHEN status = 'on_leave' THEN 1 END) as on_leave_count,
                    COUNT(CASE WHEN status = 'pending_activation' THEN 1 END) as pending_count,
                    COUNT(CASE WHEN status = 'suspended' THEN 1 END) as suspended_count,
                    COALESCE(SUM(base_salary), 0) as total_salaries,
                    COUNT(DISTINCT branch_id) as branch_count
                FROM employees
                WHERE tenant_id = ? AND status != 'terminated'";
        $params = [$tenantId];
        if ($branchId !== null) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }
        return Database::fetchOne($sql, $params) ?: [
            'total_employees' => 0,
            'active_count' => 0,
            'on_leave_count' => 0,
            'pending_count' => 0,
            'suspended_count' => 0,
            'total_salaries' => 0,
            'branch_count' => 0,
        ];
    }
}
