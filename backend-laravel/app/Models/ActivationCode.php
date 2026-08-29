<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
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
}
