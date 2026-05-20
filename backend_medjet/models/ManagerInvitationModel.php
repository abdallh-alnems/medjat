<?php

final class ManagerInvitationModel {
    private const CODE_LENGTH = 8;
    private const VALIDITY_HOURS = 72;

    public static function create(int $tenantId, int $invitedBy, array $data): array {
        $code = self::generateUniqueCode();
        $tokenHash = hash('sha256', $code);
        $expiresAt = date('Y-m-d H:i:s', strtotime('+' . self::VALIDITY_HOURS . ' hours'));

        Database::execute(
            "INSERT INTO manager_invitations
             (tenant_id, email, name, role, branch_id, permissions, token_hash, expires_at, invited_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['email'],
                $data['name'] ?? '',
                $data['role'],
                $data['branch_id'] ?? null,
                isset($data['permissions']) ? json_encode($data['permissions']) : null,
                $tokenHash,
                $expiresAt,
                $invitedBy,
            ]
        );

        return [
            'id' => (int) Database::lastInsertId(),
            'code' => $code,
            'expires_at' => $expiresAt,
        ];
    }

    public static function findByCode(string $code): ?array {
        $tokenHash = hash('sha256', $code);
        return Database::fetchOne(
            "SELECT * FROM manager_invitations
             WHERE token_hash = ? AND cancelled_at IS NULL AND accepted_at IS NULL
                AND expires_at > NOW() LIMIT 1",
            [$tokenHash]
        );
    }

    public static function getByTenant(int $tenantId, ?string $status = null): array {
        $sql = "SELECT mi.*, b.name as branch_name
                FROM manager_invitations mi
                LEFT JOIN branches b ON b.id = mi.branch_id
                WHERE mi.tenant_id = ?";
        $params = [$tenantId];

        if ($status === 'pending') {
            $sql .= " AND mi.cancelled_at IS NULL AND mi.accepted_at IS NULL AND mi.expires_at > NOW()";
        } elseif ($status === 'accepted') {
            $sql .= " AND mi.accepted_at IS NOT NULL";
        } elseif ($status === 'cancelled') {
            $sql .= " AND mi.cancelled_at IS NOT NULL";
        } elseif ($status === 'expired') {
            $sql .= " AND mi.cancelled_at IS NULL AND mi.accepted_at IS NULL AND mi.expires_at <= NOW()";
        }

        $sql .= " ORDER BY mi.created_at DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function cancel(int $invitationId, int $tenantId): bool {
        Database::execute(
            "UPDATE manager_invitations SET cancelled_at = NOW()
             WHERE id = ? AND tenant_id = ? AND cancelled_at IS NULL AND accepted_at IS NULL",
            [$invitationId, $tenantId]
        );
        return true;
    }

    public static function markAccepted(int $invitationId, int $adminId): void {
        Database::execute(
            "UPDATE manager_invitations
             SET accepted_at = NOW(), accepted_admin_id = ?
             WHERE id = ?",
            [$adminId, $invitationId]
        );
    }

    private static function generateUniqueCode(): string {
        do {
            $code = strtoupper(bin2hex(random_bytes(self::CODE_LENGTH / 2)));
            $hash = hash('sha256', $code);
            $exists = Database::fetchOne(
                "SELECT id FROM manager_invitations WHERE token_hash = ? LIMIT 1",
                [$hash]
            );
        } while ($exists);
        return $code;
    }
}
