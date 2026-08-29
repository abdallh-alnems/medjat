<?php

/**
 * Notices when one browser records attendance for more than one employee.
 *
 * This is the realistic abuse of the web channel: an employee hands their PIN to
 * a colleague, who punches for them from their own phone. No non-biometric
 * control can *prevent* that — a willing accomplice defeats possession of a
 * device, knowledge of a PIN, a printed badge, and a geofence equally. What can
 * be done is make the pattern visible, which is what every comparable product
 * relies on.
 *
 * So this flags; it never blocks. A wrongly-flagged pair costs a manager a
 * glance; a wrongly-blocked employee loses a day's pay, and the system has no
 * grounds to be that confident.
 */
final class SharedDeviceDetector {
    /**
     * Other employees who recorded attendance from this browser today.
     *
     * The day boundary is the tenant's, not the server's — a company in a
     * different zone would otherwise have its evening punches compared against
     * the wrong day.
     *
     * @return int[] Employee ids, excluding the one currently punching.
     */
    public static function otherEmployeesOnDevice(
        int $tenantId,
        string $deviceId,
        int $currentEmployeeId,
        string $tenantDate
    ): array {
        if ($deviceId === '') {
            return [];
        }

        $rows = Database::fetchAll(
            "SELECT DISTINCT a.employee_id
             FROM attendance a
             JOIN employee_auth_tokens t
               ON t.employee_id = a.employee_id
              AND t.tenant_id = a.tenant_id
              AND t.platform = 'web'
             WHERE a.tenant_id = ?
               AND a.date = ?
               AND t.device_id = ?
               AND a.employee_id <> ?
               AND (a.check_in_origin = 'web' OR a.check_out_origin = 'web')",
            [$tenantId, $tenantDate, $deviceId, $currentEmployeeId]
        );

        return array_map(static fn($r) => (int) $r['employee_id'], $rows);
    }

    /**
     * Flags every punch involved, then records the observation.
     *
     * Both sides are flagged, not just the employee who arrived second. A flag
     * that marked only the later punch would read as an accusation of one party
     * when the evidence — one device, two employees — says nothing about which
     * of them lent what to whom.
     */
    public static function flag(
        int $tenantId,
        string $tenantDate,
        int $currentEmployeeId,
        array $otherEmployeeIds,
        ?int $branchId
    ): void {
        if ($otherEmployeeIds === []) {
            return;
        }

        $ids = array_merge([$currentEmployeeId], $otherEmployeeIds);
        $placeholders = implode(',', array_fill(0, count($ids), '?'));

        Database::execute(
            "UPDATE attendance
             SET shared_device_flag = 1
             WHERE tenant_id = ? AND date = ? AND employee_id IN ($placeholders)",
            array_merge([$tenantId, $tenantDate], $ids)
        );

        // 'flagged', never 'blocked' — this observation must not read as a
        // refusal in the security log, because nothing was refused.
        foreach ($ids as $employeeId) {
            AttendanceSecurityModel::log(
                $tenantId,
                (int) $employeeId,
                $branchId,
                'web_shared_device',
                'flagged'
            );
        }
    }
}
