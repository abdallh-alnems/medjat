<?php

declare(strict_types=1);

namespace App\Shared\Http\Middleware;

use App\Exceptions\ApiFailure;
use App\Models\Admin;

/**
 * Whether this administrator may look at a given branch.
 *
 * Not a route middleware, because the branch is usually a value inside the
 * request rather than a segment of the path — a helper the controllers call once
 * they know which branch they are about to answer for.
 */
final class RequireBranchAccess
{
    /**
     * A general manager and HR see the whole company. Everybody else is pinned
     * to the branch they were given, if they were given one at all: an
     * administrator with no branch is company-wide by construction rather than
     * blocked from everything.
     */
    public static function assert(Admin $admin, ?int $branchId): void
    {
        if (in_array($admin->role, ['general_manager', 'hr'], true)) {
            return;
        }

        if ($admin->branch_id === null || $branchId === null) {
            return;
        }

        if ($admin->branch_id !== $branchId) {
            throw new ApiFailure(__('messages.branch_access_denied'), 403, 'branch_access_denied');
        }
    }
}
