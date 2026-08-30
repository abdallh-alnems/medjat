<?php

declare(strict_types=1);

namespace App\Domain\SuperAdmin;

use App\Models\SuperAdmin;
use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * A support-desk sign-in.
 *
 * The token is stored hashed and returned once. It is not scoped to a company,
 * so anybody holding one can read every company's data — which is why it lives
 * for twelve hours rather than indefinitely, and why the expiry is compared by
 * the database's own clock.
 */
final class SuperAdminSession
{
    public const LIFETIME_HOURS = 12;

    /**
     * @return array{token: string, expires_at: string}
     */
    public static function open(int $adminId, string $ip, string $userAgent): array
    {
        $token = bin2hex(random_bytes(32));

        // Computed in SQL. PHP runs UTC while MySQL runs the server zone, and
        // the expiry is compared against the database's NOW() — a PHP-built
        // one is hours out, in whichever direction hurts.
        DB::insert(
            'INSERT INTO super_admin_sessions (admin_id, token_hash, expires_at, ip, user_agent)'
            .' VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR), ?, ?)',
            [$adminId, self::hash($token), self::LIFETIME_HOURS, $ip, mb_substr($userAgent, 0, 255)],
        );

        DB::table('super_admins')->where('id', $adminId)->update([
            'last_login_at' => DB::raw('NOW()'),
            'last_login_ip' => $ip,
        ]);

        return ['token' => $token, 'expires_at' => self::expiryOf($token)];
    }

    /**
     * The operator holding this token, or null.
     *
     * An expired session is deleted on sight rather than left to accumulate:
     * the table would otherwise keep a row per sign-in forever, and a stale
     * hash is exactly the thing worth not keeping.
     */
    public static function resolve(string $token): ?SuperAdmin
    {
        if ($token === '') {
            return null;
        }

        $hash = self::hash($token);

        $row = DB::table('super_admin_sessions as s')
            ->join('super_admins as a', 'a.id', '=', 's.admin_id')
            ->where('s.token_hash', $hash)
            ->first(['s.admin_id', 'a.is_active', DB::raw('s.expires_at < NOW() AS is_expired')]);

        if ($row === null) {
            return null;
        }

        if (Value::int($row->is_expired) === 1) {
            DB::table('super_admin_sessions')->where('token_hash', $hash)->delete();

            return null;
        }

        DB::table('super_admin_sessions')->where('token_hash', $hash)
            ->update(['last_used_at' => DB::raw('NOW()')]);

        return SuperAdmin::query()->find(Value::int($row->admin_id));
    }

    public static function close(string $token): void
    {
        DB::table('super_admin_sessions')->where('token_hash', self::hash($token))->delete();
    }

    public static function hash(string $token): string
    {
        return hash('sha256', $token);
    }

    private static function expiryOf(string $token): string
    {
        return Value::string(
            DB::table('super_admin_sessions')->where('token_hash', self::hash($token))->value('expires_at')
        );
    }
}
