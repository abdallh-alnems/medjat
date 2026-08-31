<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Domain;

use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * One-off bonuses and deductions somebody typed in.
 *
 * These sit alongside the computed lines and are never overridden by the
 * correction layer — they are already exactly what a person decided, so there
 * is nothing to correct that editing the row itself would not do better.
 */
final class ManualAdjustments
{
    public function record(
        bool $isBonus,
        int $employeeId,
        int $tenantId,
        float $amount,
        string $reason,
        int $adminId,
        string $month,
        ?int $batchId = null,
    ): int {
        return (int) DB::table($isBonus ? 'manual_bonuses' : 'manual_deductions')->insertGetId([
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'batch_id' => $batchId,
            'amount' => $amount,
            'reason' => $reason,
            'month' => $month,
            'created_by' => $adminId,
        ]);
    }

    /**
     * Everybody a bulk adjustment should reach.
     *
     * Terminated and suspended people are excluded everywhere: neither is being
     * paid this month, and a bonus row against them would sit unpaid forever.
     *
     * @return list<array<string, mixed>>
     */
    public function inScope(string $scopeType, int $scopeId, int $tenantId): array
    {
        $query = DB::table('employees as e')
            ->where('e.tenant_id', $tenantId)
            ->whereNotIn('e.status', ['terminated', 'suspended']);

        match ($scopeType) {
            'all' => null,
            'employee' => $query->where('e.id', $scopeId),
            'branch' => $query->where('e.branch_id', $scopeId),
            'shift' => $query->where('e.shift_id', $scopeId),
            'category' => $query
                ->join('employee_category_assignments as eca', function (JoinClause $join): void {
                    $join->on('eca.employee_id', '=', 'e.id')->on('eca.tenant_id', '=', 'e.tenant_id');
                })
                ->where('eca.category_id', $scopeId),
            default => $query->whereRaw('1 = 0'),
        };

        $rows = $query->get(['e.id', 'e.admin_id', 'e.base_salary'])->all();

        return array_values(array_map(
            static function (mixed $row): array {
                /** @var array<string, mixed> $columns */
                $columns = (array) $row;

                return $columns;
            },
            $rows,
        ));
    }
}
