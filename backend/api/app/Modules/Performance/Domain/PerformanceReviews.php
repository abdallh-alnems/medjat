<?php

declare(strict_types=1);

namespace App\Modules\Performance\Domain;

use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Written assessments of somebody's work.
 *
 * A review names its reviewer and the direction it came from — a manager, the
 * employee themselves, a peer, a report — because "rated 3" means four
 * different things depending on who said it.
 */
final class PerformanceReviews
{
    public const REVIEWER_TYPES = ['manager', 'self', 'peer', 'subordinate'];

    public const STATUSES = ['draft', 'submitted'];

    /**
     * @param  array<string, mixed>  $data
     */
    public static function create(int $tenantId, array $data, int $reviewerId): int
    {
        return (int) DB::table('performance_reviews')->insertGetId([
            'tenant_id' => $tenantId,
            'employee_id' => $data['employee_id'],
            'cycle_id' => $data['cycle_id'] ?? null,
            'reviewer_id' => $reviewerId,
            'reviewer_type' => $data['reviewer_type'] ?? 'manager',
            'rating' => $data['rating'] ?? null,
            'strengths' => $data['strengths'] ?? null,
            'areas_for_improvement' => $data['areas_for_improvement'] ?? null,
            'review' => $data['review'] ?? null,
            'status' => $data['status'] ?? 'submitted',
        ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $id, int $tenantId): ?array
    {
        $row = DB::table('performance_reviews as pr')
            ->leftJoin('admins as a', 'a.id', '=', 'pr.reviewer_id')
            ->where('pr.id', $id)->where('pr.tenant_id', $tenantId)
            ->first(['pr.*', 'a.name as reviewer_name']);

        if ($row === null) {
            return null;
        }

        /** @var array<string, mixed> $review */
        $review = (array) $row;

        return $review;
    }

    /**
     * @return list<array<string, mixed>>
     */
    public static function forEmployee(int $employeeId, int $tenantId, ?int $cycleId = null): array
    {
        $rows = DB::table('performance_reviews as pr')
            ->leftJoin('admins as a', 'a.id', '=', 'pr.reviewer_id')
            ->where('pr.employee_id', $employeeId)->where('pr.tenant_id', $tenantId)
            ->when($cycleId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('pr.cycle_id', $cycleId))
            ->orderByDesc('pr.created_at')
            ->get(['pr.*', 'a.name as reviewer_name'])
            ->all();

        return array_values(array_map(
            static function (mixed $row): array {
                /** @var array<string, mixed> $review */
                $review = (array) $row;

                return $review;
            },
            $rows,
        ));
    }

    public static function delete(int $id, int $tenantId): bool
    {
        return DB::table('performance_reviews')
            ->where('id', $id)->where('tenant_id', $tenantId)
            ->delete() > 0;
    }

    public static function cycleExists(int $cycleId, int $tenantId): bool
    {
        return DB::table('performance_cycles')
            ->where('id', $cycleId)->where('tenant_id', $tenantId)
            ->exists();
    }
}
