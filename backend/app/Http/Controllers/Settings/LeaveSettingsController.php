<?php

declare(strict_types=1);

namespace App\Http\Controllers\Settings;

use App\Domain\Audit\AuditLog;
use App\Domain\Leave\CarryoverPolicy;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/settings/leave_settings.php.
 *
 * The company's annual entitlement and what happens to days nobody used.
 *
 * Carryover lives in the policy table, which supports rules per branch,
 * category or seniority; this screen edits the company-wide one. The old single
 * column on `tenants` is kept in step because the resolver still falls back to
 * it, and reading is tolerant of a company that has one but no policy row yet.
 */
final class LeaveSettingsController
{
    public function show(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $tenant = DB::table('tenants')->where('id', $tenantId)->first([
            'default_annual_leave_days', 'leave_carryover_max_days',
            'auto_rollover_enabled', 'apply_legal_seniority_entitlement',
        ]);

        if ($tenant === null) {
            throw new ApiFailure('Tenant not found', 404, 'not_found');
        }

        $policy = CarryoverPolicy::tenantPolicy($tenantId);

        $legacyMax = Value::nullableInt($tenant->leave_carryover_max_days);

        // Before any policy is saved, a company-wide cap on the tenant row is
        // the whole policy: carryover is on precisely when one is set.
        $enabled = $policy === null ? $legacyMax !== null : Value::int($policy['carryover_enabled'] ?? null) === 1;
        $maxDays = $policy === null ? $legacyMax : Value::nullableInt($policy['carryover_max_days'] ?? null);

        return ApiResponse::success([
            'default_annual_leave_days' => Value::int($tenant->default_annual_leave_days),
            'leave_carryover_max_days' => $enabled ? $maxDays : null,
            'carryover_enabled' => $enabled,
            'carryover_expiry_months' => $policy === null ? null : Value::nullableInt($policy['expiry_months'] ?? null),
            'carryover_encash_excess' => $policy !== null && Value::int($policy['encash_excess'] ?? null) === 1,
            'carryover_legal_min_days' => $policy === null ? null : Value::nullableInt($policy['legal_min_carry_days'] ?? null),
            'auto_rollover_enabled' => Value::int($tenant->auto_rollover_enabled) === 1,
            // Defaults on: the seniority entitlement is a legal minimum, and a
            // company that never touched this screen should still honour it.
            'apply_legal_seniority_entitlement' => Value::int($tenant->apply_legal_seniority_entitlement, 1) === 1,
        ]);
    }

    public function save(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);

        $tenantFields = [];

        if ($request->has('default_annual_leave_days')) {
            $days = Value::int($request->input('default_annual_leave_days'));

            if ($days < 0 || $days > 366) {
                throw new ApiFailure(
                    'default_annual_leave_days must be between 0 and 366',
                    422,
                    'default_annual_leave_days_between',
                );
            }

            $tenantFields['default_annual_leave_days'] = $days;
        }

        if ($request->has('auto_rollover_enabled')) {
            $tenantFields['auto_rollover_enabled'] = $request->boolean('auto_rollover_enabled') ? 1 : 0;
        }

        if ($request->has('apply_legal_seniority_entitlement')) {
            $tenantFields['apply_legal_seniority_entitlement'] =
                $request->boolean('apply_legal_seniority_entitlement') ? 1 : 0;
        }

        $touchesPolicy = $request->hasAny([
            'leave_carryover_max_days', 'carryover_enabled', 'carryover_expiry_months',
            'carryover_encash_excess', 'carryover_legal_min_days',
        ]);

        if ($tenantFields === [] && ! $touchesPolicy) {
            throw new ApiFailure('No leave settings provided', 422, 'leave_settings_provided');
        }

        if ($touchesPolicy) {
            $rawMax = $request->input('leave_carryover_max_days');

            // A cap on its own switches carryover on: sending a number and
            // having nothing happen is the more surprising behaviour.
            $enabled = $request->has('carryover_enabled')
                ? $request->boolean('carryover_enabled')
                : ($rawMax !== null && $rawMax !== '');

            $maxDays = ($rawMax === null || $rawMax === '')
                ? null
                : self::inRange($rawMax, 0, 366, 'leave_carryover_max_days');

            CarryoverPolicy::saveTenantPolicy($tenantId, [
                'carryover_enabled' => $enabled ? 1 : 0,
                'carryover_max_days' => $maxDays,
                'expiry_months' => self::optional(
                    $request->input('carryover_expiry_months'), 0, 60, 'carryover_expiry_months',
                ),
                'encash_excess' => $request->boolean('carryover_encash_excess') ? 1 : 0,
                'legal_min_carry_days' => self::optional(
                    $request->input('carryover_legal_min_days'), 0, 366, 'carryover_legal_min_days',
                ),
            ]);

            // Kept in step for the resolver's fallback and for older clients
            // that still read the column.
            $tenantFields['leave_carryover_max_days'] = $enabled ? $maxDays : null;
        }

        if ($tenantFields !== []) {
            DB::table('tenants')->where('id', $tenantId)->update($tenantFields);
        }

        AuditLog::record(
            $tenantId, $admin->id, 'tenant.update_leave_settings', 'tenant', $tenantId, $tenantFields,
        );

        return ApiResponse::success(['message' => 'Leave settings updated']);
    }

    private static function optional(mixed $raw, int $min, int $max, string $field): ?int
    {
        if ($raw === null || $raw === '') {
            return null;
        }

        return self::inRange($raw, $min, $max, $field);
    }

    private static function inRange(mixed $raw, int $min, int $max, string $field): int
    {
        $value = Value::int($raw);

        if ($value < $min || $value > $max) {
            throw new ApiFailure(
                "$field must be between $min and $max, or null",
                422,
                'between_null',
            );
        }

        return $value;
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $admin;
    }
}
