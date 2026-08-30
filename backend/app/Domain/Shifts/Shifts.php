<?php

declare(strict_types=1);

namespace App\Domain\Shifts;

use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Named working hours a company can put people on.
 *
 * A shift is a convenience, not a dependency: an employee always has their own
 * start and end times, and the shift simply supplies them. That is what makes
 * deleting one safe — the people on it keep working the same hours either way,
 * as long as somebody remembers to carry the times across.
 */
final class Shifts
{
    /** The columns a company may change. */
    private const WRITABLE = ['name', 'branch_id', 'start_time', 'end_time', 'is_active'];

    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $id, int $tenantId): ?array
    {
        $row = DB::table('shifts')->where('id', $id)->where('tenant_id', $tenantId)->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * Active shifts, with how many people are on each.
     *
     * A branch filter also returns the company-wide shifts, because a shift
     * with no branch applies everywhere and hiding it would make the branch
     * look as if it had none.
     *
     * @return list<array<string, mixed>>
     */
    public static function forTenant(int $tenantId, ?int $branchId = null): array
    {
        $rows = DB::table('shifts as s')
            ->leftJoin('branches as b', 'b.id', '=', 's.branch_id')
            ->where('s.tenant_id', $tenantId)
            ->where('s.is_active', 1)
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where(
                fn (QueryBuilder $scope): QueryBuilder => $scope
                    ->where('s.branch_id', $branchId)->orWhereNull('s.branch_id')
            ))
            ->orderBy('s.start_time')
            ->get([
                's.*', 'b.name as branch_name',
                DB::raw(
                    "(SELECT COUNT(*) FROM employees e WHERE e.shift_id = s.id AND e.status != 'terminated')"
                    .' AS employee_count'
                ),
            ])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public static function create(int $tenantId, array $data): int
    {
        return (int) DB::table('shifts')->insertGetId([
            'tenant_id' => $tenantId,
            'branch_id' => $data['branch_id'] ?? null,
            'name' => $data['name'] ?? null,
            'start_time' => $data['start_time'] ?? null,
            'end_time' => $data['end_time'] ?? null,
        ]);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public static function update(int $id, int $tenantId, array $data): void
    {
        $writable = array_intersect_key($data, array_flip(self::WRITABLE));

        if ($writable === []) {
            return;
        }

        DB::table('shifts')->where('id', $id)->where('tenant_id', $tenantId)->update($writable);
    }

    public static function delete(int $id, int $tenantId): void
    {
        DB::table('shifts')->where('id', $id)->where('tenant_id', $tenantId)->delete();
    }

    /**
     * @param  list<int>  $employeeIds
     */
    public static function assign(int $shiftId, array $employeeIds, int $tenantId): int
    {
        if ($employeeIds === []) {
            return 0;
        }

        return DB::table('employees')
            ->where('tenant_id', $tenantId)->whereIn('id', $employeeIds)
            ->update(['shift_id' => $shiftId]);
    }

    /**
     * @param  list<int>  $employeeIds
     */
    public static function unassign(int $shiftId, array $employeeIds, int $tenantId): int
    {
        if ($employeeIds === []) {
            return 0;
        }

        return DB::table('employees')
            ->where('tenant_id', $tenantId)->where('shift_id', $shiftId)->whereIn('id', $employeeIds)
            ->update(['shift_id' => null]);
    }

    /** Moves everybody on one shift to another, before the first is removed. */
    public static function transferEmployees(int $fromShiftId, int $toShiftId, int $tenantId): int
    {
        return DB::table('employees')
            ->where('shift_id', $fromShiftId)->where('tenant_id', $tenantId)
            ->where('status', '!=', 'terminated')
            ->update(['shift_id' => $toShiftId]);
    }

    /**
     * Copies a shift's hours onto each member's own working hours.
     *
     * The alternative to transferring: everybody keeps the hours they had,
     * written where they will survive the shift being deleted.
     */
    public static function applyTimesToEmployees(int $shiftId, string $startTime, string $endTime, int $tenantId): int
    {
        return DB::table('employees')
            ->where('shift_id', $shiftId)->where('tenant_id', $tenantId)
            ->where('status', '!=', 'terminated')
            ->update(['work_start_time' => $startTime, 'work_end_time' => $endTime]);
    }

    /** Repoints future roster cells so scheduled days keep a valid shift. */
    public static function transferSchedule(int $fromShiftId, int $toShiftId, int $tenantId): int
    {
        return DB::table('employee_shift_schedule')
            ->where('shift_id', $fromShiftId)->where('tenant_id', $tenantId)
            ->update(['shift_id' => $toShiftId]);
    }

    /**
     * @return array<string, mixed>
     */
    private static function toArray(mixed $row): array
    {
        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }
}
