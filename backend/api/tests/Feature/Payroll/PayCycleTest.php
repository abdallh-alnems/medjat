<?php

declare(strict_types=1);

namespace Tests\Feature\Payroll;

use App\Modules\Payroll\Domain\PayCycle;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\CreatesFixtures;
use Tests\TestCase;

/**
 * Which dates a month's pay actually covers.
 */
final class PayCycleTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    private int $tenantId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->tenantId = $this->createTenant();
    }

    private function withStartDay(int $day): void
    {
        DB::table('tenants')->where('id', $this->tenantId)->update(['cycle_start_day' => $day]);
    }

    public function test_a_start_day_of_one_is_the_calendar_month(): void
    {
        $this->withStartDay(1);
        $cycle = PayCycle::resolve($this->tenantId, null, '2026-02');

        $this->assertSame('2026-02-01', $cycle->start);
        $this->assertSame('2026-02-28', $cycle->end);
        $this->assertSame(28, $cycle->days());
    }

    public function test_february_gets_its_real_length_in_a_leap_year(): void
    {
        $this->withStartDay(1);
        $this->assertSame('2028-02-29', PayCycle::resolve($this->tenantId, null, '2028-02')->end);
    }

    public function test_an_early_start_day_names_the_cycle_after_the_month_it_starts_in(): void
    {
        // Most of a cycle beginning on the 5th of March falls in March.
        $this->withStartDay(5);
        $cycle = PayCycle::resolve($this->tenantId, null, '2026-03');

        $this->assertSame('2026-03-05', $cycle->start);
        $this->assertSame('2026-04-04', $cycle->end);
    }

    public function test_a_late_start_day_names_the_cycle_after_the_month_it_ends_in(): void
    {
        // A cycle running 26 March to 25 April is "April's pay" to everybody
        // involved: that is when the work happened and when it is paid.
        $this->withStartDay(26);
        $cycle = PayCycle::resolve($this->tenantId, null, '2026-04');

        $this->assertSame('2026-03-26', $cycle->start);
        $this->assertSame('2026-04-25', $cycle->end);
    }

    public function test_a_start_day_past_the_end_of_february_is_clamped(): void
    {
        // The 30th does not exist in February, and a cycle that simply fails to
        // happen in some months is worse than one that starts two days early.
        $this->withStartDay(30);
        $cycle = PayCycle::resolve($this->tenantId, null, '2026-02');

        $this->assertSame(28, $cycle->startDay);
        $this->assertSame('2026-01-28', $cycle->start);
        $this->assertSame('2026-02-27', $cycle->end);
    }

    public function test_a_branch_setting_beats_the_company_default(): void
    {
        $this->withStartDay(1);
        $branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Cycle branch',
            'cycle_start_day' => 26,
        ]);

        $cycle = PayCycle::resolve($this->tenantId, $branchId, '2026-04');

        $this->assertSame('2026-03-26', $cycle->start);
    }

    public function test_a_finished_cycle_counts_in_full(): void
    {
        $this->withStartDay(1);
        $cycle = PayCycle::resolve($this->tenantId, null, '2026-02');

        $this->assertSame('2026-02-28', $cycle->effectiveEnd('2026-06-01'));
        $this->assertSame(28, $cycle->daysElapsed($cycle->effectiveEnd('2026-06-01')));
    }

    public function test_a_running_cycle_stops_at_today(): void
    {
        // Otherwise a mid-month figure charges somebody for absences on days
        // that have not happened yet.
        $this->withStartDay(1);
        $cycle = PayCycle::resolve($this->tenantId, null, '2026-02');

        $this->assertSame('2026-02-10', $cycle->effectiveEnd('2026-02-10'));
        $this->assertSame(10, $cycle->daysElapsed('2026-02-10'));
    }

    public function test_a_cycle_entirely_in_the_future_counts_nothing(): void
    {
        // Null, not "one day" — a cycle that has not started has no elapsed
        // days at all, and counting one would prorate a day of salary.
        $this->withStartDay(1);
        $cycle = PayCycle::resolve($this->tenantId, null, '2026-02');

        $this->assertNull($cycle->effectiveEnd('2026-01-15'));
        $this->assertSame(0, $cycle->daysElapsed(null));
    }
}
