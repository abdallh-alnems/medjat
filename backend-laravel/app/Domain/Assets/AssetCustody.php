<?php

declare(strict_types=1);

namespace App\Domain\Assets;

use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Things a company has handed to somebody and expects back.
 *
 * The return is a two-step exchange rather than a single act: the employee says
 * they are handing it back, and somebody with the item in front of them
 * confirms it. A one-sided return would let anybody clear their own custody
 * list without the laptop ever reaching a desk.
 */
final class AssetCustody
{
    public const TYPES = ['money', 'equipment', 'device', 'vehicle', 'document', 'other'];

    public const STATUSES = ['assigned', 'return_requested', 'returned'];

    /**
     * @param  array<string, mixed>  $data
     */
    public static function create(int $tenantId, int $employeeId, array $data, ?int $adminId): int
    {
        return (int) DB::table('asset_custody')->insertGetId($data + [
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'status' => 'assigned',
            'assigned_by' => $adminId,
        ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $id, int $tenantId): ?array
    {
        $row = DB::table('asset_custody')->where('id', $id)->where('tenant_id', $tenantId)->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public static function update(int $id, int $tenantId, array $data): void
    {
        DB::table('asset_custody')->where('id', $id)->where('tenant_id', $tenantId)->update($data);
    }

    public static function delete(int $id, int $tenantId): void
    {
        DB::table('asset_custody')->where('id', $id)->where('tenant_id', $tenantId)->delete();
    }

    /**
     * @return list<array<string, mixed>>
     */
    public static function forTenant(int $tenantId, ?string $status = null, ?int $employeeId = null): array
    {
        $rows = DB::table('asset_custody as ac')
            ->join('employees as e', 'e.id', '=', 'ac.employee_id')
            ->where('ac.tenant_id', $tenantId)
            ->when($status !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('ac.status', $status))
            ->when($employeeId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('ac.employee_id', $employeeId))
            ->orderByDesc('ac.created_at')
            ->get(['ac.*', 'e.name as employee_name'])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /** The employee saying they are handing it back. */
    public static function requestReturn(int $id, int $tenantId, ?string $note): bool
    {
        return DB::table('asset_custody')
            ->where('id', $id)->where('tenant_id', $tenantId)->where('status', 'assigned')
            ->update([
                'status' => 'return_requested',
                'return_requested_at' => DB::raw('NOW()'),
                'return_note' => $note,
                // A fresh request clears the last refusal: it is a new attempt,
                // not a continuation of the one that was turned down.
                'rejection_reason' => null,
            ]) > 0;
    }

    /**
     * Somebody with the item in front of them confirming it.
     *
     * Works from either state, because an administrator handed the laptop back
     * in person often enough that requiring the employee to raise a request
     * first would just mean nobody records it.
     */
    public static function approveReturn(int $id, int $tenantId, int $adminId): bool
    {
        return DB::table('asset_custody')
            ->where('id', $id)->where('tenant_id', $tenantId)
            ->whereIn('status', ['assigned', 'return_requested'])
            ->update([
                'status' => 'returned',
                'returned_at' => DB::raw('NOW()'),
                'return_approved_by' => $adminId,
                'rejection_reason' => null,
            ]) > 0;
    }

    /** Sends it back to assigned, with a reason the employee can read. */
    public static function rejectReturn(int $id, int $tenantId, int $adminId, ?string $reason): bool
    {
        return DB::table('asset_custody')
            ->where('id', $id)->where('tenant_id', $tenantId)->where('status', 'return_requested')
            ->update([
                'status' => 'assigned',
                'return_requested_at' => null,
                'rejection_reason' => $reason,
                'return_approved_by' => $adminId,
            ]) > 0;
    }

    /**
     * @return array<string, mixed>
     */
    private static function toArray(mixed $row): array
    {
        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }
}
