<?php

declare(strict_types=1);

namespace App\Services\Cron;

use App\Domain\Attendance\AbsenceBackfill;
use App\Domain\Time\TenantClock;
use App\Support\Value;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Port of api/app/cron/catchup_absences.php.
 *
 * The safety net under the dashboard's own catch-up. Absences already
 * self-heal whenever somebody opens the app; this is the fallback for stretches
 * with no traffic — a company that closes for a week comes back to a complete
 * record rather than a gap.
 *
 * Idempotent: the attendance table's unique key on (employee_id, date) means a
 * second run writes nothing.
 */
final class CatchUpAbsences
{
    /**
     * How far back a single run will reach.
     *
     * Bounded so a company that has been quiet for a year does not turn one
     * cron invocation into a year of backfill; the next run continues.
     */
    private const MAX_BACKFILL_DAYS = 14;

    /**
     * @return array{status: string, totals: array{days: int, marked: int}, by_tenant: array<int, array<string, mixed>>}
     */
    public function execute(): array
    {
        $report = [];
        $totals = ['days' => 0, 'marked' => 0];

        foreach (DB::table('tenants')->where('is_active', 1)->pluck('id') as $id) {
            $tenantId = Value::int($id);

            try {
                $result = $this->forTenant($tenantId);
            } catch (Throwable $e) {
                // One company's failure must not stop the rest of the run.
                Log::warning('Absence catch-up failed', ['tenant_id' => $tenantId, 'exception' => $e]);
                $report[$tenantId] = ['error' => $e->getMessage()];

                continue;
            }

            $report[$tenantId] = $result;
            $totals['days'] += $result['days'];
            $totals['marked'] += $result['marked'];
        }

        return ['status' => 'success', 'totals' => $totals, 'by_tenant' => $report];
    }

    /**
     * @return array{days: int, marked: int}
     */
    private function forTenant(int $tenantId): array
    {
        // The company's own clock. A day is only "complete" in the timezone the
        // people worked in, and this runs once for companies in several.
        $now = TenantClock::now($tenantId);
        $days = 0;
        $marked = 0;

        // Completed days first. Each is finished everywhere, so every remaining
        // no-show on it can be settled.
        for ($back = self::MAX_BACKFILL_DAYS; $back >= 1; $back--) {
            $date = $now->modify("-{$back} days")->format('Y-m-d');
            $marked += AbsenceBackfill::run($tenantId, $date);
            $days++;
        }

        // Today, restricted to shifts that have already ended — somebody on a
        // late shift has not failed to arrive yet.
        $marked += AbsenceBackfill::run($tenantId, $now->format('Y-m-d'), $now->format('H:i:s'));

        return ['days' => $days, 'marked' => $marked];
    }
}
