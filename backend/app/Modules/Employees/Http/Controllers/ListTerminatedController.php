<?php

declare(strict_types=1);

namespace App\Modules\Employees\Http\Controllers;

use App\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/employees/list_terminated.php.
 *
 * People whose service has ended, with their last settlement, for the re-hire
 * screen. A separate view because the ordinary list hides them — showing former
 * staff among current ones is how somebody gets paid twice.
 */
final class ListTerminatedController
{
    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $page = max(1, Value::int($request->query('page'), 1));
        $limit = min(50, max(1, Value::int($request->query('limit'), 20)));
        $search = trim(Value::string($request->query('search')));

        $base = DB::table('employees as e')
            ->where('e.tenant_id', $tenantId)
            ->where('e.status', 'terminated');

        if ($search !== '') {
            $base->where(function (QueryBuilder $sub) use ($search): void {
                foreach (['e.name', 'e.phone', 'e.national_id'] as $column) {
                    $sub->orWhere($column, 'like', '%'.$search.'%');
                }
            });
        }

        $total = (clone $base)->count();

        $items = (clone $base)
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->leftJoin('employee_settlements as st', function (JoinClause $join): void {
                $join->on('st.employee_id', '=', 'e.id')->on('st.tenant_id', '=', 'e.tenant_id');
            })
            ->orderByDesc('e.id')
            ->limit($limit)
            ->offset(($page - 1) * $limit)
            ->get([
                'e.id', 'e.name', 'e.phone', 'e.job_title', 'e.profile_image',
                'e.base_salary', 'e.hire_date', 'e.terminated_at', 'e.status',
                'e.national_id', 'e.branch_id', 'b.name as branch_name',
                'st.reason as settlement_reason',
                'st.net_amount as settlement_net_amount',
                'st.status as settlement_status',
                'st.last_working_day as settlement_last_working_day',
            ]);

        return ApiResponse::success([
            'items' => array_values(array_map(static fn (object $row): array => (array) $row, $items->all())),
            'page' => $page,
            'total' => $total,
            'currency' => Value::string(
                DB::table('tenants')->where('id', $tenantId)->value('currency'),
                'EGP'
            ),
        ]);
    }
}
