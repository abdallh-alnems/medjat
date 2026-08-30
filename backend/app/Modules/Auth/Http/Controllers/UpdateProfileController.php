<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Shared\Contact\PhoneValidator;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/auth/update_profile.php.
 *
 * A partial update: only the keys actually present in the request are touched,
 * which is why this reads the raw payload rather than a validated array — the
 * difference between "phone was omitted" and "phone was sent empty" is the
 * difference between leaving it alone and clearing it.
 */
final class UpdateProfileController
{
    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        /** @var array<string, mixed> $changes */
        $changes = [];

        if ($request->has('name')) {
            $name = trim(Value::string($request->input('name')));
            if ($name === '') {
                throw new ApiFailure('Name cannot be empty', 422, 'name_cannot_empty');
            }
            $changes['name'] = $name;
        }

        if ($request->has('phone')) {
            $phone = trim(Value::string($request->input('phone')));

            if ($phone === '') {
                // Sending an empty string clears the number back to NULL.
                $changes['phone'] = null;
            } else {
                $normalized = PhoneValidator::normalize($phone);
                if ($normalized === null) {
                    throw new ApiFailure('Invalid phone number', 422, 'invalid_phone_number');
                }
                $changes['phone'] = $normalized;
            }
        }

        if ($changes === []) {
            throw new ApiFailure('Nothing to update', 422, 'nothing_update');
        }

        Admin::query()->whereKey($admin->id)->where('tenant_id', $tenantId)->update($changes);

        AuditLog::record($tenantId, $admin->id, 'profile.update', 'admin', $admin->id, $changes);

        return ApiResponse::success(['message' => 'Profile updated']);
    }
}
