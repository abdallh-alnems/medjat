<?php

declare(strict_types=1);

namespace App\Domain\Crew;

use App\Domain\Time\TenantClock;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * A supervisor and the people who report to them on site.
 *
 * For crews without phones — construction, cleaning, security — where one
 * foreman marks everybody. Being a supervisor is derived from whether anyone
 * points at you, never from a flag, so an empty crew and "not a supervisor" are
 * the same state by construction and cannot drift apart.
 */
final class Crew
{
    /**
     * The crew, with today's state for each person.
     *
     * Today's times come back alongside the names so the app can show who is
     * already marked without a second call — a foreman on a site with one bar of
     * signal should pay for one round trip, not two.
     *
     * @return list<array<string, mixed>>
     */
    public static function membersFor(int $supervisorId, int $tenantId): array
    {
        if ($supervisorId <= 0) {
            return [];
        }

        $rows = DB::table('employees as e')
            ->leftJoin('attendance as a', function (JoinClause $join) use ($tenantId): void {
                $join->on('a.employee_id', '=', 'e.id')
                    ->on('a.tenant_id', '=', 'e.tenant_id')
                    ->where('a.date', '=', TenantClock::date($tenantId));
            })
            ->where('e.crew_supervisor_id', $supervisorId)
            ->where('e.tenant_id', $tenantId)
            ->where(function (QueryBuilder $query): void {
                $query->whereNull('e.status')->orWhere('e.status', '!=', 'terminated');
            })
            ->orderBy('e.name')
            ->get([
                'e.id', 'e.name', 'e.job_title', 'e.branch_id', 'e.profile_image',
                'a.check_in_time', 'a.check_out_time', 'a.status as attendance_status',
            ]);

        return array_values(array_map(static fn (object $row): array => [
            'id' => Value::int($row->id),
            'name' => $row->name,
            'job_title' => $row->job_title,
            'profile_image' => $row->profile_image,
            'check_in_time' => $row->check_in_time,
            'check_out_time' => $row->check_out_time,
        ], $rows->all()));
    }

    /** True when this company wants a photograph with each crew punch. */
    public static function photoRequired(int $tenantId): bool
    {
        return Value::int(DB::table('tenants')->where('id', $tenantId)->value('crew_photo_required')) === 1;
    }

    /**
     * Whether pointing $employeeId at $supervisorId would close a ring.
     *
     * The database cannot check this. A self-reference CHECK is refused by MySQL
     * 8 on a column carrying ON DELETE SET NULL, and a longer ring spans rows a
     * CHECK cannot see anyway. So the chain is walked here.
     *
     * The hop limit is a guard, not a depth policy: running out of hops means
     * the *existing* chain is already a ring, and adding to it is refused rather
     * than looped on forever.
     */
    public static function wouldCycle(int $supervisorId, int $employeeId, int $tenantId): bool
    {
        if ($supervisorId <= 0 || $employeeId <= 0) {
            return false;
        }

        if ($supervisorId === $employeeId) {
            return true;
        }

        $cursor = $supervisorId;

        for ($hop = 0; $hop < 32; $hop++) {
            $next = DB::table('employees')
                ->where('id', $cursor)
                ->where('tenant_id', $tenantId)
                ->value('crew_supervisor_id');

            if ($next === null) {
                return false;
            }

            if (Value::int($next) === $employeeId) {
                return true;
            }

            $cursor = Value::int($next);
        }

        return true;
    }
}
