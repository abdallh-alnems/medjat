<?php

declare(strict_types=1);

namespace App\Domain\Documents;

use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * What this employee is required to hand in, and what they have handed in.
 *
 * Everything required is listed, including items with nothing uploaded against
 * them, so the employee sees what is expected rather than an empty screen. A
 * missing document reads as 'required', which is a state rather than an absence.
 *
 * Requirements are scoped four ways — everyone, one branch, named people, or a
 * category — and the resolution happens in SQL so the list cannot disagree with
 * the one the compliance report builds.
 */
final class DocumentChecklist
{
    /**
     * @return list<array<string, mixed>>
     */
    public static function forEmployee(int $employeeId, int $tenantId): array
    {
        $rows = DB::table('required_documents as rd')
            ->join('employees as e', function (JoinClause $join) use ($employeeId, $tenantId): void {
                $join->where('e.id', '=', $employeeId)->where('e.tenant_id', '=', $tenantId);
            })
            ->leftJoin('employee_documents as ed', function (JoinClause $join): void {
                $join->on('ed.required_document_id', '=', 'rd.id')
                    ->on('ed.employee_id', '=', 'e.id')
                    ->on('ed.tenant_id', '=', 'rd.tenant_id');
            })
            ->where('rd.tenant_id', $tenantId)
            ->where('rd.is_active', 1)
            ->where(function (QueryBuilder $scope) use ($tenantId): void {
                $scope->where('rd.scope_type', 'all')
                    ->orWhere(function (QueryBuilder $branch): void {
                        $branch->where('rd.scope_type', 'branch')
                            ->whereColumn('rd.scope_branch_id', 'e.branch_id');
                    })
                    ->orWhere(function (QueryBuilder $named): void {
                        $named->where('rd.scope_type', 'employees')
                            ->whereExists(function (QueryBuilder $sub): void {
                                $sub->select(DB::raw(1))
                                    ->from('required_document_employees as rde')
                                    ->whereColumn('rde.required_document_id', 'rd.id')
                                    ->whereColumn('rde.employee_id', 'e.id');
                            });
                    })
                    ->orWhere(function (QueryBuilder $category) use ($tenantId): void {
                        $category->where('rd.scope_type', 'category')
                            ->whereExists(function (QueryBuilder $sub) use ($tenantId): void {
                                $sub->select(DB::raw(1))
                                    ->from('required_document_categories as rdc')
                                    ->join('employee_category_assignments as eca', function (JoinClause $join): void {
                                        $join->on('eca.category_id', '=', 'rdc.category_id')
                                            ->on('eca.tenant_id', '=', 'rdc.tenant_id');
                                    })
                                    ->whereColumn('rdc.required_document_id', 'rd.id')
                                    ->whereColumn('eca.employee_id', 'e.id')
                                    ->where('rdc.tenant_id', $tenantId);
                            });
                    });
            })
            ->orderBy('rd.sort_order')
            ->orderBy('rd.name')
            ->get([
                'rd.id as required_document_id',
                'rd.name as document_type_name',
                'rd.description',
                'rd.category',
                'rd.is_required',
                'ed.id as employee_document_id',
                'ed.file_path',
                'ed.original_name',
                'ed.rejected_reason',
                'ed.verified_at',
                'ed.expires_at as expiry_date',
                DB::raw("COALESCE(ed.status, 'required') as status"),
            ]);

        /** @var list<array<string, mixed>> */
        return array_values(array_map(static fn (object $row): array => (array) $row, $rows->all()));
    }
}
