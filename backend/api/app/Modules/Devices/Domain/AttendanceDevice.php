<?php

declare(strict_types=1);

namespace App\Modules\Devices\Domain;

use App\Exceptions\ApiFailure;
use App\Support\Value;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * A fingerprint terminal on a customer's wall.
 *
 * A device row is either unclaimed — it has dialled in but no company has
 * entered its serial yet, and it carries no company data — or claimed by
 * exactly one company and bound to one branch. Claiming is first-come on the
 * serial, which is printed on the device itself: whoever is physically holding
 * it owns it.
 *
 * Every freshness comparison here is done in SQL. These timestamps are written
 * with the database's NOW() while PHP runs UTC, so comparing them in PHP would
 * be hours wrong and every device would look either permanently online or
 * permanently dark.
 */
final class AttendanceDevice
{
    /** A terminal polls every few seconds, so silence this long means trouble. */
    public const ONLINE_GRACE_SECONDS = 300;

    /** The columns a company may change from the settings screen. */
    private const WRITABLE = [
        'name', 'branch_id', 'status', 'direction_mode',
        'min_interval_seconds', 'clock_offset_minutes', 'keep_unmatched', 'debug_logging',
    ];

    public static function normaliseSerial(mixed $raw): string
    {
        return strtoupper(trim(Value::string($raw)));
    }

    /**
     * Marks a terminal as seen, creating its row on first contact.
     *
     * A serial nobody has claimed still gets a row: that is how a device
     * appears in the "unclaimed" list for somebody to attach to a company. It
     * can do nothing else until then, which is the whole authorisation model —
     * the firmware has nowhere to put a credential.
     *
     * @return array<string, mixed>
     */
    public static function recordContact(string $serial, ?string $ip): array
    {
        DB::insert(
            "INSERT INTO attendance_devices (serial_number, status, first_seen_at, last_seen_at, last_ip)
             VALUES (?, 'unclaimed', NOW(), NOW(), ?)
             ON DUPLICATE KEY UPDATE last_seen_at = NOW(), last_ip = VALUES(last_ip)",
            [$serial, $ip],
        );

        $device = self::findBySerial($serial);

        if ($device === null) {
            throw new RuntimeException('Device row vanished for serial '.$serial);
        }

        return $device;
    }

