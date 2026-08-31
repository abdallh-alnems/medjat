<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Models\Employee;
use Illuminate\Support\Facades\DB;

/**
 * The rows a tenant-scoped test needs before it can assert anything.
 *
 * Tests used to reach for whichever tenant, branch or employee happened to be
 * first in the table. That only worked because the test database was a copy of
 * production: against a freshly migrated schema the lookups found nothing and
 * everything behind them failed on a foreign key. It also coupled assertions to
 * whatever that one row happened to carry — a test that set a pay cycle start
 * day and read it back was really testing the dump.
 *
 * Every test now builds its own and rolls it back, so no two can see each
 * other's settings.
 */
trait CreatesFixtures
{
    /**
     * @param  array<string, mixed>  $overrides
     */
    protected function createTenant(array $overrides = []): int
    {
        return (int) DB::table('tenants')->insertGetId($overrides + [
            'name' => 'Fixture company',
            'timezone' => 'Africa/Cairo',
            'is_active' => 1,
        ]);
    }

    /**
     * Carries a geofence, because most callers want one and a branch without
     * coordinates rejects every check-in for a reason unrelated to the test.
     *
     * @param  array<string, mixed>  $overrides
     */
    protected function createBranch(int $tenantId, array $overrides = []): int
    {
        return (int) DB::table('branches')->insertGetId($overrides + [
            'tenant_id' => $tenantId,
            'name' => 'Fixture branch',
            'latitude' => 30.5018474,
            'longitude' => 31.0103032,
            'gps_radius_meters' => 50,
            'is_active' => 1,
        ]);
    }

    /**
     * An administrator account, for the tests that need an employee linked to
     * one. Returns the id rather than the row: every caller wants the id.
     *
     * @param  array<string, mixed>  $overrides
     */
    protected function createAdmin(int $tenantId, array $overrides = []): int
    {
        return (int) DB::table('admins')->insertGetId($overrides + [
            'tenant_id' => $tenantId,
            'firebase_uid' => 'uid-'.bin2hex(random_bytes(8)),
            'name' => 'Fixture administrator',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);
    }

    /**
     * Distinct within a run, because the login tests turn on one employee's
     * number not matching another's.
     */
    protected function uniquePhone(): string
    {
        return '+2010'.str_pad((string) random_int(0, 99999999), 8, '0', STR_PAD_LEFT);
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    protected function createEmployee(int $tenantId, array $overrides = []): Employee
    {
        $id = (int) DB::table('employees')->insertGetId($overrides + [
            'tenant_id' => $tenantId,
            'branch_id' => $this->createBranch($tenantId),
            'name' => 'Fixture employee',
            'job_title' => 'Accountant',
            'base_salary' => 5000,
            'hire_date' => '2021-06-01',
            'work_start_time' => '09:00:00',
            'work_end_time' => '17:00:00',
            'shift_type' => 'fixed',
            'status' => 'active',
        ]);

        return Employee::query()->findOrFail($id);
    }
}
