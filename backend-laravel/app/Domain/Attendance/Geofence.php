<?php

declare(strict_types=1);

namespace App\Domain\Attendance;

/**
 * Distance between two points, and whether one is inside a branch's fence.
 *
 * Haversine on a spherical earth: accurate to well under a metre at the
 * hundred-metre scale a geofence works at, which is far finer than consumer GPS
 * itself, so a more elaborate model would only add precision the input does not
 * have.
 */
final class Geofence
{
    private const EARTH_RADIUS_METRES = 6_371_000;

    /**
     * The fence used when a branch sets none.
     *
     * Public because callers that *report* the effective radius — the browser
     * attendance page draws the circle — must use the number this class
     * enforces rather than each copying a literal that silently diverges.
     */
    public const DEFAULT_RADIUS_METRES = 100;

    public static function metresBetween(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon / 2) ** 2;

        return self::EARTH_RADIUS_METRES * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }

    public static function contains(
        float $latitude,
        float $longitude,
        float $branchLatitude,
        float $branchLongitude,
        float $radiusMetres,
    ): bool {
        return self::metresBetween($latitude, $longitude, $branchLatitude, $branchLongitude) <= $radiusMetres;
    }
}
