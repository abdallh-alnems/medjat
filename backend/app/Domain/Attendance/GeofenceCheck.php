<?php

declare(strict_types=1);

namespace App\Domain\Attendance;

use App\Models\Branch;

/**
 * The verdict on whether a punch came from inside a branch's fence.
 */
final readonly class GeofenceCheck
{
    private function __construct(
        public bool $passed,
        public string $message,
        public ?string $reason,
        public ?float $distanceMetres,
        public ?int $allowedRadiusMetres,
    ) {}

    public static function evaluate(Branch $branch, float $latitude, float $longitude): self
    {
        // A branch with no centre cannot verify that the employee is at that
        // branch, so the punch is refused rather than quietly allowed —
        // otherwise a QR code alone would pass with no location check at all.
        // The fix is for an administrator to set the branch location.
        if (! $branch->hasLocation() || ((float) $branch->latitude === 0.0 && (float) $branch->longitude === 0.0)) {
            return new self(
                passed: false,
                message: 'Branch location is not configured; GPS check-in cannot be verified',
                reason: 'GEOFENCE_NOT_CONFIGURED',
                distanceMetres: null,
                allowedRadiusMetres: null,
            );
        }

        $radius = $branch->radiusMetres();
        $distance = Geofence::metresBetween(
            $latitude,
            $longitude,
            (float) $branch->latitude,
            (float) $branch->longitude,
        );

        if ($distance > $radius) {
            return new self(
                passed: false,
                message: 'أنت خارج نطاق الفرع',
                reason: 'GPS_OUT_OF_RANGE',
                distanceMetres: $distance,
                allowedRadiusMetres: $radius,
            );
        }

        return new self(
            passed: true,
            message: '',
            reason: null,
            distanceMetres: $distance,
            allowedRadiusMetres: $radius,
        );
    }
}
