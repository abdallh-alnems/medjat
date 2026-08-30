<?php

declare(strict_types=1);

namespace App\Domain\Documents;

use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * Which required documents apply to which employees.
 *
 * A document type is asked of everybody, of one branch, of a named list of
 * people, or of a job category. That rule is the same one behind the employee's
 * own checklist, the per-type submission list, the compliance reports and the
 * dashboard counts — so it lives here once. The original repeated the same
 * twelve lines of SQL in five places, which is how four of them can drift from
 * the fifth without anybody noticing.
 */
final class DocumentScope
{
    /**
     * Constrains a query joining required_documents (as rd) to employees (as e)
     * so only applicable pairs survive.
     */
    public static function constrain(QueryBuilder $query, int $tenantId): void
    {
        $query->where(function (QueryBuilder $scope) use ($tenantId): void {
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
        });
    }

    /**
     * Every (employee, required document) pair a company owes, as a query.
     *
     * Active employees and active required-and-not-optional types only: an
     * optional document is offered, never chased.
     */
    public static function obligations(int $tenantId): QueryBuilder
    {
        $query = DB::table('employees as e')
            ->join('required_documents as rd', function (JoinClause $join): void {
                $join->on('rd.tenant_id', '=', 'e.tenant_id');
            })
            ->where('e.tenant_id', $tenantId)
            ->where('e.status', 'active')
            ->where('rd.is_active', 1)
            ->where('rd.is_required', 1);

        self::constrain($query, $tenantId);

        return $query;
    }
}
