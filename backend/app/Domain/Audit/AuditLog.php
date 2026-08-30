<?php

declare(strict_types=1);

namespace App\Domain\Audit;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Request;
use Throwable;

/**
 * Records who changed what.
 *
 * Deliberately never throws: an audit row that cannot be written must not undo
 * the action it was describing. A failure here is a logging problem, and losing
 * the salary change because the audit insert failed would be a much worse one.
 */
final class AuditLog
{
    /**
     * @param  array<string, mixed>|null  $payload  What changed. Stored as JSON
     *                                              with Arabic left readable.
     */
    public static function record(
        int $tenantId,
        ?int $adminId,
        string $action,
        ?string $targetType = null,
        int|string|null $targetId = null,
        ?array $payload = null,
    ): void {
        try {
            DB::table('audit_log')->insert([
                'tenant_id' => $tenantId,
                'admin_id' => $adminId,
                'action' => $action,
                'target_type' => $targetType,
                'target_id' => $targetId === null ? null : (string) $targetId,
                'payload' => $payload === null ? null : json_encode($payload, JSON_UNESCAPED_UNICODE),
                'ip' => Request::ip(),
            ]);
        } catch (Throwable $e) {
            Log::warning('Audit log write failed', ['action' => $action, 'exception' => $e]);
        }
    }
}
