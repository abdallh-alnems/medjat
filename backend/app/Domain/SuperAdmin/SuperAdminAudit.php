<?php

declare(strict_types=1);

namespace App\Domain\SuperAdmin;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Request;
use Throwable;

/**
 * What the support desk did.
 *
 * Its own log, separate from any company's: these actions cross tenants, so
 * writing them into one company's activity feed would both mislead that company
 * and hide the action from every other one it touched.
 *
 * Never throws. An audit write that fails must not undo the thing it was
 * recording — the alternative is a support action that half-happened.
 */
final class SuperAdminAudit
{
    /**
     * @param  array<string, mixed>|null  $payload
     */
    public static function record(
        ?int $adminId,
        string $action,
        ?string $targetType = null,
        int|string|null $targetId = null,
        ?array $payload = null,
    ): void {
        try {
            DB::table('super_admin_audit_log')->insert([
                'admin_id' => $adminId,
                'action' => $action,
                'target_type' => $targetType,
                'target_id' => $targetId === null ? null : (string) $targetId,
                'payload' => $payload === null ? null : json_encode($payload, JSON_UNESCAPED_UNICODE),
                'ip' => Request::ip(),
            ]);
        } catch (Throwable $e) {
            Log::warning('Super-admin audit write failed', ['action' => $action, 'exception' => $e]);
        }
    }
}
