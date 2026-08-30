<?php

declare(strict_types=1);

namespace App\Modules\Branches\Domain;

use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * A company's sites, and the attendance settings each one may override.
 *
 * Most settings here are three-valued: a branch may say yes, say no, or say
 * nothing and inherit the company's answer. That is why they are nullable
 * rather than defaulted — a warehouse and a head office rarely want the same
 * strictness, but neither wants to restate every setting the company already
 * decided.
 */
final class Branches
{
    /** The columns a company may change from the branch form. */
    private const WRITABLE = ['name', 'address', 'latitude', 'longitude', 'gps_radius_meters', 'cycle_start_day'];

    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $id, int $tenantId): ?array
    {
        $row = DB::table('branches')->where('id', $id)->where('tenant_id', $tenantId)->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * The list, with how many people each branch holds.
     *
     * Terminated staff are excluded: a branch's headcount is who works there
     * now, not who ever did.
     *
     * @return list<array<string, mixed>>
     */
    public static function forTenant(int $tenantId): array
    {
        $rows = DB::table('branches as b')
            ->where('b.tenant_id', $tenantId)
            ->orderBy('b.name')
            ->get([
                'b.*',
                DB::raw(
                    '(SELECT COUNT(*) FROM employees e'
                    ." WHERE e.branch_id = b.id AND e.tenant_id = b.tenant_id AND e.status != 'terminated')"
                    .' AS employee_count'
                ),
            ])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public static function create(int $tenantId, array $data): int
    {
        return (int) DB::table('branches')->insertGetId([
            'tenant_id' => $tenantId,
            'name' => $data['name'] ?? null,
            'address' => $data['address'] ?? null,
            'latitude' => $data['latitude'] ?? 0,
            'longitude' => $data['longitude'] ?? 0,
            // Generated up front so a poster can be printed the moment the
            // branch exists, rather than after somebody remembers to ask.
            'qr_code' => self::generateQrCode(),
        ]);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public static function update(int $id, int $tenantId, array $data): void
    {
        $writable = array_intersect_key($data, array_flip(self::WRITABLE));

        if ($writable === []) {
            return;
        }

        DB::table('branches')->where('id', $id)->where('tenant_id', $tenantId)->update($writable);
    }

    /**
     * The branch's QR payload, generating one if it has none.
     */
    public static function ensureQrCode(int $id, int $tenantId, bool $force = false): ?string
    {
        $branch = self::find($id, $tenantId);

        if ($branch === null) {
            return null;
        }

        $existing = Value::string($branch['qr_code'] ?? null);

        if (! $force && $existing !== '') {
            return $existing;
        }

        $code = self::generateQrCode();

        DB::table('branches')->where('id', $id)->where('tenant_id', $tenantId)->update(['qr_code' => $code]);

        return $code;
    }

    /**
     * @param  list<string>|null  $methods  Null means inherit the company's.
     */
    public static function updateAttendanceMethods(
        int $id,
        int $tenantId,
        ?array $methods,
        int $gpsRadiusMeters,
        ?bool $allowOffline,
    ): void {
        $changes = [
            'attendance_methods' => $methods === null ? null : json_encode($methods),
            'gps_radius_meters' => $gpsRadiusMeters,
        ];

        // Absent rather than null: null here means "inherit", and writing it
        // would erase a branch's explicit choice instead of leaving it alone.
        if ($allowOffline !== null) {
            $changes['allow_offline_attendance'] = $allowOffline ? 1 : 0;
        }

        DB::table('branches')->where('id', $id)->where('tenant_id', $tenantId)->update($changes);
    }

    public static function updateFaceSettings(int $id, int $tenantId, ?float $threshold, ?bool $livenessRequired): void
    {
        DB::table('branches')->where('id', $id)->where('tenant_id', $tenantId)->update([
            'face_match_threshold' => $threshold,
            'face_liveness_required' => $livenessRequired === null ? null : ($livenessRequired ? 1 : 0),
        ]);
    }

    public static function updateRotatingQr(int $id, int $tenantId, bool $enabled): void
    {
        DB::table('branches')->where('id', $id)->where('tenant_id', $tenantId)
            ->update(['rotating_qr_enabled' => $enabled ? 1 : 0]);
    }

    public static function updateWifiSettings(int $id, int $tenantId, ?string $mode, string $match): void
    {
        DB::table('branches')->where('id', $id)->where('tenant_id', $tenantId)
            ->update(['wifi_mode' => $mode, 'wifi_match' => $match]);
    }

    private static function generateQrCode(): string
    {
        return 'MED-'.strtoupper(bin2hex(random_bytes(8)));
    }

    /**
     * @return array<string, mixed>
     */
    private static function toArray(mixed $row): array
    {
        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }
}
