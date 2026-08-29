<?php

declare(strict_types=1);

namespace App\Models;

use App\Domain\Attendance\Geofence;
use App\Support\Value;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

/**
 * @property int $id
 * @property int $tenant_id
 * @property string $name
 * @property float|null $latitude
 * @property float|null $longitude
 * @property string|null $qr_code
 * @property int|null $gps_radius_meters
 * @property bool $rotating_qr_enabled
 * @property string|null $wifi_mode
 */
final class Branch extends Model
{
    protected $table = 'branches';

    protected $guarded = [];

    /**
     * The QR value is the branch's shared secret on the printed-code path, so it
     * never goes out in a list response.
     *
     * @var list<string>
     */
    protected $hidden = ['qr_code', 'station_admin_pin_hash'];

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'latitude' => 'float',
            'longitude' => 'float',
            'rotating_qr_enabled' => 'boolean',
            'is_active' => 'boolean',
        ];
    }

    /**
     * @param  Builder<self>  $query
     * @return Builder<self>
     */
    public function scopeForTenant(Builder $query, int $tenantId): Builder
    {
        return $query->where('tenant_id', $tenantId);
    }

    /** The fence this branch enforces, falling back to the shared default. */
    public function radiusMetres(): int
    {
        $radius = Value::int($this->gps_radius_meters);

        return $radius > 0 ? $radius : Geofence::DEFAULT_RADIUS_METRES;
    }

    /** A branch with no coordinates cannot enforce a geofence at all. */
    public function hasLocation(): bool
    {
        return $this->latitude !== null && $this->longitude !== null;
    }

    /**
     * The centre a check-in is measured against.
     *
     * $allowCompanyFallback is false on the punch path on purpose. A branch with
     * no centre of its own must not borrow the company's: with several branches
     * that would let somebody check into the Jeddah branch while standing at
     * head office. The fallback exists only for display contexts that opt in.
     *
     * @return array{lat: float|null, lng: float|null, radius: int}
     */
    public function effectiveGeofence(bool $allowCompanyFallback = true): array
    {
        if ($this->hasLocation() && ! ((float) $this->latitude === 0.0 && (float) $this->longitude === 0.0)) {
            return [
                'lat' => (float) $this->latitude,
                'lng' => (float) $this->longitude,
                'radius' => $this->radiusMetres(),
            ];
        }

        if (! $allowCompanyFallback) {
            return ['lat' => null, 'lng' => null, 'radius' => $this->radiusMetres()];
        }

        $tenant = DB::table('tenants')->where('id', $this->tenant_id)
            ->first(['latitude', 'longitude', 'gps_radius_meters']);

        $lat = $tenant === null ? null : Value::nullableFloat($tenant->latitude);
        $lng = $tenant === null ? null : Value::nullableFloat($tenant->longitude);

        return [
            'lat' => $lat === 0.0 ? null : $lat,
            'lng' => $lng === 0.0 ? null : $lng,
            'radius' => $this->radiusMetres(),
        ];
    }

    /** Whether this branch lets the app queue punches while offline. */
    public function allowsOffline(): bool
    {
        $branch = $this->getAttribute('allow_offline_attendance');

        if ($branch !== null) {
            return Value::int($branch) === 1;
        }

        return Value::int(
            DB::table('tenants')->where('id', $this->tenant_id)->value('allow_offline_attendance')
        ) === 1;
    }
}
