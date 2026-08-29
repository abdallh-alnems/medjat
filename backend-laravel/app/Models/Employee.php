<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * @property int $id
 * @property int $tenant_id
 * @property int|null $branch_id
 * @property int|null $admin_id
 * @property string $name
 * @property string $phone
 * @property string $status
 */
final class Employee extends Model
{
    protected $table = 'employees';

    protected $guarded = [];

    /**
     * Fields that must never reach a client. The old backend scrubbed these in
     * EmployeeModel::scrubForClient() at every call site, which meant one
     * forgotten call leaked them; here the model refuses to serialize them at
     * all.
     *
     * @var list<string>
     */
    protected $hidden = [
        'login_code_hash',
        'face_embedding',
    ];

    /** @return HasMany<EmployeeAuthToken, $this> */
    public function authTokens(): HasMany
    {
        return $this->hasMany(EmployeeAuthToken::class);
    }

    /**
     * Every read is scoped to a tenant. Multi-tenant isolation in the old
     * backend depended on remembering to pass $tenantId into each model call;
     * making it a scope means an unscoped query is visible in review as a
     * missing call rather than invisible as an absent argument.
     *
     * @param  Builder<self>  $query
     * @return Builder<self>
     */
    public function scopeForTenant(Builder $query, int $tenantId): Builder
    {
        return $query->where('tenant_id', $tenantId);
    }

    public function isTerminated(): bool
    {
        return $this->status === 'terminated';
    }
}
