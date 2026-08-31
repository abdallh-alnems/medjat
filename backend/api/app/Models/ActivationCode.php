<?php

declare(strict_types=1);

namespace App\Models;

use App\Support\Value;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\DB;

/**
 * A single-use code (and matching deep link) that ties one employee record to
 * one phone.
 *
 * @property int $id
 * @property int $tenant_id
 * @property int $employee_id
 * @property string $code
 * @property string|null $token
 * @property string|null $used_at
 * @property string|null $used_by_firebase_uid
 * @property string $expires_at
 */
final class ActivationCode extends Model
{
    protected $table = 'employee_activation_codes';

    /**
     * The table records when a code was created and when it was used, but never
     * "last modified" — a code is written once and consumed once, so there is no
     * updated_at column for Eloquent to fill.
     */
    public const UPDATED_AT = null;

    protected $guarded = [];

    /**
     * Unused and not yet expired.
     *
     * Expiry is compared by MySQL against its own clock: PHP runs UTC here while
     * MySQL runs the server's zone, so a PHP-side comparison would keep codes
     * alive for hours past their expiry.
     *
     * @param  Builder<self>  $query
     * @return Builder<self>
     */
    public function scopeUsable(Builder $query): Builder
    {
        return $query->whereNull('used_at')->where('expires_at', '>', DB::raw('NOW()'));
    }

    public static function findUsableByCode(string $code): ?self
    {
        /** @var self|null */
        return self::query()->usable()->where('code', $code)->first();
    }

    public static function findUsableByToken(string $token): ?self
    {
        /** @var self|null */
        return self::query()->usable()->where('token', $token)->first();
    }

    /**
     * Consumes the code.
     *
     * The device id goes into used_by_firebase_uid because employees have no
     * Firebase identity — the column predates the employee channel and the
     * "device:" prefix is what distinguishes the two kinds of consumer.
     */
    public function consumeForDevice(string $deviceId): void
    {
        self::query()->whereKey($this->id)->update([
            'used_at' => DB::raw('NOW()'),
            'used_by_firebase_uid' => 'device:'.$deviceId,
        ]);
    }

    /** How long a code stays usable. Long enough to reach somebody, short enough to matter. */
    public const VALIDITY_HOURS = 24;

    /**
     * The alphabet a code is drawn from.
     *
     * No 0, O, I or 1: the code is read aloud down a phone line and typed by
     * somebody who has never seen it written, so the pairs that sound and look
     * alike are simply not in it.
     */
    private const ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

    private const CODE_LENGTH = 6;

    /**
     * Issues a fresh code and its matching link token.
     *
     * Both name the same row, so spending either spends both: the employee can
     * type the code or open the link, and cannot do both.
     *
     * @return array{code: string, token: string, expires_at: string}
     */
    public static function generateFor(int $tenantId, int $employeeId): array
    {
        // Any code this employee is still holding stops working. Two live codes
        // for one person means a stale message can activate an account after
        // somebody deliberately reissued it.
        self::query()
            ->where('employee_id', $employeeId)
            ->whereNull('used_at')
            ->where('expires_at', '>', DB::raw('NOW()'))
            ->update(['expires_at' => DB::raw('NOW()')]);

        $code = self::uniqueCode();
        $token = bin2hex(random_bytes(32));

        DB::insert(
            'INSERT INTO employee_activation_codes (tenant_id, employee_id, code, token, expires_at)
             VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))',
            [$tenantId, $employeeId, $code, $token, self::VALIDITY_HOURS]
        );

        $expiresAt = Value::string(self::query()->where('token', $token)->value('expires_at'));

        return ['code' => $code, 'token' => $token, 'expires_at' => $expiresAt];
    }

    /** The deep link an employee opens to join. */
    public static function joinLink(string $token): string
    {
        $base = rtrim(Config::string('medjat.join.base_url'), '/');

        return $base.'/join?token='.urlencode($token);
    }

    private static function uniqueCode(): string
    {
        do {
            $code = '';
            for ($i = 0; $i < self::CODE_LENGTH; $i++) {
                $code .= self::ALPHABET[random_int(0, strlen(self::ALPHABET) - 1)];
            }
        } while (self::query()->where('code', $code)->exists());

        return $code;
    }
}
