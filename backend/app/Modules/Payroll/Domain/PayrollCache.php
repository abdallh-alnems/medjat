<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Domain;

use Illuminate\Support\Facades\Cache;

/**
 * A short memory for the live payroll overview.
 *
 * The overview runs the calculator once per employee, so a company of two
 * hundred people is two hundred calculations per refresh — and the screen gets
 * refreshed a lot. Ninety seconds is long enough to absorb that and short
 * enough that nobody notices the staleness.
 *
 * Every mutating endpoint invalidates the company's entries, because a stale
 * "draft" badge on a slip somebody just paid is the one kind of staleness users
 * do notice.
 */
final class PayrollCache
{
    private const TTL_SECONDS = 90;

    /**
     * Entries are not deleted on invalidation, they are orphaned.
     *
     * Cache tags need a store that supports them and key enumeration needs one
     * that allows scanning; neither is guaranteed here. So every key carries
     * the company's current generation, and dropping that generation makes the
     * whole set unreachable in one write, whatever the store.
     */
    public static function key(int $tenantId, string $month, ?int $branchId, ?int $limit, int $offset): string
    {
        return sprintf(
            'payroll:live:%d:%s:%s:%s:%s:%d',
            $tenantId,
            self::generation($tenantId),
            $month,
            $branchId === null ? 'all' : "b{$branchId}",
            $limit === null ? 'full' : "l{$limit}",
            $offset,
        );
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function get(string $key): ?array
    {
        $cached = Cache::get($key);

        if (! is_array($cached)) {
            return null;
        }

        /** @var array<string, mixed> $payload */
        $payload = $cached;

        return $payload;
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    public static function put(string $key, array $payload): void
    {
        Cache::put($key, $payload, self::TTL_SECONDS);
    }

    public static function invalidate(int $tenantId): void
    {
        Cache::forget(self::generationKey($tenantId));
    }

    private static function generation(int $tenantId): string
    {
        $generation = Cache::get(self::generationKey($tenantId));

        if (is_string($generation)) {
            return $generation;
        }

        $generation = bin2hex(random_bytes(6));
        Cache::forever(self::generationKey($tenantId), $generation);

        return $generation;
    }

    private static function generationKey(int $tenantId): string
    {
        return "payroll:live:generation:{$tenantId}";
    }
}
