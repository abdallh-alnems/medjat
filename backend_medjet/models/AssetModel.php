<?php

final class AssetModel {
    public const TYPES = ['money', 'equipment', 'device', 'vehicle', 'document', 'other'];
    public const STATUSES = ['assigned', 'return_requested', 'returned'];

    public static function create(
        int $tenantId,
        int $employeeId,
        string $type,
        string $name,
        ?string $description,
        ?float $value,
        ?string $currency,
        ?string $serialNo,
        int $quantity,
        string $assignedAt,
        ?string $assignPhotoUrl,
        ?string $notes,
        int $assignedBy
    ): int {
        Database::execute(
            "INSERT INTO asset_custody
                (tenant_id, employee_id, type, name, description, value, currency,
                 serial_no, quantity, assign_photo_url, notes, status, assigned_at, assigned_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'assigned', ?, ?)",
            [
                $tenantId, $employeeId, $type, $name, $description, $value,
                $currency ?: 'SAR', $serialNo, $quantity, $assignPhotoUrl, $notes,
                $assignedAt, $assignedBy,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM asset_custody WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function listByTenant(int $tenantId, ?string $status = null, ?int $employeeId = null): array {
        $sql = "SELECT ac.*, e.name AS employee_name
                FROM asset_custody ac
                JOIN employees e ON e.id = ac.employee_id
                WHERE ac.tenant_id = ?";
        $params = [$tenantId];
        if ($status !== null && $status !== '') {
            $sql .= " AND ac.status = ?";
            $params[] = $status;
        }
        if ($employeeId !== null) {
            $sql .= " AND ac.employee_id = ?";
            $params[] = $employeeId;
        }
        $sql .= " ORDER BY ac.created_at DESC";
        return Database::fetchAll($sql, $params);
    }

    /** Employee requests the custody to be returned (employee app). */
    public static function requestReturn(int $id, int $tenantId, ?string $returnNote, ?string $returnPhotoUrl): void {
        Database::execute(
            "UPDATE asset_custody
             SET status = 'return_requested', return_requested_at = NOW(),
                 return_note = ?, return_photo_url = COALESCE(?, return_photo_url), rejection_reason = NULL
             WHERE id = ? AND tenant_id = ? AND status = 'assigned'",
            [$returnNote, $returnPhotoUrl, $id, $tenantId]
        );
    }

    /** Admin confirms the item was returned. Works from 'assigned' or 'return_requested'. */
    public static function approveReturn(int $id, int $tenantId, int $adminId): void {
        Database::execute(
            "UPDATE asset_custody
             SET status = 'returned', returned_at = NOW(), return_approved_by = ?, rejection_reason = NULL
             WHERE id = ? AND tenant_id = ? AND status IN ('assigned', 'return_requested')",
            [$adminId, $id, $tenantId]
        );
    }

    /** Admin rejects a return request, sending it back to 'assigned'. */
    public static function rejectReturn(int $id, int $tenantId, int $adminId, ?string $reason): void {
        Database::execute(
            "UPDATE asset_custody
             SET status = 'assigned', return_requested_at = NULL, rejection_reason = ?, return_approved_by = ?
             WHERE id = ? AND tenant_id = ? AND status = 'return_requested'",
            [$reason, $adminId, $id, $tenantId]
        );
    }
}
