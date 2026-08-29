<?php

declare(strict_types=1);

namespace App\Models;

use App\Domain\Attendance\Geofence;
use App\Support\Value;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

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
}
