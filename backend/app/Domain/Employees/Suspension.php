<?php

declare(strict_types=1);

namespace App\Domain\Employees;

use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * Standing somebody down without ending their employment.
 *
 * The status the employee held beforehand is recorded on the suspension, not
 * assumed — somebody suspended while on leave goes back to being on leave, not
 * to active, and reconstructing that afterwards is impossible.
 */
final class Suspension
{
    /** @var list<string> */
    public const PAY_MODES = ['unpaid', 'partial', 'full'];

    /**
     * @return object{id: int, previous_status: string|null}|null
     */
    public static function activeFor(int $employeeId, int $tenantId): ?object
    {
        /** @var object{id: int, previous_status: string|null}|null */
        return DB::table('employee_suspensions')
            ->where('employee_id', $employeeId)
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->orderByDesc('start_date')
            ->orderByDesc('id')
            ->first(['id', 'previous_status']);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public static function open(int $tenantId, int $employeeId, array $data, int $createdBy): int
    {
        return (int) DB::table('employee_suspensions')->insertGetId([
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'reason' => $data['reason'],
            'pay_mode' => $data['pay_mode'],
            'pay_percentage' => $data['pay_percentage'] ?? null,
            'start_date' => $data['start_date'],
            'end_date' => $data['end_date'] ?? null,
            'previous_status' => $data['previous_status'] ?? null,
            'created_by' => $createdBy,
        ]);
    }

    public static function close(int $id, int $tenantId, int $endedBy, ?string $note): bool
    {
        return DB::table('employee_suspensions')
            ->where('id', $id)->where('tenant_id', $tenantId)->where('status', 'active')
            ->update([
                'status' => 'ended',
                'ended_at' => DB::raw('NOW()'),
                'ended_by' => $endedBy,
                'end_note' => $note,
            ]) > 0;
    }

    /**
     * Ends definite suspensions whose date has passed and restores the people.
     *
     * Run when the screen is opened rather than by a scheduler: the company that
     * cares is the one looking, and a suspension that quietly outlives its own
     * end date is somebody unable to work for a reason nobody remembers setting.
     *
     * @return int Suspensions closed.
     */
    public static function reconcileExpired(int $tenantId, string $today): int
    {
        $due = DB::table('employee_suspensions')
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->whereNotNull('end_date')
            ->where('end_date', '<', $today)
            ->get(['id', 'employee_id', 'previous_status']);

        foreach ($due as $suspension) {
            DB::table('employee_suspensions')
                ->where('id', Value::int($suspension->id))
                ->where('tenant_id', $tenantId)
                ->where('status', 'active')
                ->update(['status' => 'ended', 'ended_at' => DB::raw('NOW()')]);

            // Guarded on 'suspended': if somebody has since been terminated or
            // moved on, an elapsed suspension must not drag them back.
            DB::table('employees')
                ->where('id', Value::int($suspension->employee_id))
                ->where('tenant_id', $tenantId)
                ->where('status', 'suspended')
                ->update([
                    'status' => Value::string($suspension->previous_status, 'active') ?: 'active',
                    'updated_at' => DB::raw('NOW()'),
                ]);
        }

        return $due->count();
    }
}
