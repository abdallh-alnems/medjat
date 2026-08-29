<?php

declare(strict_types=1);

namespace App\Domain\Payroll;

use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * Per-month corrections to computed pay lines.
 *
 * Computed lines have no identity of their own — they are derived fresh on
 * every read, so there is no row id to attach a correction to. A line is
 * identified by a hash of what makes it that line: its kind, its date, and the
 * text shown on the payslip.
 *
 * That has a consequence worth stating: change the attendance a line came from
 * and the hash changes with it, so the correction stops applying. This is
 * intentional. A waiver granted against "غياب يوم 2026-08-04" should not
 * silently carry over to a different line that happens to occupy the same slot.
 *
 * Manual lines are never overridden here — they are rows the company already
 * owns and can edit directly.
 */
final class PayLineOverrides
{
    public static function hash(string $type, ?string $date, string $description): string
    {
        return sha1($type.'|'.($date ?? '').'|'.$description);
    }

    /**
     * @return array<string, array{waived: bool, amount: float|null}> Keyed "kind|hash".
     */
    public static function forMonth(int $employeeId, string $month, int $tenantId): array
    {
        $map = [];

        $rows = DB::table('payroll_line_overrides')
            ->where('employee_id', $employeeId)
            ->where('month', $month)
            ->where('tenant_id', $tenantId)
            ->get(['line_kind', 'line_hash', 'waived', 'override_amount']);

        foreach ($rows as $row) {
            $map[Value::string($row->line_kind).'|'.Value::string($row->line_hash)] = [
                'waived' => Value::int($row->waived) === 1,
                'amount' => Value::nullableFloat($row->override_amount),
            ];
        }

        return $map;
    }

    /**
     * Record a correction, replacing any correction already on that line.
     *
     * A waiver stores no amount: the two are alternatives, and keeping a stale
     * figure beside `waived` invites a later reader to use it.
     */
    public static function save(
        int $tenantId,
        int $employeeId,
        string $month,
        string $kind,
        string $type,
        ?string $date,
        string $description,
        bool $waived,
        ?float $amount,
        ?string $reason,
        ?int $adminId,
    ): void {
        DB::table('payroll_line_overrides')->upsert(
            [[
                'tenant_id' => $tenantId,
                'employee_id' => $employeeId,
                'month' => $month,
                'line_kind' => $kind,
                'line_type' => $type,
                'line_date' => $date,
                'line_desc' => $description,
                'line_hash' => self::hash($type, $date, $description),
                'waived' => $waived ? 1 : 0,
                'override_amount' => $waived ? null : $amount,
                'reason' => $reason,
                'created_by' => $adminId,
            ]],
            ['tenant_id', 'employee_id', 'month', 'line_kind', 'line_hash'],
            ['waived', 'override_amount', 'reason', 'line_type', 'line_date', 'line_desc'],
        );
    }

    /** Drop a correction, restoring the computed line. */
    public static function clear(
        int $tenantId,
        int $employeeId,
        string $month,
        string $kind,
        string $type,
        ?string $date,
        string $description,
    ): void {
        DB::table('payroll_line_overrides')
            ->where('tenant_id', $tenantId)
            ->where('employee_id', $employeeId)
            ->where('month', $month)
            ->where('line_kind', $kind)
            ->where('line_hash', self::hash($type, $date, $description))
            ->delete();
    }

    /**
     * @param  list<array<string, mixed>>  $lines
     * @param  array<string, array{waived: bool, amount: float|null}>  $overrides
     * @return list<array<string, mixed>>
     */
    public static function apply(array $lines, string $kind, array $overrides): array
    {
        $out = [];

        foreach ($lines as $line) {
            if (($line['type'] ?? '') === 'manual') {
                $out[] = $line;

                continue;
            }

            $hash = self::hash(
                Value::string($line['type'] ?? null),
                Value::nullableString($line['date'] ?? null),
                Value::string($line['description'] ?? null),
            );

            $override = $overrides[$kind.'|'.$hash] ?? null;

            if ($override === null) {
                $out[] = $line;

                continue;
            }

            if ($override['waived']) {
                continue;
            }

            if ($override['amount'] !== null) {
                // The original is kept beside the new figure: a payslip that
                // shows a corrected line without showing what it was corrected
                // from invites the argument it is meant to settle.
                $line['original_amount'] = $line['amount'] ?? 0;
                $line['amount'] = round($override['amount'], 2);
                $line['overridden'] = true;
            }

            $out[] = $line;
        }

        return $out;
    }
}
