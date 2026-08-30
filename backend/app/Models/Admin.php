<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A person who signs in to the management surfaces, and — since employees were
 * given app accounts — also the row that carries an employee's identity for
 * permission checks. The `employee` role is the second kind.
 *
 * Companies have no owner: `general_manager` is the top role and can be granted
 * to anyone, with the API enforcing equal-or-lower when roles are assigned.
 *
 * @property int $id
 * @property string $firebase_uid
 * @property int|null $tenant_id
 * @property int|null $branch_id
 * @property string $name
 * @property string|null $phone
 * @property string $role
 * @property bool $is_active
 * @property string|null $active_device_id
 */
final class Admin extends Model
{
    protected $table = 'admins';

    protected $guarded = [];

    /** @var list<string> */
    protected $hidden = ['firebase_uid'];

    /** @return array<string, string> */
    protected function casts(): array
    {
        return ['is_active' => 'boolean'];
    }
}
