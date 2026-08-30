<?php

declare(strict_types=1);

namespace App\Services\Employees;

use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * The employee list, with the filters the management screen offers.
 */
final class EmployeeQuery
{
    /** Terminated is never listed here; it has its own screen. */
    public const FILTERABLE_STATUSES = ['active', 'suspended', 'on_leave', 'pending_activation'];

    /**
     * Sort keys mapped to columns rather than interpolated.
     *
     * The value reaches an ORDER BY clause, which cannot be a bound parameter,
     * so it has to come from a list the caller cannot add to.
     *
     * @var array<string, string>
     */
    private const SORT_COLUMNS = [
        'name' => 'e.name',
        'hire_date' => 'e.hire_date',
    ];

    /**
     * @param  array<array-key, mixed>  $filters
     * @return array{items: list<array<string, mixed>>, page: int}
     */
    public function paginate(int $tenantId, array $filters): array
    {
        $page = max(1, Value::int($filters['page'] ?? null, 1));
        $limit = min(50, max(1, Value::int($filters['limit'] ?? null, 20)));

        $query = DB::table('employees as e')
            ->leftJoin('shifts as s', 's.id', '=', 'e.shift_id')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->where('e.tenant_id', $tenantId)
            ->where('e.status', '!=', 'terminated');

        $this->applyFilters($query, $filters);

        $sort = Value::string($filters['sort'] ?? null, 'name');
        $column = self::SORT_COLUMNS[$sort] ?? self::SORT_COLUMNS['name'];
        $direction = mb_strtolower(Value::string($filters['dir'] ?? null, 'asc')) === 'desc' ? 'desc' : 'asc';

        $query->orderBy($column, $direction);

        // A stable tiebreaker, so equal hire dates keep a deterministic order
        // and page two does not repeat a row from page one.
        if ($sort === 'hire_date') {
            $query->orderBy('e.name');
        }

        $rows = $query
            ->limit($limit)
            ->offset(($page - 1) * $limit)
            ->get(['e.*', 's.start_time as shift_start', 's.end_time as shift_end', 's.name as shift_name', 'b.name as branch_name']);

        return [
            'items' => array_values(array_map(
                fn (object $row): array => $this->present($row, $tenantId),
                $rows->all()
            )),
            'page' => $page,
        ];
    }

    /**
     * Headcount by status, honouring the branch scope but not the other
     * filters — the chips show what the company has, not what is on screen.
     *
     * Always returns every key so the interface can render a fixed row of chips
     * rather than a set that changes shape with the data.
     *
     * @return array<string, int>
     */
    public function statusCounts(int $tenantId, ?int $branchId): array
    {
        $counts = [
            'total' => 0,
            'active' => 0,
            'on_leave' => 0,
            'pending_activation' => 0,
            'suspended' => 0,
        ];

        $query = DB::table('employees')
            ->where('tenant_id', $tenantId)
            ->where('status', '!=', 'terminated');

        if ($branchId !== null) {
            $query->where('branch_id', $branchId);
        }

        foreach ($query->groupBy('status')->get(['status', DB::raw('COUNT(*) as c')]) as $row) {
            $count = Value::int($row->c);
            $status = Value::string($row->status);

            $counts['total'] += $count;
            if (array_key_exists($status, $counts)) {
                $counts[$status] = $count;
            }
        }

        return $counts;
    }

    /**
     * @param  array<array-key, mixed>  $filters
     */
    private function applyFilters(QueryBuilder $query, array $filters): void
    {
        $branchId = Value::int($filters['branch_id'] ?? null);
        if ($branchId > 0) {
            $query->where('e.branch_id', $branchId);
        }

        $shiftId = Value::int($filters['shift_id'] ?? null);
        if ($shiftId > 0) {
            $query->where('e.shift_id', $shiftId);
        }

        $categoryId = Value::int($filters['category_id'] ?? null);
        if ($categoryId > 0) {
            // Many-to-many, so an EXISTS rather than a join: joining would
            // multiply rows for anyone in two categories.
            $query->whereExists(function (QueryBuilder $sub) use ($categoryId): void {
                $sub->select(DB::raw(1))
                    ->from('employee_category_assignments as eca')
                    ->whereColumn('eca.employee_id', 'e.id')
                    ->whereColumn('eca.tenant_id', 'e.tenant_id')
                    ->where('eca.category_id', $categoryId);
            });
        }

        $status = Value::string($filters['status'] ?? null);
        if (in_array($status, self::FILTERABLE_STATUSES, true)) {
            $query->where('e.status', $status);
        }

        $expiringWithin = Value::int($filters['expiring_within'] ?? null);
        if ($expiringWithin > 0) {
            // Already-expired documents are included: an expired iqama is more
            // urgent than one expiring next week, not less.
            $query->where(function (QueryBuilder $sub) use ($expiringWithin): void {
                foreach (['iqama_expiry', 'passport_expiry', 'work_permit_expiry'] as $column) {
                    $sub->orWhere(function (QueryBuilder $inner) use ($column, $expiringWithin): void {
                        $inner->whereNotNull("e.{$column}")
                            ->whereRaw("e.{$column} <= DATE_ADD(CURDATE(), INTERVAL ? DAY)", [$expiringWithin]);
                    });
                }
            });
        }

        $search = trim(Value::string($filters['search'] ?? null));
        if ($search !== '') {
            // Qualified with the alias: shifts also has a `name` column, so an
            // unqualified one is ambiguous and errors.
            $query->where(function (QueryBuilder $sub) use ($search): void {
                foreach (['e.name', 'e.phone', 'e.national_id', 'e.job_title'] as $column) {
                    $sub->orWhere($column, 'like', '%'.$search.'%');
                }
            });
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function present(object $row, int $tenantId): array
    {
        /** @var array<string, mixed> $employee */
        $employee = (array) $row;

        // SELECT e.* would otherwise send the face template and the kiosk PIN
        // digest to every client that opens the employee list.
        unset($employee['face_embedding'], $employee['kiosk_pin_hash'], $employee['login_code_hash']);

        $employee['category_ids'] = DB::table('employee_category_assignments')
            ->where('employee_id', Value::int($employee['id'] ?? null))
            ->where('tenant_id', $tenantId)
            ->pluck('category_id')
            ->map(static fn (mixed $id): int => Value::int($id))
            ->values()
            ->all();

        return $employee;
    }
}
