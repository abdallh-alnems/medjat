<?php

declare(strict_types=1);

namespace App\Modules\Employees\Domain;

use App\Models\Admin;
use App\Models\Employee;
use Illuminate\Support\Facades\DB;

/**
 * The `admins` row an employee's permissions hang off.
 *
 * Employees carry permissions through an `admins` row with the `employee`
 * role, created on first activation and reused afterwards. The firebase_uid is
 * synthetic, because an employee never authenticates through Firebase.
 *
 * One implementation, called from both activation paths. The original had two
 * copies with a comment on each saying they must stay identical and that the
 * next person to touch either should collapse them — which is this. The failure
 * they were guarding against is real and was live: an employee's account
 * differed depending on whether they first activated on a phone or in a
 * browser, because only the phone path created the row.
 */
final class EmployeeAccount
{
    /**
     * Marks the employee active and returns their admin id, creating the row if
     * this is the first time.
     */
    public static function activate(Employee $employee): int
    {
        Employee::query()->whereKey($employee->id)->update([
            'status' => 'active',
            'has_linked_account' => 1,
            'updated_at' => DB::raw('NOW()'),
        ]);

        return self::ensureAdminRow($employee);
    }

    /**
     * The admin id for this employee, creating the row if there is none.
     */
    public static function ensureAdminRow(Employee $employee): int
    {
        if ($employee->admin_id !== null) {
            return $employee->admin_id;
        }

        // An employee who was once a manager, or who was invited before being
        // hired, already has a row under the same phone. Reusing it keeps one
        // person to one account.
        $existing = Admin::query()
            ->where('tenant_id', $employee->tenant_id)
            ->where('phone', $employee->phone)
            ->where('role', 'employee')
            ->first();

        $adminId = $existing !== null ? $existing->id : (int) Admin::query()->insertGetId([
            'firebase_uid' => 'employee:'.$employee->id,
            'tenant_id' => $employee->tenant_id,
            'branch_id' => $employee->branch_id,
            'name' => $employee->name,
            'phone' => $employee->phone,
            'role' => 'employee',
        ]);

        Employee::query()->whereKey($employee->id)->update(['admin_id' => $adminId]);
        $employee->admin_id = $adminId;

        return $adminId;
    }
}
