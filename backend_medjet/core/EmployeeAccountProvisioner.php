<?php

/**
 * Makes sure an activating employee has the `admins` row their permissions hang
 * off, and marks them active.
 *
 * This mirrors, deliberately and not by accident, the block inside
 * `app/auth/employee_login.php`. That file is the login path for every employee
 * currently in the field with a store-published build, and it cannot be
 * exercised locally right now, so it was left untouched rather than refactored
 * to call this. The duplication is a considered trade, not an oversight:
 *
 *   - changing it blind risks breaking sign-in for everyone,
 *   - the logic is small, self-contained and has been stable,
 *   - and the next person to touch either path should collapse them, with the
 *     app login exercised against MAMP first.
 *
 * If you are that person: the two blocks must stay identical in behaviour, or
 * an employee's account will differ depending on whether they first activated
 * on a phone or in a browser.
 */
final class EmployeeAccountProvisioner {
    /**
     * @param array $employee Row from `employees` (must include id, tenant_id, phone, name, branch_id, admin_id)
     * @return int The employee's admin id.
     */
    public static function activate(array $employee): int {
        $employeeId = (int) $employee['id'];
        $tenantId = (int) $employee['tenant_id'];

        Database::execute(
            "UPDATE employees
             SET status = 'active', has_linked_account = 1, updated_at = NOW()
             WHERE id = ?",
            [$employeeId]
        );

        $adminId = $employee['admin_id'] ? (int) $employee['admin_id'] : null;
        if ($adminId) {
            return $adminId;
        }

        $existing = Database::fetchOne(
            "SELECT id FROM admins WHERE tenant_id = ? AND phone = ? AND role = 'employee' LIMIT 1",
            [$tenantId, $employee['phone']]
        );

        if ($existing) {
            $adminId = (int) $existing['id'];
        } else {
            $adminId = AdminModel::create([
                'firebase_uid' => 'employee:' . $employeeId,
                'tenant_id'    => $tenantId,
                'branch_id'    => $employee['branch_id'] ? (int) $employee['branch_id'] : null,
                'name'         => $employee['name'],
                'phone'        => $employee['phone'],
                'role'         => 'employee',
            ]);
        }

        Database::execute('UPDATE employees SET admin_id = ? WHERE id = ?', [$adminId, $employeeId]);

        return $adminId;
    }

    /**
     * Sanity-check that the typed phone belongs to the employee the code points at.
     *
     * The activation code is already the secret; this only stops an obvious
     * mistype from binding the wrong person. Compared on digits, tolerating the
     * local-zero ↔ country-code difference, so a correct code is never rejected
     * over formatting — matching the existing app login exactly.
     */
    public static function phoneMatches(string $typed, ?string $stored): bool {
        $inDigits = preg_replace('/\D/', '', $typed);
        $dbDigits = preg_replace('/\D/', '', (string) $stored);
        if ($inDigits === $dbDigits) {
            return true;
        }

        $inCore = ltrim($inDigits, '0');
        $dbCore = ltrim($dbDigits, '0');

        return $inCore !== '' && $dbCore !== ''
            && (str_ends_with($dbCore, $inCore) || str_ends_with($inCore, $dbCore));
    }

    /** Finds an employee by phone, tolerating the same formatting differences. */
    public static function findByPhone(string $phone): ?array {
        $digits = preg_replace('/\D/', '', $phone);
        $core = ltrim($digits, '0');
        if ($core === '') {
            return null;
        }

        // Matching on the trailing significant digits rather than on equality:
        // the database holds E.164 while an employee types whatever they know.
        return Database::fetchOne(
            "SELECT e.*, b.name AS branch_name, t.name AS tenant_name
             FROM employees e
             LEFT JOIN branches b ON b.id = e.branch_id
             LEFT JOIN tenants  t ON t.id = e.tenant_id
             WHERE REPLACE(REPLACE(REPLACE(e.phone, '+', ''), ' ', ''), '-', '') LIKE CONCAT('%', ?)
             ORDER BY e.id
             LIMIT 1",
            [$core]
        );
    }
}
