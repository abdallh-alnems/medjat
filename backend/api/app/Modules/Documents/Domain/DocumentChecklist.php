<?php

declare(strict_types=1);

namespace App\Modules\Documents\Domain;

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
        $query = DB::table('required_documents as rd')
            ->join('employees as e', function (JoinClause $join) use ($employeeId, $tenantId): void {
                $join->where('e.id', '=', $employeeId)->where('e.tenant_id', '=', $tenantId);
            })
            ->leftJoin('employee_documents as ed', function (JoinClause $join): void {
                $join->on('ed.required_document_id', '=', 'rd.id')
                    ->on('ed.employee_id', '=', 'e.id')
                    ->on('ed.tenant_id', '=', 'rd.tenant_id');
            })
            ->where('rd.tenant_id', $tenantId)
            ->where('rd.is_active', 1);

        DocumentScope::constrain($query, $tenantId);

        $rows = $query
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
