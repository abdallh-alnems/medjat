<?php

declare(strict_types=1);

namespace App\Domain\Leave;

use App\Support\Value;
use DateTimeImmutable;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * What happens to annual leave somebody did not take.
 *
 * Companies answer this at four levels — the company, a branch, a job
 * category, one person — and often differently for long-serving staff. So a
 * policy is picked rather than looked up: the most specific scope that applies,
 * and within it the highest seniority tier the employee has actually reached.
 */
final readonly class CarryoverPolicy
{
    /** Most specific first; a personal policy beats one set for the branch. */
    private const SCOPE_RANK = ['employee' => 4, 'category' => 3, 'branch' => 2, 'tenant' => 1];

    public function __construct(
        public bool $enabled,
        public ?int $maxDays,
        public ?int $expiryMonths,
        public bool $encashExcess,
        public ?int $legalMinCarryDays,
        public string $source,
    ) {}

    public static function resolve(int $employeeId, int $tenantId): self
    {
        $employee = DB::table('employees')
            ->where('id', $employeeId)->where('tenant_id', $tenantId)
            ->first(['branch_id', 'hire_date']);

        $branchId = $employee === null ? null : Value::nullableInt($employee->branch_id);
        $tenure = self::tenureMonths($employee === null ? null : Value::nullableString($employee->hire_date));

        $categoryIds = DB::table('employee_category_assignments')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->pluck('category_id')
            ->map(static fn (mixed $id): int => Value::int($id))
            ->all();

        // Tiers above the employee's tenure are excluded in SQL: a policy that
        // starts at five years must not apply to somebody with two.
        $rows = DB::table('leave_carryover_policies')
            ->where('tenant_id', $tenantId)
            ->where('min_seniority_months', '<=', $tenure)
            ->get([
                'scope_type', 'scope_id', 'min_seniority_months', 'carryover_enabled',
                'carryover_max_days', 'expiry_months', 'encash_excess', 'legal_min_carry_days',
            ]);

        $best = null;
        $bestRank = -1;
        $bestTier = -1;

        foreach ($rows as $row) {
            $scope = Value::string($row->scope_type);
            $scopeId = Value::nullableInt($row->scope_id);

            $applies = match ($scope) {
                'tenant' => true,
                'branch' => $branchId !== null && $scopeId === $branchId,
                'category' => $scopeId !== null && in_array($scopeId, $categoryIds, true),
                'employee' => $scopeId === $employeeId,
                default => false,
            };

            if (! $applies) {
                continue;
            }

            $rank = self::SCOPE_RANK[$scope] ?? 0;
            $tier = Value::int($row->min_seniority_months);

            if ($rank > $bestRank || ($rank === $bestRank && $tier > $bestTier)) {
                $best = $row;
                $bestRank = $rank;
                $bestTier = $tier;
            }
        }

        if ($best !== null) {
            return new self(
                Value::int($best->carryover_enabled) === 1,
                Value::nullableInt($best->carryover_max_days),
                Value::nullableInt($best->expiry_months),
                Value::int($best->encash_excess) === 1,
                Value::nullableInt($best->legal_min_carry_days),
                Value::string($best->scope_type),
            );
        }

        // Before policies existed there was one column on the company. Reading
        // it still is the difference between honouring what a company
        // configured and silently dropping everybody's carried days.
        $legacyMax = Value::nullableInt(
            DB::table('tenants')->where('id', $tenantId)->value('leave_carryover_max_days')
        );

        return new self(
            $legacyMax !== null,
            $legacyMax,
            null,
            false,
            null,
            $legacyMax !== null ? 'legacy' : 'default',
        );
    }

    /**
     * Whole months of service; zero when unknown, or when the hire date is in
     * the future — a start date that has not arrived is not seniority.
     */
    public static function tenureMonths(?string $hireDate): int
    {
        if ($hireDate === null || $hireDate === '') {
            return 0;
        }

        try {
            $hire = new DateTimeImmutable($hireDate);
        } catch (Throwable) {
            return 0;
        }

        $today = new DateTimeImmutable('today');

        if ($hire > $today) {
            return 0;
        }

        $difference = $hire->diff($today);

        return $difference->y * 12 + $difference->m;
    }
}
