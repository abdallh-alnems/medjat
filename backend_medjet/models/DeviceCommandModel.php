<?php

/**
 * Commands waiting to be collected by a terminal.
 *
 * The server never dials the device — it cannot, the device sits behind the
 * customer's router. Instead the device polls (`GET /iclock/getrequest`) every
 * few seconds and picks up whatever is queued here.
 */
final class DeviceCommandModel {
    /** Commands the app is allowed to queue, mapped to their ADMS command line. */
    public const KINDS = ['sync_time', 'reboot', 'info'];

    public static function queue(
        int $tenantId,
        int $deviceId,
        string $kind,
        string $payload,
        ?int $adminId
    ): int {
        Database::execute(
            "INSERT INTO device_commands (tenant_id, device_id, kind, payload, created_by)
             VALUES (?, ?, ?, ?, ?)",
            [$tenantId, $deviceId, $kind, $payload, $adminId]
        );
        return (int) Database::lastInsertId();
    }

    /**
     * Hands the next queued commands to the device and marks them sent.
     *
     * Marked 'sent' rather than waiting for confirmation: a device that reboots
     * mid-command would otherwise be handed the same command on every poll,
     * forever. The device reports the outcome separately (`devicecmd`).
     */
    public static function claimQueued(int $deviceId, int $limit = 5): array {
        $limit = max(1, min(20, $limit));
        $rows = Database::fetchAll(
            "SELECT id, kind, payload FROM device_commands
             WHERE device_id = ? AND state = 'queued'
             ORDER BY id ASC LIMIT $limit",
            [$deviceId]
        );
        if (!$rows) {
            return [];
        }

        $ids = array_column($rows, 'id');
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        Database::execute(
            "UPDATE device_commands SET state = 'sent', sent_at = NOW() WHERE id IN ($placeholders)",
            $ids
        );

        return $rows;
    }

    public static function complete(int $commandId, int $deviceId, ?string $returnCode): void {
        // Return code 0 is success in the ADMS protocol; anything else is the
        // device telling us it could not do it.
        $ok = $returnCode === null || $returnCode === '' || (int) $returnCode === 0;
        Database::execute(
            "UPDATE device_commands
             SET state = ?, result_code = ?, completed_at = NOW()
             WHERE id = ? AND device_id = ?",
            [$ok ? 'done' : 'failed', $returnCode, $commandId, $deviceId]
        );
    }

    public static function listForDevice(int $deviceId, int $tenantId, int $limit = 20): array {
        $limit = max(1, min(100, $limit));
        return Database::fetchAll(
            "SELECT id, kind, state, result_code, sent_at, completed_at, created_at
             FROM device_commands
             WHERE device_id = ? AND tenant_id = ?
             ORDER BY id DESC LIMIT $limit",
            [$deviceId, $tenantId]
        );
    }

    /** Drops stale queued/sent commands so a long-offline device is not flooded on return. */
    public static function pruneStale(int $deviceId, int $olderThanHours = 24): void {
        Database::execute(
            "UPDATE device_commands SET state = 'failed', result_code = 'expired'
             WHERE device_id = ? AND state IN ('queued','sent')
               AND created_at < DATE_SUB(NOW(), INTERVAL ? HOUR)",
            [$deviceId, $olderThanHours]
        );
    }
}
