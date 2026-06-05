<?php

final class SignaturePartyModel {
    public const SIGNER_TYPES = ['employee', 'admin', 'external'];
    public const STATUSES = ['pending', 'signed', 'declined'];
    public const METHODS = ['drawn', 'typed', 'otp'];

    public static function insertMany(int $tenantId, int $requestId, array $parties): void {
        $order = 1;
        foreach ($parties as $p) {
            Database::execute(
                "INSERT INTO signature_parties
                    (tenant_id, signature_request_id, party_order, signer_type,
                     signer_employee_id, signer_admin_id, signer_name, role_label)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    $tenantId,
                    $requestId,
                    $order,
                    $p['signer_type'],
                    $p['signer_employee_id'] ?? null,
                    $p['signer_admin_id'] ?? null,
                    $p['signer_name'] ?? null,
                    $p['role_label'] ?? null,
                ]
            );
            $order++;
        }
    }

    public static function getByRequest(int $tenantId, int $requestId): array {
        return Database::fetchAll(
            "SELECT * FROM signature_parties
             WHERE signature_request_id = ? AND tenant_id = ?
             ORDER BY party_order ASC",
            [$requestId, $tenantId]
        );
    }

    public static function currentParty(int $tenantId, int $requestId, int $order): ?array {
        return Database::fetchOne(
            "SELECT * FROM signature_parties
             WHERE signature_request_id = ? AND tenant_id = ? AND party_order = ?
             LIMIT 1",
            [$requestId, $tenantId, $order]
        );
    }

    public static function markSigned(int $tenantId, int $partyId, array $sig): void {
        Database::execute(
            "UPDATE signature_parties
             SET status = 'signed', sign_method = ?, signature_image_path = ?, typed_name = ?,
                 consent_given = 1, signed_at = NOW(), signed_ip = ?, signed_user_agent = ?,
                 otp_hash = NULL, otp_expires_at = NULL
             WHERE id = ? AND tenant_id = ?",
            [
                $sig['sign_method'] ?? null,
                $sig['signature_image_path'] ?? null,
                $sig['typed_name'] ?? null,
                $sig['signed_ip'] ?? null,
                $sig['signed_user_agent'] ?? null,
                $partyId,
                $tenantId,
            ]
        );
    }

    public static function markDeclined(int $tenantId, int $partyId, ?string $reason): void {
        Database::execute(
            "UPDATE signature_parties
             SET status = 'declined', decline_reason = ?, signed_at = NOW(), signed_ip = ?
             WHERE id = ? AND tenant_id = ?",
            [
                $reason,
                $_SERVER['REMOTE_ADDR'] ?? null,
                $partyId,
                $tenantId,
            ]
        );
    }

    public static function setOtp(int $tenantId, int $partyId, string $otpHash, string $expiresAt): void {
        Database::execute(
            "UPDATE signature_parties SET otp_hash = ?, otp_expires_at = ? WHERE id = ? AND tenant_id = ?",
            [$otpHash, $expiresAt, $partyId, $tenantId]
        );
    }

    public static function verifyOtp(array $party, string $code): bool {
        if (empty($party['otp_hash']) || empty($party['otp_expires_at'])) {
            return false;
        }
        if (strtotime($party['otp_expires_at']) < time()) {
            return false;
        }
        return password_verify($code, $party['otp_hash']);
    }

    public static function pendingForEmployee(int $tenantId, int $employeeId): array {
        return Database::fetchAll(
            "SELECT sp.*, sr.title, sr.entity_id, sr.entity_type, sr.status AS request_status,
                    sr.current_party, sr.total_parties
             FROM signature_parties sp
             JOIN signature_requests sr ON sr.id = sp.signature_request_id
             WHERE sp.tenant_id = ? AND sp.signer_employee_id = ? AND sp.status = 'pending'
               AND sr.status = 'pending' AND sr.current_party = sp.party_order
             ORDER BY sr.created_at ASC",
            [$tenantId, $employeeId]
        );
    }

    public static function pendingForAdmin(int $tenantId, int $adminId, string $role): array {
        $sql = "SELECT sp.*, sr.title, sr.entity_id, sr.entity_type, sr.status AS request_status,
                       sr.current_party, sr.total_parties
                FROM signature_parties sp
                JOIN signature_requests sr ON sr.id = sp.signature_request_id
                WHERE sp.tenant_id = ? AND sp.signer_type = 'admin' AND sp.status = 'pending'
                  AND sr.status = 'pending' AND sr.current_party = sp.party_order";
        $params = [$tenantId];
        if ($role !== 'general_manager') {
            $sql .= " AND sp.signer_admin_id = ?";
            $params[] = $adminId;
        }
        $sql .= " ORDER BY sr.created_at ASC";
        return Database::fetchAll($sql, $params);
    }
}
