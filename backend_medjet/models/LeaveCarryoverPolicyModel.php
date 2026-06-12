<?php

/**
 * Multi-level annual-leave carryover policy.
 *
 * Policies are stored at four scopes — tenant, branch, category, employee — and
 * may be split into seniority tiers (min_seniority_months). The resolver picks
 * the most specific scope that applies to an employee, and within that scope the
 * highest seniority tier the employee qualifies for. When no policy row exists
 * the resolver falls back to the legacy `tenants.leave_carryover_max_days`.
 *
 * @see LeaveModel::rolloverYear() and LeaveModel::getBalance() which consume resolve()
 * @see app/leaves/carryover_policy_save.php
 */
final class LeaveCarryoverPolicyModel {

    /** Scope precedence, most specific first. */
    private const SCOPE_ORDER = ['employee' => 4, 'category' => 3, 'branch' => 2, 'tenant' => 1];

    /**
     * The effective carryover policy for one employee.
     *
     * @return array{
     *   carryover_enabled:bool, carryover_max_days:?int, expiry_months:?int,
     *   encash_excess:bool, legal_min_carry_days:?int, source:string
     * }
     */
    public static function resolve(int $employeeId, int $tenantId): array {
        $emp = Database::fetchOne(
            "SELECT branch_id, hire_date FROM employees WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $tenantId]
        );
        $branchId = $emp && $emp['branch_id'] !== null ? (int) $emp['branch_id'] : null;
        $tenureMonths = self::tenureMonths($emp['hire_date'] ?? null);

        $categoryIds = array_map(
            static fn($r) => (int) $r['category_id'],
            Database::fetchAll(
                "SELECT category_id FROM employee_category_assignments WHERE employee_id = ? AND tenant_id = ?",
                [$employeeId, $tenantId]
            )
        );

        $rows = Database::fetchAll(
            "SELECT scope_type, scope_id, min_seniority_months, carryover_enabled, carryover_max_days,
                    expiry_months, encash_excess, legal_min_carry_days
               FROM leave_carryover_policies
              WHERE tenant_id = ? AND min_seniority_months <= ?",
            [$tenantId, $tenureMonths]
        );

        $best = null;
        $bestRank = -1;
        $bestSeniority = -1;
        foreach ($rows as $r) {
            $scope = $r['scope_type'];
            $scopeId = $r['scope_id'] !== null ? (int) $r['scope_id'] : null;

            // Does this row apply to this employee?
            $applies = match ($scope) {
                'tenant' => true,
                'branch' => $branchId !== null && $scopeId === $branchId,
                'category' => $scopeId !== null && in_array($scopeId, $categoryIds, true),
                'employee' => $scopeId === $employeeId,
                default => false,
            };
            if (!$applies) {
                continue;
            }

            $rank = self::SCOPE_ORDER[$scope] ?? 0;
            $seniority = (int) $r['min_seniority_months'];
            // More specific scope wins; tie-break on the higher seniority tier.
            if ($rank > $bestRank || ($rank === $bestRank && $seniority > $bestSeniority)) {
                $best = $r;
                $bestRank = $rank;
                $bestSeniority = $seniority;
            }
        }

        if ($best !== null) {
            return [
                'carryover_enabled' => (int) $best['carryover_enabled'] === 1,
                'carryover_max_days' => $best['carryover_max_days'] !== null ? (int) $best['carryover_max_days'] : null,
                'expiry_months' => $best['expiry_months'] !== null ? (int) $best['expiry_months'] : null,
                'encash_excess' => (int) $best['encash_excess'] === 1,
                'legal_min_carry_days' => $best['legal_min_carry_days'] !== null ? (int) $best['legal_min_carry_days'] : null,
                'source' => $best['scope_type'],
            ];
        }

        // Legacy fallback: the old single tenant column.
        $tenant = Database::fetchOne(
            "SELECT leave_carryover_max_days FROM tenants WHERE id = ? LIMIT 1",
            [$tenantId]
        );
        $legacyMax = $tenant && $tenant['leave_carryover_max_days'] !== null
            ? (int) $tenant['leave_carryover_max_days']
            : null;

        return [
            'carryover_enabled' => $legacyMax !== null,
            'carryover_max_days' => $legacyMax,
            'expiry_months' => null,
            'encash_excess' => false,
            'legal_min_carry_days' => null,
            'source' => $legacyMax !== null ? 'legacy' : 'default',
        ];
    }

    /** Whole months between $hireDate and today; 0 when unknown or in the future. */
    public static function tenureMonths(?string $hireDate): int {
        if (!$hireDate) {
            return 0;
        }
        try {
            $hire = new DateTime($hireDate);
        } catch (Exception $e) {
            return 0;
        }
        $now = new DateTime('today');
        if ($hire > $now) {
            return 0;
        }
        $diff = $hire->diff($now);
        return $diff->y * 12 + $diff->m;
    }

    /** All policy rows for a tenant (for the management UI). */
    public static function listForTenant(int $tenantId): array {
        return Database::fetchAll(
            "SELECT id, scope_type, scope_id, min_seniority_months, carryover_enabled, carryover_max_days,
                    expiry_months, encash_excess, legal_min_carry_days, created_at, updated_at
               FROM leave_carryover_policies
              WHERE tenant_id = ?
              ORDER BY FIELD(scope_type,'tenant','branch','category','employee'), scope_id, min_seniority_months",
            [$tenantId]
        );
    }

    /** Insert or update one policy row (keyed by scope + seniority tier). */
    public static function upsert(int $tenantId, array $data): void {
        Database::execute(
            "INSERT INTO leave_carryover_policies
                (tenant_id, scope_type, scope_id, min_seniority_months, carryover_enabled,
                 carryover_max_days, expiry_months, encash_excess, legal_min_carry_days)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                carryover_enabled = VALUES(carryover_enabled),
                carryover_max_days = VALUES(carryover_max_days),
                expiry_months = VALUES(expiry_months),
                encash_excess = VALUES(encash_excess),
                legal_min_carry_days = VALUES(legal_min_carry_days)",
            [
                $tenantId,
                $data['scope_type'],
                $data['scope_id'],
                $data['min_seniority_months'] ?? 0,
                !empty($data['carryover_enabled']) ? 1 : 0,
                $data['carryover_max_days'],
                $data['expiry_months'],
                !empty($data['encash_excess']) ? 1 : 0,
                $data['legal_min_carry_days'],
            ]
        );
    }

    /** Remove an override row (restores inheritance from the parent scope). */
    public static function delete(int $tenantId, int $id): void {
        Database::execute(
            "DELETE FROM leave_carryover_policies WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    /** Convenience accessor for the tenant-level (scope=tenant, tier 0) row. */
    public static function getTenantPolicy(int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT carryover_enabled, carryover_max_days, expiry_months, encash_excess, legal_min_carry_days
               FROM leave_carryover_policies
              WHERE tenant_id = ? AND scope_type = 'tenant' AND scope_id IS NULL AND min_seniority_months = 0
              LIMIT 1",
            [$tenantId]
        );
    }
}
