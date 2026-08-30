<?php

declare(strict_types=1);

namespace App\Modules\Settlements\Domain;

use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * The end-of-service settlement — تسوية نهاية الخدمة.
 *
 * One per employee. It starts as a draft HR can edit line by line, and
 * approving it freezes the figures and ends the employment. What is stored is
 * always internally consistent because the three totals are recomputed here
 * from the parts on every write; a client that sent a net that disagreed with
 * its own lines would be recording a number nobody could reconstruct later.
 */
final class Settlement
{
    public const REASONS = [
        'resignation', 'termination', 'end_of_contract',
        'retirement', 'death', 'absconding', 'other',
    ];

    /** Figures HR may override before approval. */
    public const FIGURES = [
        'base_salary', 'daily_rate', 'years_of_service',
        'pending_salary', 'gratuity_days', 'gratuity_amount',
        'leave_balance_days', 'leave_encashment', 'other_additions',
        'outstanding_loans', 'other_deductions',
    ];

    /**
     * @return array<string, mixed>|null
     */
    public static function forEmployee(int $employeeId, int $tenantId): ?array
    {
        $row = DB::table('employee_settlements as s')
            ->leftJoin('admins as c', 'c.id', '=', 's.created_by')
            ->leftJoin('admins as a', 'a.id', '=', 's.approved_by')
            ->where('s.employee_id', $employeeId)->where('s.tenant_id', $tenantId)
            ->first(['s.*', 'c.name as created_by_name', 'a.name as approved_by_name']);

        return self::decode($row);
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $id, int $tenantId): ?array
    {
        $row = DB::table('employee_settlements')->where('id', $id)->where('tenant_id', $tenantId)->first();

        return self::decode($row);
    }

    /**
     * Removes an employee's settlement outright.
     *
     * Used when re-hiring somebody: without it their next end-of-service would
     * be blocked forever by the approved record from the last one.
     */
    public static function deleteForEmployee(int $employeeId, int $tenantId): void
    {
        DB::table('employee_settlements')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->delete();
    }

    /**
     * Writes the draft, recomputing the totals from the parts.
     *
     * @param  array<string, mixed>  $data
     */
    public static function save(int $tenantId, int $employeeId, array $data, int $adminId): int
    {
        $lineItems = self::sanitiseLineItems($data['line_items'] ?? null);
        [$earnings, $deductions, $net] = self::totals($data, $lineItems);

        $reason = Value::string($data['reason'] ?? null);

        $fields = [
            'reason' => in_array($reason, self::REASONS, true) ? $reason : 'resignation',
            'notes' => Value::nullableString($data['notes'] ?? null),
            'last_working_day' => Value::string($data['last_working_day'] ?? null),
            'hire_date' => Value::nullableString($data['hire_date'] ?? null),
            'total_earnings' => $earnings,
            'total_deductions' => $deductions,
            'net_amount' => $net,
            'line_items' => json_encode($lineItems, JSON_UNESCAPED_UNICODE),
        ];

        foreach (self::FIGURES as $figure) {
            $fields[$figure] = Value::float($data[$figure] ?? null);
        }

        $existing = Value::nullableInt(
            DB::table('employee_settlements')
                ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
                ->value('id')
        );

        if ($existing !== null) {
            DB::table('employee_settlements')
                ->where('id', $existing)->where('tenant_id', $tenantId)
                ->update($fields);

            return $existing;
        }

        return (int) DB::table('employee_settlements')->insertGetId($fields + [
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'created_by' => $adminId,
        ]);
    }

    /**
     * Freezes the figures and stamps the approver.
     *
     * The status guard is inside the UPDATE, so two people pressing approve at
     * the same moment cannot both succeed and terminate the employee twice.
     *
     * @param  array<string, mixed>  $snapshot
     */
    public static function approve(int $id, int $tenantId, int $adminId, array $snapshot): bool
    {
        return DB::table('employee_settlements')
            ->where('id', $id)->where('tenant_id', $tenantId)->where('status', 'draft')
            ->update([
                'status' => 'approved',
                'approved_by' => $adminId,
                'approved_at' => DB::raw('NOW()'),
                'breakdown' => json_encode($snapshot, JSON_UNESCAPED_UNICODE),
            ]) > 0;
    }

    public static function markPaid(int $id, int $tenantId): bool
    {
        return DB::table('employee_settlements')
            ->where('id', $id)->where('tenant_id', $tenantId)->where('status', 'approved')
            ->update(['status' => 'paid', 'paid_at' => DB::raw('NOW()')]) > 0;
    }

    /**
     * @param  array<string, mixed>  $data
     * @param  list<array{label: string, kind: string, amount: float}>  $lineItems
     * @return array{0: float, 1: float, 2: float}
     */
    public static function totals(array $data, array $lineItems): array
    {
        $earnings = Value::float($data['pending_salary'] ?? null)
            + Value::float($data['gratuity_amount'] ?? null)
            + Value::float($data['leave_encashment'] ?? null)
            + Value::float($data['other_additions'] ?? null);

        $deductions = Value::float($data['outstanding_loans'] ?? null)
            + Value::float($data['other_deductions'] ?? null);

        foreach ($lineItems as $item) {
            if ($item['kind'] === 'deduction') {
                $deductions += $item['amount'];
            } else {
                $earnings += $item['amount'];
            }
        }

        return [round($earnings, 2), round($deductions, 2), round($earnings - $deductions, 2)];
    }

    /**
     * Keeps only well-formed custom rows.
     *
     * A line with no label is dropped rather than stored blank: the settlement
     * is handed to somebody as the account of what they are owed, and an
     * unexplained figure on it is the one that gets disputed.
     *
     * @return list<array{label: string, kind: string, amount: float}>
     */
    public static function sanitiseLineItems(mixed $raw): array
    {
        if (! is_array($raw)) {
            return [];
        }

        $clean = [];

        foreach ($raw as $item) {
            if (! is_array($item)) {
                continue;
            }

            $label = trim(Value::string($item['label'] ?? null));

            if ($label === '') {
                continue;
            }

            $clean[] = [
                'label' => $label,
                'kind' => Value::string($item['kind'] ?? null) === 'deduction' ? 'deduction' : 'earning',
                'amount' => round(Value::float($item['amount'] ?? null), 2),
            ];
        }

        return $clean;
    }

    /**
     * @return array<string, mixed>|null
     */
    private static function decode(mixed $row): ?array
    {
        if ($row === null) {
            return null;
        }

        /** @var array<string, mixed> $settlement */
        $settlement = (array) $row;

        $settlement['line_items'] = self::sanitiseLineItems(
            json_decode(Value::string($settlement['line_items'] ?? null), true)
        );

        $breakdown = Value::string($settlement['breakdown'] ?? null);
        $settlement['breakdown'] = $breakdown === '' ? null : json_decode($breakdown, true);

        return $settlement;
    }
}
