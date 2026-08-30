<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * An operator of the product itself, as opposed to an administrator of a
 * company on it.
 *
 * The fourth principal, and the only one that is not scoped to a tenant: the
 * support desk exists precisely to look across companies. That makes it the
 * account worth guarding hardest, which is why its sessions are short-lived and
 * every action it takes is written to its own audit log.
 *
 * @property int $id
 * @property string $username
 * @property string|null $email
 * @property string $password_hash
 * @property string|null $display_name
 * @property string $role
 * @property int $is_active
 */
final class SuperAdmin extends Model
{
    protected $table = 'super_admins';

    public $timestamps = false;

    /**
     * The ladder. A required role is satisfied by that rung or anything above.
     *
     * @var array<string, int>
     */
    public const RANKS = ['readonly' => 1, 'admin' => 2, 'superadmin' => 3];

    protected $guarded = [];

    public function outranks(string $required): bool
    {
        return (self::RANKS[$this->role] ?? 0) >= (self::RANKS[$required] ?? 0);
    }
}
