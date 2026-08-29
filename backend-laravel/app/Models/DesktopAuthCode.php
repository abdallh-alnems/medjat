<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

/**
 * A two-minute, single-use code that carries a browser sign-in over to the
 * desktop shell.
 *
 * Only digests are stored. The browser holds the plaintext code and the desktop
 * app holds the plaintext state nonce it generated, so a code intercepted
 * without that nonce is useless.
 *
 * @property int $id
 * @property string $code_hash
 * @property string $state_hash
 * @property int $admin_id
 * @property string $firebase_uid
 * @property string|null $used_at
 * @property string $expires_at
 */
final class DesktopAuthCode extends Model
{
    /**
     * Deliberately short: the browser redirects to the app the instant it has
     * the code, so anything longer is only a window for someone else.
     */
    public const LIFETIME_SECONDS = 120;

    protected $table = 'desktop_auth_codes';

    public $timestamps = false;

    protected $guarded = [];

    /** @var list<string> */
    protected $hidden = ['code_hash', 'state_hash'];

    public static function hash(string $value): string
    {
        return hash('sha256', $value);
    }

    /**
     * Issues a code for an already-authenticated administrator and returns the
     * plaintext, which exists only in this response.
     *
     * Expiry is computed in SQL: PHP runs UTC while MySQL runs the server's
     * zone, and a PHP-computed expiry on a two-minute window is born dead.
     */
    public static function issue(int $adminId, string $firebaseUid, string $state): string
    {
        // This administrator's spent and expired codes are of no further use.
        self::query()
            ->where('admin_id', $adminId)
            ->where(fn ($query) => $query->whereNotNull('used_at')->orWhere('expires_at', '<=', DB::raw('NOW()')))
            ->delete();

        $code = bin2hex(random_bytes(32));

        DB::insert(
            'INSERT INTO desktop_auth_codes (code_hash, state_hash, admin_id, firebase_uid, expires_at)
             VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))',
            [self::hash($code), self::hash($state), $adminId, $firebaseUid, self::LIFETIME_SECONDS]
        );

        return $code;
    }

    public static function findUsable(string $plainCode): ?self
    {
        /** @var self|null */
        return self::query()
            ->where('code_hash', self::hash($plainCode))
            ->whereNull('used_at')
            ->where('expires_at', '>', DB::raw('NOW()'))
            ->first();
    }

    public function matchesState(string $plainState): bool
    {
        return hash_equals($this->state_hash, self::hash($plainState));
    }

    /**
     * Claims the code before anything is minted from it. The WHERE guard makes
     * two racing requests resolve to exactly one winner.
     */
    public function claim(): bool
    {
        return self::query()
            ->whereKey($this->id)
            ->whereNull('used_at')
            ->update(['used_at' => DB::raw('NOW()')]) === 1;
    }
}
