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
}
