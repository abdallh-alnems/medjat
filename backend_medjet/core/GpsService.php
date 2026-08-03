<?php

final class GpsService {
    private const EARTH_RADIUS_KM = 6371;
    /**
     * Public so callers that need to *report* the effective radius (the browser
     * attendance page draws it) use the same number this service enforces,
     * rather than each copying a literal that would silently diverge.
     */
    public const DEFAULT_GPS_RADIUS = 100;

    public static function distanceBetween(
        float $lat1, float $lon1,
        float $lat2, float $lon2
    ): float {
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $a = sin($dLat / 2) * sin($dLat / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLon / 2) * sin($dLon / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return self::EARTH_RADIUS_KM * $c;
    }

    public static function distanceInMeters(
        float $lat1, float $lon1,
        float $lat2, float $lon2
    ): float {
        return self::distanceBetween($lat1, $lon1, $lat2, $lon2) * 1000;
    }

    public static function haversineMeters(
        float $lat1, float $lon1,
        float $lat2, float $lon2
    ): float {
        return self::distanceInMeters($lat1, $lon1, $lat2, $lon2);
    }

    public static function isWithinRange(
        float $userLat, float $userLon,
        float $branchLat, float $branchLon,
        float $allowedRadiusMeters
    ): bool {
        $distance = self::distanceInMeters($userLat, $userLon, $branchLat, $branchLon);
        return $distance <= $allowedRadiusMeters;
    }

    public static function validateCheckIn(
        float $userLat, float $userLon,
        int $branchId,
        int $tenantId
    ): array {
        $branch = BranchModel::findById($branchId, $tenantId);
        if (!$branch) {
            return ['valid' => false, 'message' => 'Branch not found'];
        }

        // Resolve THIS branch's own geofence (no company fallback). If the
        // branch has no center configured we cannot verify the employee is
        // actually at that branch, so the check-in must be rejected (never
        // silently allowed) — otherwise a QR code alone would pass without any
        // real location check. The admin must set the branch location first.
        $geo = BranchModel::effectiveGeofence($branchId, $tenantId, false);
        $branchLat = $geo['lat'];
        $branchLon = $geo['lng'];
        if ($branchLat === null || $branchLon === null || ($branchLat == 0.0 && $branchLon == 0.0)) {
            return [
                'valid' => false,
                'message' => 'Branch location is not configured; GPS check-in cannot be verified',
                'distance' => null,
                'allowed_radius' => null,
                'reason' => 'GEOFENCE_NOT_CONFIGURED',
            ];
        }

        $allowedRadius = (int) ($geo['radius'] ?? self::DEFAULT_GPS_RADIUS);
        if ($allowedRadius <= 0) {
            $allowedRadius = self::DEFAULT_GPS_RADIUS;
        }
        $distance = self::distanceInMeters($userLat, $userLon, $branchLat, $branchLon);

        if ($distance > $allowedRadius) {
            return [
                'valid' => false,
                // User-facing, so it goes through I18n — this text reaches an
                // Arabic-first audience and shipped in English until a browser
                // test put it on screen.
                'message' => I18n::t('gps_out_of_range'),
                'distance' => round($distance, 1),
                'allowed_radius' => $allowedRadius,
            ];
        }

        return [
            'valid' => true,
            'distance' => round($distance, 1),
            'allowed_radius' => $allowedRadius,
        ];
    }
}
