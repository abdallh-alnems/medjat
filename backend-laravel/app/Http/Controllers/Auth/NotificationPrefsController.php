<?php

declare(strict_types=1);

namespace App\Http\Controllers\Auth;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Employee;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/auth/notification_prefs.php.
 *
 * Which alerts this person wants. Split into two actions on one route pair
 * because the old file branched on the request method inside itself.
 */
final class NotificationPrefsController
{
    /**
     * Every switch defaults to on. Someone who has never opened the screen
     * should still hear about a missing check-out.
     */
    private const DEFAULTS = [
        'late_absence' => true,
        'missing_checkout' => true,
        'document_expiry' => true,
        'leave_events' => true,
        'payroll_events' => true,
    ];

    public function show(Request $request): JsonResponse
    {
        $adminId = $this->adminId($request);

        $stored = DB::table('admin_notification_prefs')->where('admin_id', $adminId)->value('prefs');
        $decoded = is_string($stored) ? json_decode($stored, true) : null;

        return ApiResponse::success([
            'prefs' => is_array($decoded) ? $this->normalize($decoded) : self::DEFAULTS,
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $adminId = $this->adminId($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $submitted = $request->input('prefs');
        if (! is_array($submitted)) {
            throw new ApiFailure('prefs must be an object', 400, 'prefs_object');
        }

        $prefs = $this->normalize($submitted);

        DB::table('admin_notification_prefs')->upsert(
            [[
                'admin_id' => $adminId,
                'tenant_id' => $tenantId > 0 ? $tenantId : null,
                'prefs' => json_encode($prefs, JSON_UNESCAPED_UNICODE),
                'updated_at' => DB::raw('NOW()'),
            ]],
            ['admin_id'],
            ['prefs', 'updated_at'],
        );

        return ApiResponse::success(['prefs' => $prefs]);
    }

    /**
     * Unknown keys are dropped and missing ones default to on, so a stored blob
     * written by an older client can never turn into a partial preference set.
     *
     * @param  array<mixed>  $submitted
     * @return array<string, bool>
     */
    private function normalize(array $submitted): array
    {
        $prefs = [];

        foreach (array_keys(self::DEFAULTS) as $key) {
            $prefs[$key] = isset($submitted[$key]) ? (bool) $submitted[$key] : true;
        }

        return $prefs;
    }

    /**
     * Preferences hang off the admins row, which every employee also has — it
     * is what carries their permissions.
     */
    private function adminId(Request $request): int
    {
        $employee = $request->attributes->get('employee');

        $adminId = $employee instanceof Employee ? $employee->admin_id : null;

        if ($adminId === null) {
            throw new ApiFailure(
                'No account linked to receive notifications',
                422,
                'account_linked_receive_notifications'
            );
        }

        return $adminId;
    }
}
