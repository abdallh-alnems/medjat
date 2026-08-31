<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

/**
 * The PIN an employee uses to sign in from a browser.
 *
 * @property int $id
 * @property int $tenant_id
 * @property int $employee_id
 * @property string $pin_hash
 * @property int $failed_attempts
 * @property string|null $locked_until
 */
final class EmployeeWebCredential extends Model
{
    /**
     * Five wrong PINs, then fifteen minutes. Rate limiting only slows guessing
     * down; against a six-digit space the lockout is what actually bounds it.
     */
    public const MAX_FAILED_ATTEMPTS = 5;

    private const LOCKOUT_SECONDS = 900;

    protected $table = 'employee_web_credentials';

    protected $guarded = [];

    /** @var list<string> */
    protected $hidden = ['pin_hash'];

    public static function findFor(int $employeeId, int $tenantId): ?self
    {
        /** @var self|null */
        return self::query()
            ->where('employee_id', $employeeId)
            ->where('tenant_id', $tenantId)
            ->first();
    }

    /**
     * Locked right now, by the database's clock — PHP runs UTC here while MySQL
     * runs the server's zone, so comparing in PHP would let a locked account
     * back in hours early.
     */
    public static function isLocked(int $employeeId): bool
    {
        return self::query()
            ->where('employee_id', $employeeId)
            ->whereNotNull('locked_until')
            ->where('locked_until', '>', DB::raw('NOW()'))
            ->exists();
    }

    public function verifyPin(string $pin): bool
    {
        return password_verify($pin, $this->pin_hash);
    }

    public static function recordSuccess(int $employeeId): void
    {
        self::query()->where('employee_id', $employeeId)->update([
            'failed_attempts' => 0,
            'locked_until' => null,
            'last_used_at' => DB::raw('NOW()'),
        ]);
    }

    /**
     * Counts a wrong PIN and locks the credential once the limit is reached.
     *
     * Two statements on purpose. Doing the increment and the lock decision in
     * one UPDATE reads naturally but is wrong: MySQL evaluates SET assignments
     * left to right and later expressions see the *new* value of columns already
     * assigned, so a `CASE WHEN failed_attempts + 1 >= 5` sitting after
     * `failed_attempts = failed_attempts + 1` actually tests the original + 2 —
     * and the account locks an attempt early. That was found by counting the
     * attempts in a test, not by reading the query.
     *
     * @return bool True when this failure caused the lockout.
     */
    public static function recordFailure(int $employeeId): bool
    {
        self::query()->where('employee_id', $employeeId)->increment('failed_attempts');

        DB::update(
            'UPDATE employee_web_credentials
                SET locked_until = DATE_ADD(NOW(), INTERVAL ? SECOND)
              WHERE employee_id = ? AND failed_attempts >= ?',
            [self::LOCKOUT_SECONDS, $employeeId, self::MAX_FAILED_ATTEMPTS]
        );

        return self::isLocked($employeeId);
    }
}
