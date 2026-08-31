<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/notifications/{list,read}.php.
 *
 * What the employee app shows in its bell.
 */
final class MyNotificationsController
{
    private const DEFAULT_LIMIT = 50;

    private const MAX_LIMIT = 100;

    public function index(Request $request): JsonResponse
    {
        $employee = self::employee($request);

        $limit = min(self::MAX_LIMIT, max(1, Value::int($request->query('limit'), self::DEFAULT_LIMIT)));
        $offset = max(0, Value::int($request->query('offset')));

        $notifications = self::addressedTo($employee)
            ->when(
                $request->boolean('unread_only'),
                fn (QueryBuilder $q): QueryBuilder => $q->whereNull('read_at'),
            )
            ->orderByDesc('created_at')
            ->limit($limit)->offset($offset)
            ->get(['id', 'type', 'title', 'title_ar', 'body', 'body_ar', 'data', 'read_at', 'created_at'])
            ->all();

        return ApiResponse::success([
            'notifications' => $notifications,
            'unread_count' => self::addressedTo($employee)->whereNull('read_at')->count(),
        ]);
    }

    public function markRead(Request $request): JsonResponse
    {
        $employee = self::employee($request);

        $id = Value::int($request->input('id')) ?: Value::int($request->query('id'));

        if ($id <= 0) {
            throw new ApiFailure('Notification ID is required', 400, 'notification_id_required');
        }

        // Scoped to the reader, so the id alone cannot mark somebody else's
        // notification read — and a stranger's id is a 404, not a silent no-op.
        $updated = self::addressedTo($employee)->where('id', $id)->update([
            'read_at' => DB::raw('COALESCE(read_at, NOW())'),
        ]);

        if ($updated === 0 && ! self::addressedTo($employee)->where('id', $id)->exists()) {
            throw new ApiFailure(__('messages.notification_not_found'), 404, 'not_found');
        }

        return ApiResponse::success(['message' => 'Marked as read']);
    }

    /**
     * Notifications belonging to this person.
     *
     * Matched on the employee record *or* their linked administrator account.
     * The original filtered on admin_id alone, which is null for anybody who
     * never linked one — the great majority of employees — so their bell was
     * always empty however many notifications had been written for them. Both
     * are accepted so rows written either way reach the person they are about.
     */
    private static function addressedTo(Employee $employee): QueryBuilder
    {
        $adminId = Value::nullableInt($employee->getAttribute('admin_id'));

        return DB::table('notifications')
            ->where('tenant_id', $employee->tenant_id)
            ->where(function (QueryBuilder $q) use ($employee, $adminId): void {
                $q->where('employee_id', $employee->id);

                if ($adminId !== null) {
                    $q->orWhere('admin_id', $adminId);
                }
            });
    }

    private static function employee(Request $request): Employee
    {
        $employee = $request->attributes->get('employee');

        if (! $employee instanceof Employee) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        return $employee;
    }
}
