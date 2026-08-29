<?php

declare(strict_types=1);

namespace App\Domain\Employees;

use App\Support\Value;
use DateTimeImmutable;
use Illuminate\Support\Facades\DB;

/**
 * Credentials that are about to lapse, or already have.
 *
 * Expiry is what turns a legal employee into an illegal one without anybody
 * doing anything, so already-expired items are included by default: an expired
 * iqama is more urgent than one expiring next week, not less.
 *
 * One row per credential rather than per employee — somebody whose passport and
 * work permit both lapse needs chasing twice.
 */
final class ComplianceExpiry
{
    /**
     * Credential => [number column or null, expiry column].
     *
     * A contract and health insurance have no number of their own, so the number
     * is null rather than a blank string pretending there is one.
     *
     * @var array<string, array{string|null, string}>
     */
    private const CREDENTIALS = [
        'iqama' => ['iqama_number', 'iqama_expiry'],
        'passport' => ['passport_number', 'passport_expiry'],
        'work_permit' => ['work_permit_number', 'work_permit_expiry'],
        'contract' => [null, 'contract_end'],
        'health_insurance' => [null, 'health_insurance_expiry'],
    ];

    /**
     * @return list<array<string, mixed>>
     */
    public static function within(int $tenantId, int $daysAhead, ?int $branchId, bool $includeExpired): array
    {
        $query = DB::table('employees as e')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->where('e.tenant_id', $tenantId)
            ->where('e.status', '!=', 'terminated');

        if ($branchId !== null) {
            $query->where('e.branch_id', $branchId);
        }

        $columns = ['e.id', 'e.name', 'e.branch_id', 'b.name as branch_name'];
        foreach (self::CREDENTIALS as [$numberColumn, $expiryColumn]) {
            $columns[] = 'e.'.$expiryColumn;
            if ($numberColumn !== null) {
                $columns[] = 'e.'.$numberColumn;
            }
        }

        $today = new DateTimeImmutable('today');
        $results = [];

        foreach ($query->get($columns) as $employee) {
            foreach (self::CREDENTIALS as $credential => [$numberColumn, $expiryColumn]) {
                $expiry = Value::nullableString($employee->{$expiryColumn} ?? null);
                if ($expiry === null || $expiry === '') {
                    continue;
                }

                $expiresAt = DateTimeImmutable::createFromFormat('Y-m-d', $expiry);
                if ($expiresAt === false) {
                    continue;
                }

                // Signed: negative means it lapsed that many days ago.
                $daysLeft = (int) $today->diff($expiresAt)->format('%r%a');

                if ($daysLeft > $daysAhead) {
                    continue;
                }

                if ($daysLeft < 0 && ! $includeExpired) {
                    continue;
                }

                $results[] = [
                    'employee_id' => Value::int($employee->id),
                    'employee_name' => $employee->name,
                    'branch_id' => Value::nullableInt($employee->branch_id),
                    'branch_name' => $employee->branch_name,
                    'credential' => $credential,
                    'number' => $numberColumn === null ? null : ($employee->{$numberColumn} ?? null),
                    'expires_at' => $expiry,
                    'days_left' => $daysLeft,
                    'is_expired' => $daysLeft < 0,
                ];
            }
        }

        // Most urgent first, which is the most overdue rather than the soonest.
        usort($results, static fn (array $a, array $b): int => $a['days_left'] <=> $b['days_left']);

        return $results;
    }
}