    /**
     * Stores whatever the device volunteered about itself.
     *
     * Only non-empty values: a handshake that omits the firmware version must
     * not erase the one we already knew.
     *
     * @param  array<string, mixed>  $info
     */
    public static function updateInfo(int $deviceId, array $info): void
    {
        $fields = [];

        foreach (['model', 'firmware', 'user_count'] as $column) {
            $value = $info[$column] ?? null;

            if ($value !== null && $value !== '') {
                $fields[$column] = $value;
            }
        }

        if ($fields === []) {
            return;
        }

        DB::table('attendance_devices')->where('id', $deviceId)->update($fields);
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function findBySerial(string $serial): ?array
    {
        $row = DB::table('attendance_devices')->where('serial_number', self::normaliseSerial($serial))->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $id, int $tenantId): ?array
    {
        $row = DB::table('attendance_devices')->where('id', $id)->where('tenant_id', $tenantId)->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * Binds an unclaimed device to a company and a branch.
     *
     * A device already owned by another company is refused rather than moved:
     * silently taking it would hand that company's punch stream to a stranger.
     *
     * @return array<string, mixed>
     */
    public static function claim(string $serial, int $tenantId, int $branchId, ?string $name, ?int $adminId): array
    {
        $serial = self::normaliseSerial($serial);
        $existing = self::findBySerial($serial);

        if ($existing !== null) {
            $owner = Value::nullableInt($existing['tenant_id'] ?? null);

            if ($owner !== null && $owner !== $tenantId) {
                throw new ApiFailure(
                    __('messages.device_registered_elsewhere'),
                    409,
                    'DEVICE_ALREADY_CLAIMED',
                );
            }

            $changes = [
                'tenant_id' => $tenantId,
                'branch_id' => $branchId,
                'status' => 'active',
                'claimed_by' => $adminId,
                'claimed_at' => DB::raw('NOW()'),
            ];

            // Re-claiming without naming it keeps whatever it is already
            // called, rather than blanking a label somebody chose.
            if ($name !== null) {
                $changes['name'] = $name;
            }

            DB::table('attendance_devices')->where('id', Value::int($existing['id'] ?? null))->update($changes);
        } else {
            // Registered before the terminal ever dialled in — HR usually types
            // the serial off the box while the electrician is still mounting
            // it — so the row is created ready and waiting.
            DB::table('attendance_devices')->insert([
                'tenant_id' => $tenantId,
                'branch_id' => $branchId,
                'serial_number' => $serial,
                'name' => $name,
                'status' => 'active',
                'claimed_by' => $adminId,
                'claimed_at' => DB::raw('NOW()'),
            ]);
        }

        $device = self::findBySerial($serial);

        if ($device === null) {
            throw new RuntimeException('Device row vanished for serial '.$serial);
        }

        return $device;
    }

    /**
     * The stand-in device a file import hangs off.
     *
     * A punch has to belong to a device row — that is what carries the branch,
     * the clock offset and the repeat-tap window. A company importing a file
     * usually has no registered terminal at all, which is why they are
     * importing a file, so one is synthesised per branch.
     *
     * The serial is namespaced and unclaimable: registration only accepts
     * [A-Z0-9-]{4,64}, so a real terminal can never collide with it.
     *
     * @return array<string, mixed>
     */
    public static function ensureFileImportDevice(int $tenantId, int $branchId, ?int $adminId): array
    {
        $serial = self::normaliseSerial("FILE-T{$tenantId}-B{$branchId}");
        $existing = self::findBySerial($serial);

        if ($existing !== null) {
            return $existing;
        }

        DB::table('attendance_devices')->insertOrIgnore([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'serial_number' => $serial,
            'name' => 'استيراد ملف',
            'vendor' => 'other',
            'status' => 'active',
            'claimed_by' => $adminId,
            'claimed_at' => DB::raw('NOW()'),
            'first_seen_at' => DB::raw('NOW()'),
        ]);

        $device = self::findBySerial($serial);

        if ($device === null) {
            throw new RuntimeException('Could not create the file-import device for branch '.$branchId);
        }

        return $device;
    }

    /**
     * Everything the fleet screen needs to answer "is it working?".
     *
     * @return list<array<string, mixed>>
     */
    public static function listForTenant(int $tenantId): array
    {
        $rows = DB::table('attendance_devices as d')
            ->leftJoin('branches as b', function (JoinClause $join): void {
                $join->on('b.id', '=', 'd.branch_id')->on('b.tenant_id', '=', 'd.tenant_id');
            })
            ->where('d.tenant_id', $tenantId)
            ->orderByDesc('d.id')
            ->get([
                'd.*', 'b.name as branch_name',
                DB::raw('TIMESTAMPDIFF(SECOND, d.last_seen_at, NOW()) AS seconds_since_seen'),
                DB::raw('(SELECT COUNT(*) FROM device_users du WHERE du.device_id = d.id AND du.employee_id IS NOT NULL) AS linked_users'),
                DB::raw('(SELECT COUNT(*) FROM device_users du WHERE du.device_id = d.id AND du.employee_id IS NULL) AS pending_users'),
                DB::raw('(SELECT COUNT(*) FROM device_punches p WHERE p.device_id = d.id AND DATE(p.punched_at) = CURDATE()) AS punches_today'),
            ])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * @param  array<string, mixed>  $fields
     */
    public static function update(int $deviceId, int $tenantId, array $fields): void
    {
        $writable = array_intersect_key($fields, array_flip(self::WRITABLE));

        if ($writable === []) {
            return;
        }

        DB::table('attendance_devices')->where('id', $deviceId)->where('tenant_id', $tenantId)->update($writable);
    }

    /**
     * Releases a device back to unclaimed.
     *
     * The attendance already recorded stays: those hours were worked, and they
     * belong to the company rather than to the hardware. What goes is the link
     * — the user mapping and any queued commands — so the terminal can be moved
     * or sold on without carrying somebody else's people with it.
     */
    public static function release(int $deviceId, int $tenantId): void
    {
        DB::transaction(function () use ($deviceId, $tenantId): void {
            DB::table('attendance_devices')->where('id', $deviceId)->where('tenant_id', $tenantId)->update([
                'tenant_id' => null,
                'branch_id' => null,
                'status' => 'unclaimed',
                'claimed_by' => null,
                'claimed_at' => null,
                'name' => null,
            ]);

            DB::table('device_users')->where('device_id', $deviceId)->where('tenant_id', $tenantId)->delete();
            DB::table('device_commands')->where('device_id', $deviceId)->where('tenant_id', $tenantId)->delete();
        });
    }

    public static function touchPunch(int $deviceId, string $punchedAt): void
    {
        DB::update(
            'UPDATE attendance_devices SET last_punch_at = GREATEST(COALESCE(last_punch_at, ?), ?) WHERE id = ?',
            [$punchedAt, $punchedAt, $deviceId],
        );
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
