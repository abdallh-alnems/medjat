<?php

final class SignatureRequestModel {
    public const ENTITY_TYPES = ['document_request'];
    public const STATUSES = ['pending', 'completed', 'declined', 'voided'];
    public const SIGNING_ORDERS = ['sequential', 'parallel'];

    public static function create(int $tenantId, array $data): int {
        $verifyCode = self::generateVerifyCode();
        Database::execute(
            "INSERT INTO signature_requests
                (tenant_id, entity_type, entity_id, title, source_pdf_path, source_hash,
                 verify_code, signing_order, current_party, total_parties, expires_at, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['entity_type'],
                $data['entity_id'],
                $data['title'] ?? null,
                $data['source_pdf_path'],
                $data['source_hash'],
                $verifyCode,
                $data['signing_order'] ?? 'sequential',
                1,
                $data['total_parties'],
                $data['expires_at'] ?? null,
                $data['created_by'] ?? null,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function find(int $id, int $tenantId): ?array {
        $req = Database::fetchOne(
            "SELECT * FROM signature_requests WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
        if (!$req) {
            return null;
        }
        $req['parties'] = SignaturePartyModel::getByRequest($tenantId, $id);
        return $req;
    }

    public static function findByVerifyCode(string $code): ?array {
        $req = Database::fetchOne(
            "SELECT * FROM signature_requests WHERE verify_code = ? LIMIT 1",
            [$code]
        );
        if (!$req) {
            return null;
        }
        $req['signed_parties'] = Database::fetchAll(
            "SELECT signer_name, role_label, signed_at, sign_method
             FROM signature_parties
             WHERE signature_request_id = ? AND status = 'signed'
             ORDER BY party_order ASC",
            [$req['id']]
        );
        return $req;
    }

    public static function findOpenForEntity(int $tenantId, string $entityType, int $entityId): ?array {
        return Database::fetchOne(
            "SELECT id FROM signature_requests
             WHERE tenant_id = ? AND entity_type = ? AND entity_id = ? AND status = 'pending'
             LIMIT 1",
            [$tenantId, $entityType, $entityId]
        );
    }

    public static function listByTenant(int $tenantId, ?string $status, ?string $entityType, int $page = 1, int $limit = 30): array {
        $sql = "SELECT sr.*,
                       (SELECT COUNT(*) FROM signature_parties sp WHERE sp.signature_request_id = sr.id AND sp.status = 'signed') AS signed_count,
                       (SELECT COUNT(*) FROM signature_parties sp WHERE sp.signature_request_id = sr.id) AS total_parties_count
                FROM signature_requests sr
                WHERE sr.tenant_id = ?";
        $params = [$tenantId];
        if ($status !== null && $status !== '') {
            $sql .= " AND sr.status = ?";
            $params[] = $status;
        }
        if ($entityType !== null && $entityType !== '') {
            $sql .= " AND sr.entity_type = ?";
            $params[] = $entityType;
        }
        $offset = ($page - 1) * $limit;
        $sql .= " ORDER BY sr.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        return ['items' => Database::fetchAll($sql, $params), 'page' => $page];
    }

    public static function setStatus(int $id, int $tenantId, string $status): void {
        $extra = '';
        $params = [$status];
        if ($status === 'completed') {
            $extra = ", completed_at = NOW()";
        }
        if ($status === 'voided' || $status === 'declined') {
            $extra = ", completed_at = NULL";
        }
        $params[] = $id;
        $params[] = $tenantId;
        Database::execute(
            "UPDATE signature_requests SET status = ?{$extra} WHERE id = ? AND tenant_id = ?",
            $params
        );
    }

    public static function advanceParty(int $id, int $tenantId, int $nextOrder): void {
        Database::execute(
            "UPDATE signature_requests SET current_party = ? WHERE id = ? AND tenant_id = ?",
            [$nextOrder, $id, $tenantId]
        );
    }

    public static function setSigned(int $id, int $tenantId, string $signedPdfPath, string $signedHash): void {
        Database::execute(
            "UPDATE signature_requests
             SET signed_pdf_path = ?, signed_hash = ?, status = 'completed', completed_at = NOW()
             WHERE id = ? AND tenant_id = ?",
            [$signedPdfPath, $signedHash, $id, $tenantId]
        );
    }

    private static function generateVerifyCode(): string {
        $maxAttempts = 10;
        for ($i = 0; $i < $maxAttempts; $i++) {
            $code = bin2hex(random_bytes(8));
            $exists = Database::fetchOne(
                "SELECT id FROM signature_requests WHERE verify_code = ? LIMIT 1",
                [$code]
            );
            if (!$exists) {
                return $code;
            }
        }
        return bin2hex(random_bytes(12));
    }
}
