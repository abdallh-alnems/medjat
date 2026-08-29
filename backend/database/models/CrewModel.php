<?php

/**
 * Crews: the people one supervisor may record attendance for on site.
 *
 * A crew is not a stored entity. It is derived from
 * `employees.crew_supervisor_id`, so "my crew" and "may I record for this
 * person" are the same query asked two ways, and a membership list can never
 * disagree with the permission that guards it.
 *
 * WHY THIS FILE EXISTS AT ALL, given how small the queries are: this is the
 * only place in the codebase where an employee credential does something for
 * somebody other than its owner. Thirty-three endpoints authenticate an
 * employee and every other one of them acts strictly on that employee's own
 * rows. When that invariant gets an exception it should be one function, named,
 * with the reasoning next to it — not a WHERE clause inlined into an endpoint
 * where the next reader has to notice it.
 */
final class CrewModel {
    /**
     * Everyone this supervisor may record for today.
     *
     * Tenant-scoped on both sides. Terminated employees are excluded: the app
     * would otherwise keep offering a name that every write then refuses.
     *
     * @return array<int, array<string, mixed>>
     */
    public static function membersFor(int $supervisorId, int $tenantId): array {
        if ($supervisorId <= 0) {
            return [];
        }

        return Database::fetchAll(
            "SELECT e.id, e.name, e.job_title, e.branch_id, e.profile_image,
                    a.check_in_time, a.check_out_time, a.status AS attendance_status
             FROM employees e
             LEFT JOIN attendance a
               ON a.employee_id = e.id AND a.tenant_id = e.tenant_id AND a.date = ?
             WHERE e.crew_supervisor_id = ?
               AND e.tenant_id = ?
               AND (e.status IS NULL OR e.status <> 'terminated')
             ORDER BY e.name",
            [TenantClock::date($tenantId), $supervisorId, $tenantId]
        );
    }

    /**
     * The authorisation check, asked about a whole batch at once.
     *
     * Returns the ids that are NOT in this supervisor's crew. An empty array
     * means the batch is authorised.
     *
     * Deliberately answers for the batch rather than per id: a supervisor sends
     * thirty ids, and thirty round trips to reject one of them is both slower
     * and easier to get wrong by forgetting to check one.
     *
     * @param int[] $employeeIds
     * @return int[] The unauthorised subset.
     */
    public static function rejectOutsiders(int $supervisorId, int $tenantId, array $employeeIds): array {
        $ids = array_values(array_unique(array_filter(
            array_map('intval', $employeeIds),
            static fn(int $id): bool => $id > 0
        )));

        if ($ids === [] || $supervisorId <= 0) {
            return $ids;
        }

        $placeholders = implode(',', array_fill(0, count($ids), '?'));

        $rows = Database::fetchAll(
            "SELECT id FROM employees
             WHERE id IN ($placeholders)
               AND tenant_id = ?
               AND crew_supervisor_id = ?
               AND (status IS NULL OR status <> 'terminated')",
            array_merge($ids, [$tenantId, $supervisorId])
        );

        $allowed = array_map(static fn(array $r): int => (int) $r['id'], $rows);

        return array_values(array_diff($ids, $allowed));
    }

    /** True when anybody at all reports to this employee. */
    public static function isSupervisor(int $employeeId, int $tenantId): bool {
        if ($employeeId <= 0) {
            return false;
        }
        $row = Database::fetchOne(
            "SELECT 1 AS yes FROM employees
             WHERE crew_supervisor_id = ? AND tenant_id = ?
               AND (status IS NULL OR status <> 'terminated')
             LIMIT 1",
            [$employeeId, $tenantId]
        );
        return $row !== null;
    }

    /**
     * Would making $supervisorId the supervisor of $employeeId create a loop?
     *
     * The database stops the one-step case (a CHECK that you are not your own
     * supervisor). It cannot see other rows, so A→B→A and longer rings have to
     * be caught here. A ring would make membersFor and rejectOutsiders disagree
     * about who is above whom, and — worse — let two people record for each
     * other indefinitely with nobody above either of them.
     *
     * Walks upward from the proposed supervisor. The hop limit is a guard
     * against a ring that already exists in the data rather than a depth
     * assumption: without it, bad data turns this into an infinite loop.
     */
    public static function wouldCycle(int $supervisorId, int $employeeId, int $tenantId): bool {
        if ($supervisorId <= 0 || $employeeId <= 0) {
            return false;
        }
        if ($supervisorId === $employeeId) {
            return true;
        }

        $cursor = $supervisorId;
        for ($hop = 0; $hop < 32; $hop++) {
            $row = Database::fetchOne(
                "SELECT crew_supervisor_id FROM employees WHERE id = ? AND tenant_id = ? LIMIT 1",
                [$cursor, $tenantId]
            );
            $next = $row['crew_supervisor_id'] ?? null;
            if ($next === null) {
                return false;
            }
            if ((int) $next === $employeeId) {
                return true;
            }
            $cursor = (int) $next;
        }

        // Ran out of hops: the existing chain is already a ring, so refuse.
        return true;
    }

    /** Does this company require a group photograph on every crew batch? */
    public static function photoRequired(int $tenantId): bool {
        $tenant = TenantModel::findById($tenantId);
        return (int) ($tenant['crew_photo_required'] ?? 0) === 1;
    }
}
