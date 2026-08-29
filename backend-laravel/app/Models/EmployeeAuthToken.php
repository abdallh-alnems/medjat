<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\DB;

/**
 * An employee session. The plaintext token is shown to the client exactly once
 * and only its SHA-256 digest is stored, so a database leak yields no usable
 * sessions.
 *
 * @property int $id
 * @property int $tenant_id
 * @property int $employee_id
 * @property string $token_hash
 * @property string|null $device_id
 * @property string|null $platform
 * @property string|null $expires_at
 * @property string|null $revoked_at
 * @property string|null $last_used_at
 */
final class EmployeeAuthToken extends Model
{
    /**
     * The phone platforms. Kept apart from 'web' so that signing in on a phone
     * does not end an active browser session, and vice versa — the two channels
     * are independent sessions for the same person.
     *
     * @var list<string>
     */
    public const APP_PLATFORMS = ['android', 'ios'];

    protected $table = 'employee_auth_tokens';

    public $timestamps = false;

    protected $guarded = [];

    /** @return BelongsTo<Employee, $this> */
    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }

    public static function hash(string $plain): string
    {
        return hash('sha256', $plain);
    }

    /**
     * Usable sessions only: not revoked, and not past expiry.
     *
     * The expiry comparison is done by MySQL against its own clock on purpose.
     * PHP runs in UTC here while MySQL runs in the server's zone, so comparing
     * in PHP accepts sessions for hours after they should have ended — which is
     * exactly the shared-device hole the expiry exists to close. A NULL expiry
     * means "never expires", which is every token issued to a personal phone.
     *
     * @param  Builder<self>  $query
     * @return Builder<self>
     */
    public function scopeActive(Builder $query): Builder
    {
        return $query
            ->whereNull('revoked_at')
            ->where(function (Builder $q): void {
                $q->whereNull('expires_at')->orWhere('expires_at', '>', DB::raw('NOW()'));
            });
    }

    public static function findActiveByPlain(string $plain): ?self
    {
        /** @var self|null $token */
        $token = self::query()->active()->where('token_hash', self::hash($plain))->first();

        if ($token !== null) {
            // Touched through the query builder rather than the model so the
            // write uses the database clock, for the same reason as the expiry
            // comparison above.
            self::query()->whereKey($token->id)->update(['last_used_at' => DB::raw('NOW()')]);
        }

        return $token;
    }

    /**
     * Ends a session. Idempotent: an already-revoked row is left untouched so a
     * repeated logout keeps the original reason and timestamp.
     *
     * @return int Rows revoked.
     */
    public static function revokeByPlain(string $plain, string $reason): int
    {
        return self::query()
            ->where('token_hash', self::hash($plain))
            ->whereNull('revoked_at')
            ->update(['revoked_at' => DB::raw('NOW()'), 'revoke_reason' => $reason]);
    }

    /**
     * Revokes **every** matching live session, not the first one found. With a
     * phone channel and a browser channel in play, "the one active token" stopped
     * being a safe assumption, and a stray survivor is the kind of thing that
     * never fails visibly.
     *
     * @param  list<string>|null  $platforms  null = every platform.
     * @return int Rows revoked.
     */
    public static function revokeForEmployee(int $employeeId, string $reason, ?array $platforms = null): int
    {
        $query = self::query()
            ->where('employee_id', $employeeId)
            ->whereNull('revoked_at');

        if ($platforms !== null && $platforms !== []) {
            $query->whereIn('platform', $platforms);
        }

        return $query->update(['revoked_at' => DB::raw('NOW()'), 'revoke_reason' => $reason]);
    }

    /**
     * Issues a phone session and returns the plaintext token, which is the only
     * time it exists in readable form.
     */
    public static function issue(
        int $tenantId,
        int $employeeId,
        string $deviceId,
        ?string $deviceModel,
        string $platform,
        ?string $appVersion,
    ): string {
        self::revokeForEmployee($employeeId, 'reissued_on_login', self::APP_PLATFORMS);

        $plain = bin2hex(random_bytes(32));

        self::query()->create([
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'token_hash' => self::hash($plain),
            'device_id' => $deviceId,
            'device_model' => $deviceModel,
            'platform' => $platform,
            'app_version' => $appVersion,
        ]);

        return $plain;
    }

    /**
     * Issues a browser session: expiring, and one per employee.
     *
     * expires_at is computed in SQL. PHP runs UTC on the server while MySQL runs
     * the server's zone, so a PHP-computed expiry is born hours wrong — the
     * face-challenge table learned this the hard way.
     *
     * @return array{token: string, expires_at: string}
     */
    public static function issueWeb(int $tenantId, int $employeeId, string $deviceId, int $lifetimeSeconds): array
    {
        self::revokeForEmployee($employeeId, 'reissued_on_web_login', ['web']);

        $plain = bin2hex(random_bytes(32));
        $hash = self::hash($plain);

        // Raw insert rather than Eloquent::create so the lifetime is a bound
        // parameter inside the SQL expression instead of being interpolated
        // into it.
        DB::insert(
            'INSERT INTO employee_auth_tokens
                (tenant_id, employee_id, token_hash, device_id, platform, expires_at)
             VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))',
            [$tenantId, $employeeId, $hash, $deviceId, 'web', $lifetimeSeconds]
        );

        $expiresAt = self::query()->where('token_hash', $hash)->value('expires_at');

        return ['token' => $plain, 'expires_at' => is_scalar($expiresAt) ? (string) $expiresAt : ''];
    }
}
