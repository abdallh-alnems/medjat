<?php

declare(strict_types=1);

namespace App\Modules\Categories\Domain;

use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Job categories: the grouping most other features scope themselves by.
 *
 * A category is a label, so it can be renamed or switched off freely. It cannot
 * be deleted while a document requirement is scoped to it, because that would
 * silently drop the requirement rather than the label.
 */
final class EmployeeCategories
{
    private const WRITABLE = ['name', 'description', 'color', 'is_active'];

    /**
     * @return list<array<string, mixed>>
     */
    public static function forTenant(int $tenantId, bool $activeOnly = false): array
    {
        $rows = DB::table('employee_categories as ec')
            ->where('ec.tenant_id', $tenantId)
            ->when($activeOnly, fn (QueryBuilder $q): QueryBuilder => $q->where('ec.is_active', 1))
            ->orderBy('ec.name')
            ->get([
                'ec.*',
                // Terminated staff excluded, so the figure matches the employee
                // list, which never shows them.
                DB::raw(
                    '(SELECT COUNT(*) FROM employee_category_assignments eca'
                    .' JOIN employees e ON e.id = eca.employee_id AND e.tenant_id = eca.tenant_id'
                    .' WHERE eca.category_id = ec.id AND eca.tenant_id = ec.tenant_id'
                    ." AND e.status != 'terminated') AS employee_count"
                ),
            ])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $id, int $tenantId): ?array
    {
        $row = DB::table('employee_categories')->where('id', $id)->where('tenant_id', $tenantId)->first();

        return $row === null ? null : self::toArray($row);
    }

    public static function nameTaken(string $name, int $tenantId, ?int $excludeId = null): bool
    {
        return DB::table('employee_categories')
            ->where('name', $name)->where('tenant_id', $tenantId)
            ->when($excludeId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('id', '!=', $excludeId))
            ->exists();
    }

    public static function create(int $tenantId, string $name, ?string $description, ?string $color): int
    {
        return (int) DB::table('employee_categories')->insertGetId([
            'tenant_id' => $tenantId,
            'name' => $name,
            'description' => $description,
            'color' => $color,
        ]);
    }

    /**
     * @param  array<string, mixed>  $fields
     */
    public static function update(int $id, int $tenantId, array $fields): void
    {
        $writable = array_intersect_key($fields, array_flip(self::WRITABLE));

        if ($writable === []) {
            return;
        }

        DB::table('employee_categories')->where('id', $id)->where('tenant_id', $tenantId)->update($writable);
    }

    /**
     * The browser-channel exception: 1 allow, 0 refuse, null inherit.
     *
     * Null is the default, and the reason a company that simply turns the
     * channel on needs no category configuration at all.
     */
    public static function setWebAccess(int $id, int $tenantId, ?bool $allowed): void
    {
        DB::table('employee_categories')->where('id', $id)->where('tenant_id', $tenantId)
            ->update(['web_attendance_allowed' => $allowed === null ? null : ($allowed ? 1 : 0)]);
    }

    /**
     * A category a document requirement is scoped to cannot be deleted:
     * removing it would silently drop the requirement, not just the label.
     */
    public static function usedByDocuments(int $categoryId, int $tenantId): bool
    {
        return DB::table('required_document_categories')
            ->where('category_id', $categoryId)->where('tenant_id', $tenantId)
            ->exists();
    }

    public static function delete(int $id, int $tenantId): void
    {
        DB::table('employee_categories')->where('id', $id)->where('tenant_id', $tenantId)->delete();
    }

    /**
     * Replaces an employee's categories wholesale.
     *
     * The list is a statement of what they are now, not a history of what has
     * been added, so it is rewritten rather than merged.
     *
     * @param  list<int>  $categoryIds
     */
    public static function assignToEmployee(int $employeeId, int $tenantId, array $categoryIds): void
    {
        DB::transaction(function () use ($employeeId, $tenantId, $categoryIds): void {
            DB::table('employee_category_assignments')
                ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
                ->delete();

            $rows = [];

            foreach (array_unique($categoryIds) as $categoryId) {
                if ($categoryId > 0) {
                    $rows[] = [
                        'employee_id' => $employeeId,
                        'category_id' => $categoryId,
                        'tenant_id' => $tenantId,
                    ];
                }
            }

            if ($rows !== []) {
                DB::table('employee_category_assignments')->insert($rows);
            }
        });
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
