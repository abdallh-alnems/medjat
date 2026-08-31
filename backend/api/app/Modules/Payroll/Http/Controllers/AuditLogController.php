<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/payroll/audit_log.php.
 *
 * Who did what to payroll. Every action this module records is prefixed
 * "payroll.", so the trail is one LIKE away.
 */
final class AuditLogController
{
    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $page = max(1, Value::int($request->query('page'), 1));
        $limit = min(100, max(10, Value::int($request->query('limit'), 50)));

        $items = DB::table('audit_log as al')
            ->leftJoin('admins as a', 'a.id', '=', 'al.admin_id')
            ->where('al.tenant_id', $tenantId)
            ->where('al.action', 'like', 'payroll.%')
            ->orderByDesc('al.created_at')
            ->limit($limit)->offset(($page - 1) * $limit)
            ->get([
                'al.id', 'al.admin_id', 'al.action', 'al.target_type', 'al.target_id',
                'al.payload', 'al.created_at', 'a.name as admin_name',
            ]);

        return ApiResponse::success([
            'items' => array_values(array_map(static fn (object $row): array => (array) $row, $items->all())),
            'page' => $page,
        ]);
    }
}
