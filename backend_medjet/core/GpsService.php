<?php

final class GpsService {
    private const EARTH_RADIUS_KM = 6371;

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

        $allowedRadius = (float) ($branch['gps_radius'] ?? 100);
        $distance = self::distanceInMeters(
            $userLat, $userLon,
            (float) $branch['latitude'], (float) $branch['longitude']
        );

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
