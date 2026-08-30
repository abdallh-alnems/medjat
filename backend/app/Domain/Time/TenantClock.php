<?php

declare(strict_types=1);

namespace App\Domain\Time;

use App\Support\Value;
use Carbon\CarbonImmutable;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * "Now", in a company's own timezone.
 *
 * The server runs PHP in UTC while MySQL runs the server's zone, so a bare
 * date()/NOW() pair disagrees by hours. Attendance rows were stamped in UTC for
 * months because of exactly that. Every path — read and write — resolves the day
 * through here instead.
 *
 * The company's zone is authoritative, not the employee's handset: payroll is
 * computed against the company's working hours, so someone travelling abroad is
 * still measured against their employer's clock.
 *
 * Always a zone *name*, never a fixed offset. Egypt observes DST and the Gulf
 * does not, so an offset is right for half the year at best.
 */
final class TenantClock
{
    /** Used when a company has no timezone set, or an unparseable one. */
    public const FALLBACK = 'Africa/Cairo';

    /** @var array<int, DateTimeZone> resolved zones, per request */
    private static array $zones = [];

    public static function zone(int $tenantId): DateTimeZone
    {
        if (isset(self::$zones[$tenantId])) {
            return self::$zones[$tenantId];
        }

        $name = Value::string(DB::table('tenants')->where('id', $tenantId)->value('timezone'));

        try {
            $zone = new DateTimeZone($name !== '' ? $name : self::FALLBACK);
        } catch (Throwable) {
            // Company settings validate the identifier before storing it, but a
            // hand-edited row must not be able to break check-in.
            Log::warning('Invalid tenant timezone, falling back', ['tenant_id' => $tenantId, 'timezone' => $name]);
            $zone = new DateTimeZone(self::FALLBACK);
        }

        return self::$zones[$tenantId] = $zone;
    }

    /**
     * Now, in the company's zone.
     *
     * Through Carbon rather than `new DateTimeImmutable`, so the clock can be
     * frozen. Everything in this system that is easy to get wrong is a function
     * of the time of day — whether a break window has closed, whether a shift
     * has started, whether a punch is inside its sanity range — and a clock
     * that cannot be fixed in place means those are tested against whatever
     * time the suite happens to run at. CarbonImmutable is a DateTimeImmutable,
     * so nothing downstream can tell the difference.
     */
    public static function now(int $tenantId): DateTimeImmutable
    {
        return CarbonImmutable::now(self::zone($tenantId));
    }

    /** Today's date (Y-m-d) as the company experiences it. */
    public static function date(int $tenantId): string
    {
        return self::now($tenantId)->format('Y-m-d');
    }

    /** The wall-clock time (H:i:s) as the company experiences it. */
    public static function time(int $tenantId): string
    {
        return self::now($tenantId)->format('H:i:s');
    }

    /** A full timestamp for writing to a DATETIME column. */
    public static function timestamp(int $tenantId): string
    {
        return self::now($tenantId)->format('Y-m-d H:i:s');
    }

    /** Only for tests: the per-request zone cache would otherwise leak between them. */
    public static function flush(): void
    {
        self::$zones = [];
    }
}
