<?php

declare(strict_types=1);

namespace App\Modules\SuperAdmin\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\SuperAdmin;
use App\Modules\Notifications\Domain\PushSender;
use App\Modules\SuperAdmin\Domain\SuperAdminAudit;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/admin/{dashboard/overview,force_update/trigger,notifications}.php.
 *
 * The platform-wide corner of the panel: the headline numbers, the update
 * floor, and announcements.
 */
final class PlatformController
{
    private const AUDIENCES = ['admins', 'employees', 'all'];

    private const PLATFORMS = ['all', 'android', 'ios'];

    public function __construct(private readonly PushSender $push) {}

    public function overview(): JsonResponse
    {
        return ApiResponse::success([
            'total_tenants' => DB::table('tenants')->count(),
            'active_tenants' => DB::table('tenants')->where('is_active', 1)->count(),
            'total_users' => DB::table('admins')->count(),
            'total_employees' => DB::table('employees')->where('status', 'active')->count(),
        ]);
    }

    /**
     * The minimum build a platform may run.
     *
     * Keyed by platform, not by app — which is the axis the Remote Config gate
     * cannot express, and why both exist.
     */
    public function forceUpdate(Request $request): JsonResponse
    {
        $admin = self::admin($request);

        $platform = Value::string($request->input('platform'), 'all') ?: 'all';

        if (! in_array($platform, self::PLATFORMS, true)) {
            throw new ApiFailure('platform must be all, android or ios', 422, 'invalid_platform');
        }

        $minVersion = trim(Value::string($request->input('min_version')));

        if ($minVersion === '') {
            throw new ApiFailure('min_version is required', 422, 'min_version_required');
        }

        if (preg_match('/^\d+(\.\d+){0,3}$/', $minVersion) !== 1) {
            throw new ApiFailure(
                'Invalid version format. Use dotted numeric (e.g. 1.2.0)',
                422,
                'invalid_version_format_dotted_numeric',
            );
        }

        $message = Value::string($request->input('message'), 'Please update the app to continue')
            ?: 'Please update the app to continue';

        DB::table('force_updates')->upsert(
            [[
                'platform' => $platform,
                'min_version' => $minVersion,
                'message' => $message,
                'is_active' => 1,
                'created_at' => DB::raw('NOW()'),
                'updated_at' => DB::raw('NOW()'),
            ]],
            ['platform'],
            ['min_version', 'message', 'is_active', 'updated_at'],
        );

        SuperAdminAudit::record($admin->id, 'force_update.trigger', null, null, [
            'platform' => $platform,
            'min_version' => $minVersion,
        ]);

        return ApiResponse::success(['message' => 'Force update triggered']);
    }

    /**
     * A platform-wide announcement.
     *
     * The audience is explicit. The original pushed to `admin_devices` and
     * stopped there — the managers' table — so every employee on the platform
     * was silently excluded from a message the panel called "send to everyone".
     */
    public function announceToAll(Request $request): JsonResponse
    {
        $admin = self::admin($request);
        [$title, $body, $audience] = $this->announcement($request);

        $sentAdmins = 0;
        $sentEmployees = 0;

        if ($audience !== 'employees') {
            $sentAdmins = $this->pushToAdmins(
                DB::table('admins')
                    ->where('is_active', 1)
                    ->whereNotIn('role', ['employee', 'pending'])
                    ->pluck('id'),
                $title,
                $body,
            );
        }

        if ($audience !== 'admins') {
            $sentEmployees = $this->pushToEmployees(
                DB::table('employees')->where('status', 'active')->pluck('id'),
                $title,
                $body,
            );
        }

        SuperAdminAudit::record($admin->id, 'notification.send_all', null, null, [
            'title' => $title,
            'audience' => $audience,
            'sent_admins' => $sentAdmins,
            'sent_employees' => $sentEmployees,
        ]);

        return ApiResponse::success([
            'audience' => $audience,
            'sent_admins' => $sentAdmins,
            'sent_employees' => $sentEmployees,
            'sent' => $sentAdmins + $sentEmployees,
        ]);
    }

    /** The same announcement, to one company. */
    public function announceToTenant(Request $request): JsonResponse
    {
        $admin = self::admin($request);
        [$title, $body, $audience] = $this->announcement($request);

        $tenantId = Value::int($request->input('tenant_id'));

        $tenant = $tenantId > 0
            ? DB::table('tenants')->where('id', $tenantId)->first(['id', 'name'])
            : null;

        if ($tenant === null) {
            throw new ApiFailure(__('messages.tenant_not_found'), 404, 'not_found');
        }

        $sentAdmins = 0;
        $sentEmployees = 0;

        if ($audience !== 'employees') {
            $sentAdmins = $this->pushToAdmins(
                DB::table('admins')
                    ->where('tenant_id', $tenantId)->where('is_active', 1)
                    ->whereNotIn('role', ['employee', 'pending'])
                    ->pluck('id'),
                $title,
                $body,
            );
        }

        if ($audience !== 'admins') {
            $sentEmployees = $this->pushToEmployees(
                DB::table('employees')
                    ->where('tenant_id', $tenantId)->where('status', 'active')
                    ->pluck('id'),
                $title,
                $body,
            );
        }

        SuperAdminAudit::record($admin->id, 'notification.send_tenant', 'tenant', $tenantId, [
            'title' => $title,
            'audience' => $audience,
            'sent_admins' => $sentAdmins,
            'sent_employees' => $sentEmployees,
        ]);

        return ApiResponse::success([
            'tenant_id' => $tenantId,
            'tenant_name' => $tenant->name,
            'audience' => $audience,
            'sent_admins' => $sentAdmins,
            'sent_employees' => $sentEmployees,
            'sent' => $sentAdmins + $sentEmployees,
        ]);
    }

    /**
     * @param  \Illuminate\Support\Collection<int, mixed>  $ids
     */
    private function pushToAdmins(mixed $ids, string $title, string $body): int
    {
        $sent = 0;

        foreach ($ids as $id) {
            $sent += $this->push->toAdmin(Value::int($id), $title, $body, ['type' => 'announcement']) ? 1 : 0;
        }

        return $sent;
    }

    /**
     * @param  \Illuminate\Support\Collection<int, mixed>  $ids
     */
    private function pushToEmployees(mixed $ids, string $title, string $body): int
    {
        $sent = 0;

        foreach ($ids as $id) {
            $sent += $this->push->toEmployee(Value::int($id), $title, $body, ['type' => 'announcement']) ? 1 : 0;
        }

        return $sent;
    }

    /**
     * @return array{0: string, 1: string, 2: string}
     */
    private function announcement(Request $request): array
    {
        $title = trim(Value::string($request->input('title')));
        $body = trim(Value::string($request->input('body')));

        if ($title === '' || $body === '') {
            throw new ApiFailure('title and body are required', 422, 'title_body_required');
        }

        $audience = Value::string($request->input('audience'), 'admins') ?: 'admins';

        if (! in_array($audience, self::AUDIENCES, true)) {
            throw new ApiFailure(__('messages.audience_invalid'), 422, 'invalid_audience');
        }

        return [$title, $body, $audience];
    }

    private static function admin(Request $request): SuperAdmin
    {
        $admin = $request->attributes->get('super_admin');

        if (! $admin instanceof SuperAdmin) {
            throw new ApiFailure(__('messages.admin_token_required'), 401, 'admin_token_required');
        }

        return $admin;
    }
}
