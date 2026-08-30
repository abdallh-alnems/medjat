<?php

declare(strict_types=1);

namespace App\Domain\Documents;

use App\Support\Value;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * The catalogue of documents a company asks its staff for.
 *
 * A type carries its own scope — everybody, one branch, a named list of people,
 * or a job category — and the two membership tables that back the last two are
 * rewritten wholesale rather than diffed: a scope is a statement of who is
 * covered now, not a history of who was added when.
 */
final class RequiredDocument
{
    public const CATEGORIES = ['identity', 'contract', 'certificate', 'insurance', 'general'];

    public const SCOPES = ['all', 'branch', 'employees', 'category'];

    /** The columns a client may set; anything else is ignored rather than trusted. */
    private const WRITABLE = [
        'name', 'description', 'expiry_days', 'notification_days_before',
        'category', 'sort_order', 'is_required', 'is_active',
        'scope_type', 'scope_branch_id',
    ];

    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $id, int $tenantId): ?array
    {
        $row = DB::table('required_documents')->where('id', $id)->where('tenant_id', $tenantId)->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * The catalogue with each type's scope resolved to names.
     *
     * Names travel with the ids so a client can render the scope without a
     * second round trip, and they come from a join, so a type scoped to
     * somebody who has since left shows the people who actually remain.
     *
     * @return list<array<string, mixed>>
     */
    public static function catalogue(int $tenantId): array
    {
        $rows = DB::table('required_documents')
            ->where('tenant_id', $tenantId)
            ->orderBy('sort_order')->orderBy('name')
            ->get()->all();

        $documents = [];

        foreach ($rows as $row) {
            $document = self::toArray($row);
            $id = Value::int($document['id'] ?? null);
            $scope = Value::string($document['scope_type'] ?? null, 'all');

            $employees = $scope === 'employees' ? self::scopedEmployees($id, $tenantId) : [];
            $categories = $scope === 'category' ? self::scopedCategories($id, $tenantId) : [];

            $document['scope_employees'] = $employees;
            $document['scope_employee_ids'] = array_column($employees, 'id');
            $document['scope_categories'] = $categories;
            $document['scope_category_ids'] = array_column($categories, 'id');

            $documents[] = $document;
        }

        return $documents;
    }

    /**
     * @param  array<string, mixed>  $fields
     */
    public static function create(int $tenantId, array $fields): int
    {
        return (int) DB::table('required_documents')->insertGetId(
            ['tenant_id' => $tenantId] + self::writable($fields)
        );
    }

    /**
     * @param  array<string, mixed>  $fields
     */
    public static function update(int $id, int $tenantId, array $fields): bool
    {
        $writable = self::writable($fields);

        if ($writable === []) {
            return false;
        }

        return DB::table('required_documents')->where('id', $id)->where('tenant_id', $tenantId)
            ->update($writable) > 0;
    }

    public static function delete(int $id, int $tenantId): bool
    {
        return DB::table('required_documents')->where('id', $id)->where('tenant_id', $tenantId)->delete() > 0;
    }

    public static function toggleActive(int $id, int $tenantId): void
    {
        DB::table('required_documents')->where('id', $id)->where('tenant_id', $tenantId)
            ->update(['is_active' => DB::raw('NOT is_active')]);
    }

    /**
     * @param  list<int>  $employeeIds
     */
    public static function setEmployeeScope(int $id, int $tenantId, array $employeeIds): void
    {
        self::replaceScope('required_document_employees', 'employee_id', $id, $tenantId, $employeeIds);
    }

    /**
     * @param  list<int>  $categoryIds
     */
    public static function setCategoryScope(int $id, int $tenantId, array $categoryIds): void
    {
        self::replaceScope('required_document_categories', 'category_id', $id, $tenantId, $categoryIds);
    }

    /**
     * @param  list<int>  $ids
     */
    private static function replaceScope(string $table, string $column, int $id, int $tenantId, array $ids): void
    {
        DB::transaction(function () use ($table, $column, $id, $tenantId, $ids): void {
            DB::table($table)->where('required_document_id', $id)->where('tenant_id', $tenantId)->delete();

            $rows = [];
            foreach (array_unique($ids) as $memberId) {
                if ($memberId > 0) {
                    $rows[] = ['required_document_id' => $id, $column => $memberId, 'tenant_id' => $tenantId];
                }
            }

            if ($rows !== []) {
                DB::table($table)->insert($rows);
            }
        });
    }

    /**
     * @return list<array{id: int, name: mixed}>
     */
    public static function scopedEmployees(int $id, int $tenantId): array
    {
        $rows = DB::table('required_document_employees as rde')
            ->join('employees as e', function (JoinClause $join): void {
                $join->on('e.id', '=', 'rde.employee_id')->on('e.tenant_id', '=', 'rde.tenant_id');
            })
            ->where('rde.required_document_id', $id)->where('rde.tenant_id', $tenantId)
            ->orderBy('e.name')
            ->get(['e.id', 'e.name']);

        return array_values($rows->map(static fn (object $row): array => [
            'id' => Value::int($row->id), 'name' => $row->name,
        ])->all());
    }

    /**
     * @return list<array{id: int, name: mixed}>
     */
    public static function scopedCategories(int $id, int $tenantId): array
    {
        $rows = DB::table('required_document_categories as rdc')
            ->join('employee_categories as c', function (JoinClause $join): void {
                $join->on('c.id', '=', 'rdc.category_id')->on('c.tenant_id', '=', 'rdc.tenant_id');
            })
            ->where('rdc.required_document_id', $id)->where('rdc.tenant_id', $tenantId)
            ->orderBy('c.name')
            ->get(['c.id', 'c.name']);

        return array_values($rows->map(static fn (object $row): array => [
            'id' => Value::int($row->id), 'name' => $row->name,
        ])->all());
    }

    /**
     * @param  array<string, mixed>  $fields
     * @return array<string, mixed>
     */
    private static function writable(array $fields): array
    {
        return array_intersect_key($fields, array_flip(self::WRITABLE));
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
