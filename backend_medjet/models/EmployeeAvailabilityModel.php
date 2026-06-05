<?php

final class EmployeeAvailabilityModel {
    public const KINDS = ['weekly', 'date'];
    public const LEVELS = ['available', 'preferred', 'unavailable'];

    public static function replaceWeekly(int $tenantId, int $employeeId, array $rows): int {
        Database::execute(
            "DELETE FROM employee_availability WHERE tenant_id = ? AND employee_id = ? AND kind = 'weekly'",
            [$tenantId, $employeeId]
        );
        $count = 0;
        foreach ($rows as $row) {
            $dayOfWeek = intval($row['day_of_week'] ?? -1);
            if ($dayOfWeek < 0 || $dayOfWeek > 6) continue;
            $availability = $row['availability'] ?? 'available';
            if (!in_array($availability, self::LEVELS, true)) continue;
            Database::execute(
                "INSERT INTO employee_availability (tenant_id, employee_id, kind, day_of_week, availability, start_time, end_time, note)
                 VALUES (?, ?, 'weekly', ?, ?, ?, ?, ?)",
                [
                    $tenantId,
                    $employeeId,
                    $dayOfWeek,
                    $availability,
                    $row['start_time'] ?? null,
                    $row['end_time'] ?? null,
                    $row['note'] ?? null,
                ]
            );
            $count++;
        }
        return $count;
    }

    public static function addDateException(int $tenantId, int $employeeId, array $data): int {
        Database::execute(
            "INSERT INTO employee_availability (tenant_id, employee_id, kind, specific_date, availability, start_time, end_time, note)
             VALUES (?, ?, 'date', ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $employeeId,
                $data['specific_date'],
                $data['availability'] ?? 'available',
                $data['start_time'] ?? null,
                $data['end_time'] ?? null,
                $data['note'] ?? null,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function deleteRow(int $id, int $tenantId, int $employeeId): bool {
        return Database::execute(
            "DELETE FROM employee_availability WHERE id = ? AND tenant_id = ? AND employee_id = ?",
            [$id, $tenantId, $employeeId]
        ) > 0;
    }

    public static function listForEmployee(int $tenantId, int $employeeId): array {
        return Database::fetchAll(
            "SELECT * FROM employee_availability
             WHERE tenant_id = ? AND employee_id = ?
             ORDER BY kind ASC, day_of_week ASC, specific_date ASC",
            [$tenantId, $employeeId]
        );
    }

    public static function forRosterWindow(int $tenantId, string $startDate, string $endDate, ?int $branchId = null): array {
        $weekly = Database::fetchAll(
            "SELECT ea.*, e.name AS employee_name, e.branch_id
             FROM employee_availability ea
             JOIN employees e ON e.id = ea.employee_id
             WHERE ea.tenant_id = ? AND ea.kind = 'weekly'
               AND e.status NOT IN ('terminated', 'pending_activation')",
            [$tenantId]
        );

        $dateParams = [$tenantId, $startDate, $endDate];
        $branchFilter = '';
        if ($branchId !== null) {
            $branchFilter = ' AND e.branch_id = ?';
            $dateParams[] = $branchId;
        }
        $dateExc = Database::fetchAll(
            "SELECT ea.*, e.name AS employee_name, e.branch_id
             FROM employee_availability ea
             JOIN employees e ON e.id = ea.employee_id
             WHERE ea.tenant_id = ? AND ea.kind = 'date'
               AND ea.specific_date BETWEEN ? AND ?
               AND e.status NOT IN ('terminated', 'pending_activation')
               {$branchFilter}",
            $dateParams
        );

        if ($branchId !== null) {
            $weekly = array_filter($weekly, fn($r) => (int) $r['branch_id'] === $branchId);
            $weekly = array_values($weekly);
        }

        return ['weekly' => $weekly, 'date_exceptions' => $dateExc];
    }

    public static function checkConflict(int $tenantId, int $employeeId, string $date): ?array {
        $dow = (int) date('w', strtotime($date));
        $dateRow = Database::fetchOne(
            "SELECT * FROM employee_availability
             WHERE tenant_id = ? AND employee_id = ? AND kind = 'date' AND specific_date = ? AND availability = 'unavailable'",
            [$tenantId, $employeeId, $date]
        );
        if ($dateRow) return $dateRow;

        return Database::fetchOne(
            "SELECT * FROM employee_availability
             WHERE tenant_id = ? AND employee_id = ? AND kind = 'weekly' AND day_of_week = ? AND availability = 'unavailable'",
            [$tenantId, $employeeId, $dow]
        );
    }
}
