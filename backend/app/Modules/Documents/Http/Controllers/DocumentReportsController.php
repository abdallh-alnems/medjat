<?php

declare(strict_types=1);

namespace App\Modules\Documents\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Documents\Domain\DocumentScope;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/documents/reports_*.php and mark_expired.php.
 *
 * Where a company stands on paperwork: what has not been handed in, what is
 * about to lapse, and what already has.
 */
final class DocumentReportsController
{
    /** The window "expiring soon" means when nobody says otherwise. */
    private const DEFAULT_DAYS_AHEAD = 30;

    /**
     * Documents that are owed and have never been handed in.
     *
     * Optional types are excluded: a company chases what it requires, and
     * listing the rest as "missing" buries the ones that matter.
     */
    public function missing(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->query('employee_id')) ?: null;
        $branchId = Value::int($request->query('branch_id')) ?: null;

        $rows = DocumentScope::obligations($tenantId)
            ->leftJoin('employee_documents as ed', function (JoinClause $join): void {
                $join->on('ed.employee_id', '=', 'e.id')->on('ed.required_document_id', '=', 'rd.id');
            })
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->whereNull('ed.id')
            // Naming one person narrows to them; otherwise the branch filter
            // applies, exactly as the two original endpoints behaved.
            ->when($employeeId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.id', $employeeId))
            ->when(
                $employeeId === null && $branchId !== null,
                fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId)
            )
            ->get([
                'e.id as employee_id', 'e.name as employee_name', 'e.branch_id', 'b.name as branch_name',
                'rd.id as required_document_id', 'rd.name as document_name', 'rd.category',
            ])
            ->all();

        return ApiResponse::success(['missing_documents' => self::rows($rows)]);
    }

    public function expiringSoon(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $daysAhead = Value::int($request->query('days_ahead'), self::DEFAULT_DAYS_AHEAD);
        $branchId = Value::int($request->query('branch_id')) ?: null;

        $rows = $this->dated($tenantId, $branchId)
            ->where('ed.status', 'uploaded')
            // Compared against the database's own date, so "soon" does not
            // depend on which timezone the PHP process happens to run in.
            ->whereRaw('ed.expires_at BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL ? DAY)', [$daysAhead])
            ->get(self::COLUMNS)
            ->all();

        return ApiResponse::success(['documents' => self::rows($rows)]);
    }

    /**
     * Includes documents still marked uploaded whose date has passed, not only
     * ones already flipped to expired — otherwise the report would show nothing
     * until somebody ran the sweep.
     */
    public function expired(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = Value::int($request->query('branch_id')) ?: null;

        $rows = $this->dated($tenantId, $branchId)
            ->whereIn('ed.status', ['expired', 'uploaded'])
            ->whereRaw('ed.expires_at < CURDATE()')
            ->get(self::COLUMNS)
            ->all();

        return ApiResponse::success(['documents' => self::rows($rows)]);
    }

    public function stats(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $required = DocumentScope::obligations($tenantId)->count();

        $missing = DocumentScope::obligations($tenantId)
            ->leftJoin('employee_documents as ed', function (JoinClause $join): void {
                $join->on('ed.employee_id', '=', 'e.id')->on('ed.required_document_id', '=', 'rd.id');
            })
            ->whereNull('ed.id')
            ->count();

        $counts = DB::table('employee_documents')
            ->where('tenant_id', $tenantId)
            ->selectRaw(
                "COUNT(CASE WHEN status = 'uploaded' THEN 1 END) AS uploaded,"
                ."COUNT(CASE WHEN status = 'expired' THEN 1 END) AS expired,"
                ."COUNT(CASE WHEN status = 'uploaded' AND expires_at IS NOT NULL"
                .' AND expires_at BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL '
                .self::DEFAULT_DAYS_AHEAD.' DAY) THEN 1 END) AS expiring_soon'
            )
            ->first();

        return ApiResponse::success([
            'stats' => [
                'total_required' => $required,
                'total_uploaded' => Value::int($counts?->uploaded),
                'total_missing' => $missing,
                'total_expired' => Value::int($counts?->expired),
                'total_expiring_soon' => Value::int($counts?->expiring_soon),
            ],
        ]);
    }

    /**
     * Flips documents whose date has passed to expired.
     *
     * Run on demand rather than on a schedule here; the reports do not depend
     * on it having run, so this only tidies the stored state.
     */
    public function markExpired(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        $count = DB::table('employee_documents')
            ->where('tenant_id', $tenantId)
            ->where('status', 'uploaded')
            ->whereNotNull('expires_at')
            ->whereRaw('expires_at < CURDATE()')
            ->update(['status' => 'expired']);

        AuditLog::record($tenantId, $adminId, 'documents.mark_expired', null, null, ['count' => $count]);

        return ApiResponse::success(['marked_expired' => $count]);
    }

    private const COLUMNS = [
        'ed.*', 'e.name as employee_name', 'e.branch_id', 'b.name as branch_name', 'rd.name as document_name',
    ];

    private function dated(int $tenantId, ?int $branchId): QueryBuilder
    {
        return DB::table('employee_documents as ed')
            ->join('employees as e', 'e.id', '=', 'ed.employee_id')
            ->join('required_documents as rd', 'rd.id', '=', 'ed.required_document_id')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->where('ed.tenant_id', $tenantId)
            ->whereNotNull('ed.expires_at')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId))
            ->orderBy('ed.expires_at');
    }

    /**
     * @param  array<int, mixed>  $rows
     * @return list<array<string, mixed>>
     */
    private static function rows(array $rows): array
    {
        return array_values(array_map(
            static function (mixed $row): array {
                /** @var array<string, mixed> $columns */
                $columns = (array) $row;

                return $columns;
            },
            $rows,
        ));
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $admin;
    }
}
