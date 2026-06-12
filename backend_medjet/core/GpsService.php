<?php

final class GpsService {
    private const EARTH_RADIUS_KM = 6371;
    private const DEFAULT_GPS_RADIUS = 100;

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

        // Resolve the geofence: branch center if set, else the company-wide
        // default. No center anywhere → nothing to validate against, so GPS
        // check-in is allowed from anywhere until a center is configured.
        $geo = BranchModel::effectiveGeofence($branchId, $tenantId);
        $branchLat = $geo['lat'];
        $branchLon = $geo['lng'];
        if ($branchLat === null || $branchLon === null || ($branchLat == 0.0 && $branchLon == 0.0)) {
            return ['valid' => true, 'distance' => null, 'allowed_radius' => null];
        }

        $allowedRadius = (int) ($geo['radius'] ?? self::DEFAULT_GPS_RADIUS);
        if ($allowedRadius <= 0) {
            $allowedRadius = self::DEFAULT_GPS_RADIUS;
        }
        $distance = self::distanceInMeters($userLat, $userLon, $branchLat, $branchLon);

        if ($distance > $allowedRadius) {
            return [
                'valid' => false,
                'message' => 'You are outside the branch area',
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
