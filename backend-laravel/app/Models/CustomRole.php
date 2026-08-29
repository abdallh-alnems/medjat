<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A per-administrator permission set that overrides their role's defaults.
 *
 * @property int $id
 * @property int $tenant_id
 * @property int $admin_id
 * @property int|null $branch_id
 * @property string $name
 * @property list<string> $permissions
 */
final class CustomRole extends Model
{
    protected $table = 'custom_roles';

    protected $guarded = [];

    /** @return array<string, string> */
    protected function casts(): array
    {
        return ['permissions' => 'array'];
    }

    /**
     * @return list<string>|null null when no custom role is assigned, which is
     *                           different from one assigned with no permissions.
     */
    public static function permissionsFor(int $adminId, int $tenantId): ?array
    {
        $row = self::query()
            ->where('admin_id', $adminId)
            ->where('tenant_id', $tenantId)
            ->first();

        if ($row === null) {
            return null;
        }

        $permissions = $row->permissions;

        return is_array($permissions) ? array_values(array_filter($permissions, 'is_string')) : [];
    }
}
