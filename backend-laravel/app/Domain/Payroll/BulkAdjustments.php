<?php

declare(strict_types=1);

namespace App\Domain\Payroll;

use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * A bonus or deduction applied across a group, tracked as a batch.
 *
 * The batch is a handle, not a mechanism: it fans out into ordinary
 * per-employee rows, so everything downstream — the calculator, the payslips,
 * the audit trail — sees exactly what it would see from lines typed one at a
 * time. What the batch adds is the ability to edit or undo the whole thing
 * afterwards without hunting for the rows it created.
 *
 * Membership is a snapshot: somebody who joins the branch tomorrow is not
 * retroactively adjusted.
 */
final class BulkAdjustments
{
    public const KINDS = ['bonus', 'deduction'];

    public const SCOPES = ['all', 'branch', 'category', 'shift', 'employee'];

    public const AMOUNT_TYPES = ['fixed', 'percent'];

    public static function create(
        int $tenantId,
        string $kind,
        string $scopeType,
        ?int $scopeId,
        ?string $scopeName,
        float $amount,
        string $amountType,
        string $reason,
        int $createdBy,
        string $month,
    ): int {
        return (int) DB::table('bulk_adjustments')->insertGetId([
            'tenant_id' => $tenantId,
            'kind' => $kind,
            'scope_type' => $scopeType,
            'scope_id' => $scopeId,
            // Snapshot, so a batch still reads sensibly after the branch it
            // named has been renamed or removed.
            'scope_name' => $scopeName,
            'amount' => $amount,
            'amount_type' => $amountType,
            'reason' => $reason,
            'month' => $month,
            'created_by' => $createdBy,
        ]);
    }

    /**
     * Whether the same thing has already been done this month.
     *
     * Reported as a warning rather than refused: applying the same bonus twice
     * is occasionally deliberate, and the only person who knows is the one
     * pressing the button.
     */
    public static function existsSimilar(
        int $tenantId,
        string $kind,
        string $scopeType,
        ?int $scopeId,
        string $month,
    ): bool {
        return DB::table('bulk_adjustments')
            ->where('tenant_id', $tenantId)->where('kind', $kind)
            ->where('scope_type', $scopeType)->where('month', $month)
            ->when(
                $scopeId === null,
                fn (QueryBuilder $q): QueryBuilder => $q->whereNull('scope_id'),
                fn (QueryBuilder $q): QueryBuilder => $q->where('scope_id', $scopeId),
            )
            ->exists();
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $id, int $tenantId): ?array
    {
        $row = DB::table('bulk_adjustments')->where('id', $id)->where('tenant_id', $tenantId)->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public static function forTenant(int $tenantId): array
    {
        $rows = DB::table('bulk_adjustments as ba')
            ->leftJoin('admins as a', 'a.id', '=', 'ba.created_by')
            ->where('ba.tenant_id', $tenantId)
            ->orderByDesc('ba.created_at')
            ->get([
                'ba.*', 'a.name as created_by_name',
                DB::raw(
                    "CASE ba.kind WHEN 'bonus'"
                    .' THEN (SELECT COUNT(*) FROM manual_bonuses WHERE batch_id = ba.id)'
                    .' ELSE (SELECT COUNT(*) FROM manual_deductions WHERE batch_id = ba.id)'
                    .' END AS member_count'
                ),
                DB::raw(
                    "CASE ba.kind WHEN 'bonus'"
                    .' THEN (SELECT COALESCE(SUM(amount), 0) FROM manual_bonuses WHERE batch_id = ba.id)'
                    .' ELSE (SELECT COALESCE(SUM(amount), 0) FROM manual_deductions WHERE batch_id = ba.id)'
                    .' END AS total_amount'
                ),
            ])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * @return list<array<string, mixed>>
     */
    public static function members(int $batchId, string $kind, int $tenantId): array
    {
        $rows = DB::table(self::table($kind).' as m')
            ->join('employees as e', 'e.id', '=', 'm.employee_id')
            ->where('m.batch_id', $batchId)->where('m.tenant_id', $tenantId)
            ->orderBy('e.name')
            ->get([
                'm.id', 'm.employee_id', 'm.amount', 'm.reason',
                'e.name as employee_name', 'e.base_salary', 'e.admin_id',
            ])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    public static function updateMemberAmount(int $rowId, string $kind, int $tenantId, float $amount, string $reason): void
    {
        DB::table(self::table($kind))->where('id', $rowId)->where('tenant_id', $tenantId)
            ->update(['amount' => $amount, 'reason' => $reason]);
    }

    public static function removeMember(int $rowId, int $batchId, string $kind, int $tenantId): bool
    {
        return DB::table(self::table($kind))
            ->where('id', $rowId)->where('batch_id', $batchId)->where('tenant_id', $tenantId)
            ->delete() > 0;
    }

    public static function updateMeta(int $id, int $tenantId, float $amount, string $amountType, string $reason): void
    {
        DB::table('bulk_adjustments')->where('id', $id)->where('tenant_id', $tenantId)->update([
            'amount' => $amount,
            'amount_type' => $amountType,
            'reason' => $reason,
        ]);
    }

    /** The batch and every row it created, together. */
    public static function deleteBatch(int $id, string $kind, int $tenantId): void
    {
        DB::transaction(function () use ($id, $kind, $tenantId): void {
            DB::table(self::table($kind))->where('batch_id', $id)->where('tenant_id', $tenantId)->delete();
            DB::table('bulk_adjustments')->where('id', $id)->where('tenant_id', $tenantId)->delete();
        });
    }

    /** The percentage basis, written into each line so the trail explains itself. */
    public static function percentNote(float $percentage): string
    {
        return ' ('.rtrim(rtrim(number_format($percentage, 2, '.', ''), '0'), '.').'% من الأساسي)';
    }

    private static function table(string $kind): string
    {
        return $kind === 'bonus' ? 'manual_bonuses' : 'manual_deductions';
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
