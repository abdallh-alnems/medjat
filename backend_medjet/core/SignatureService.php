<?php

final class SignatureService {
    public static function open(int $tenantId, int $documentRequestId, array $parties,
                                string $signingOrder, ?string $expiresAt, int $byAdminId): int {
        $docRequest = DocumentRequestModel::find($documentRequestId, $tenantId);
        if (!$docRequest) {
            Response::fail('Document request not found', 404);
        }
        if ($docRequest['status'] !== 'approved') {
            Response::fail('Document must be approved before sending for signature', 422);
        }

        $pdfPath = $docRequest['pdf_path'] ?? null;
        if (empty($pdfPath) || !is_file($pdfPath)) {
            try {
                $pdfPath = LetterPdfService::generateForRequest($docRequest, $tenantId);
                DocumentRequestModel::setPdfPath($documentRequestId, $tenantId, $pdfPath);
            } catch (Throwable $e) {
                error_log('PDF regeneration for signature failed: ' . $e->getMessage());
                Response::fail('Source PDF is unavailable', 500);
            }
        }

        $sourceHash = hash_file('sha256', $pdfPath);

        $existing = SignatureRequestModel::findOpenForEntity($tenantId, 'document_request', $documentRequestId);
        if ($existing) {
            Response::fail('An open signature request already exists for this document', 409);
        }

        $template = null;
        if (!empty($docRequest['template_id'])) {
            $template = DocumentTemplateModel::find((int) $docRequest['template_id'], $tenantId);
        }
        $title = $template ? ($template['name_ar'] ?? $template['name_en'] ?? null) : null;

        $preparedParties = [];
        foreach ($parties as $i => $p) {
            $signerType = $p['signer_type'] ?? '';
            Validator::enum($signerType, ['employee', 'admin'], 'signer_type');

            $party = [
                'signer_type' => $signerType,
                'signer_employee_id' => null,
                'signer_admin_id' => null,
                'signer_name' => $p['signer_name'] ?? null,
                'role_label' => $p['role_label'] ?? null,
            ];

            if ($signerType === 'employee') {
                $empId = (int) ($p['signer_employee_id'] ?? $docRequest['employee_id']);
                $emp = EmployeeModel::findById($empId, $tenantId);
                if (!$emp) {
                    Response::fail("Employee not found for party " . ($i + 1), 422);
                }
                $party['signer_employee_id'] = $empId;
                if (empty($party['signer_name'])) {
                    $party['signer_name'] = $emp['name'] ?? '';
                }
            } elseif ($signerType === 'admin') {
                $adminId = (int) ($p['signer_admin_id'] ?? 0);
                Validator::required($adminId, 'signer_admin_id');
                $admin = AdminModel::findById($adminId, $tenantId);
                if (!$admin) {
                    Response::fail("Admin not found for party " . ($i + 1), 422);
                }
                $party['signer_admin_id'] = $adminId;
                if (empty($party['signer_name'])) {
                    $party['signer_name'] = $admin['name'] ?? '';
                }
            }

            $preparedParties[] = $party;
        }

        $totalParties = count($preparedParties);
        if ($totalParties < 1) {
            Response::fail('At least one signing party is required', 422);
        }

        $db = Database::getInstance();
        $db->beginTransaction();

        try {
            $requestId = SignatureRequestModel::create($tenantId, [
                'entity_type' => 'document_request',
                'entity_id' => $documentRequestId,
                'title' => $title,
                'source_pdf_path' => $pdfPath,
                'source_hash' => $sourceHash,
                'signing_order' => $signingOrder,
                'total_parties' => $totalParties,
                'expires_at' => $expiresAt,
                'created_by' => $byAdminId,
            ]);

            SignaturePartyModel::insertMany($tenantId, $requestId, $preparedParties);

            $db->commit();
        } catch (Exception $e) {
            $db->rollBack();
            error_log('Signature open failed: ' . $e->getMessage());
            Response::error('Failed to create signature request', 500);
        }

        $firstParty = $preparedParties[0] ?? null;
        if ($firstParty) {
            $req = SignatureRequestModel::find($requestId, $tenantId);
            self::notifyParty($tenantId, $firstParty, $req);
        }

        return $requestId;
    }

    public static function sign(int $tenantId, int $requestId, array $party, array $payload,
                                ?int $byAdminId, ?int $byEmployeeId): array {
        $req = SignatureRequestModel::find($requestId, $tenantId);
        if (!$req) {
            Response::fail('Signature request not found', 404);
        }
        if ($req['status'] !== 'pending') {
            Response::fail('Signature request already finalized', 409);
        }
        if ((int) $party['party_order'] !== (int) $req['current_party']) {
            Response::fail('Not your turn to sign', 409);
        }
        if ($party['status'] !== 'pending') {
            Response::fail('Party already acted', 409);
        }

        $method = $payload['method'] ?? '';
        Validator::enum($method, ['drawn', 'typed', 'otp'], 'method');

        $meta = self::captureMeta();
        $sig = [
            'sign_method' => $method,
            'signature_image_path' => null,
            'typed_name' => null,
            'signed_ip' => $meta['ip'],
            'signed_user_agent' => $meta['ua'],
        ];

        if ($method === 'drawn') {
            $data = $payload['signature_data'] ?? '';
            if (empty($data)) {
                Response::fail('signature_data is required for drawn method', 422);
            }
            $sig['signature_image_path'] = self::saveDrawnSignature($tenantId, $data, (int) $party['id']);
        } elseif ($method === 'typed') {
            $typedName = $payload['typed_name'] ?? '';
            Validator::required($typedName, 'typed_name');
            $sig['typed_name'] = $typedName;
        } elseif ($method === 'otp') {
            $otpCode = $payload['otp_code'] ?? '';
            Validator::required($otpCode, 'otp_code');
            if (!SignaturePartyModel::verifyOtp($party, $otpCode)) {
                Response::fail('Invalid or expired OTP code', 422);
            }
        }

        $isLast = (int) $party['party_order'] >= (int) $req['total_parties'];
        $nextOrder = (int) $party['party_order'] + 1;

        // Only DB writes run inside the transaction; the heavy PDF render is done
        // after commit so no row locks are held while mpdf works.
        $db = Database::getInstance();
        $db->beginTransaction();
        try {
            SignaturePartyModel::markSigned($tenantId, (int) $party['id'], $sig);
            if (!$isLast) {
                SignatureRequestModel::advanceParty($requestId, $tenantId, $nextOrder);
            }
            $db->commit();
        } catch (Exception $e) {
            $db->rollBack();
            error_log('Signature sign failed: ' . $e->getMessage());
            Response::error('Failed to process signature', 500);
        }

        if (!$isLast) {
            $nextParty = SignaturePartyModel::currentParty($tenantId, $requestId, $nextOrder);
            if ($nextParty) {
                $freshReq = Database::fetchOne(
                    "SELECT * FROM signature_requests WHERE id = ? AND tenant_id = ? LIMIT 1",
                    [$requestId, $tenantId]
                );
                self::notifyParty($tenantId, $nextParty, $freshReq);
            }
            return ['completed' => false, 'signed_pdf_path' => null];
        }

        // Last party signed: render the final signed PDF outside the transaction,
        // then persist its path/hash (this also flips the request to 'completed').
        $freshReq = Database::fetchOne(
            "SELECT * FROM signature_requests WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$requestId, $tenantId]
        );
        $allParties = SignaturePartyModel::getByRequest($tenantId, $requestId);
        try {
            $signedPdfPath = SignedPdfService::render($tenantId, $freshReq, $allParties);
            $signedHash = hash_file('sha256', $signedPdfPath);
            SignatureRequestModel::setSigned($requestId, $tenantId, $signedPdfPath, $signedHash);
        } catch (Throwable $e) {
            error_log('Signed PDF generation failed: ' . $e->getMessage());
            Response::error('Signature recorded but signed PDF generation failed', 500);
        }

        return ['completed' => true, 'signed_pdf_path' => $signedPdfPath];
    }

    public static function decline(int $tenantId, int $requestId, array $party, ?string $reason): void {
        $req = SignatureRequestModel::find($requestId, $tenantId);
        if (!$req) {
            Response::fail('Signature request not found', 404);
        }
        if ($req['status'] !== 'pending') {
            Response::fail('Signature request already finalized', 409);
        }
        if ((int) $party['party_order'] !== (int) $req['current_party']) {
            Response::fail('Not your turn to decline', 409);
        }
        if ($party['status'] !== 'pending') {
            Response::fail('Party already acted', 409);
        }

        $db = Database::getInstance();
        $db->beginTransaction();

        try {
            SignaturePartyModel::markDeclined($tenantId, (int) $party['id'], $reason);
            SignatureRequestModel::setStatus($requestId, $tenantId, 'declined');
            $db->commit();
        } catch (Exception $e) {
            $db->rollBack();
            error_log('Signature decline failed: ' . $e->getMessage());
            Response::error('Failed to decline', 500);
        }
    }

    public static function void(int $tenantId, int $requestId, int $byAdminId): void {
        $req = SignatureRequestModel::find($requestId, $tenantId);
        if (!$req) {
            Response::fail('Signature request not found', 404);
        }
        if ($req['status'] !== 'pending') {
            Response::fail('Only pending requests can be voided', 409);
        }
        if ((int) $req['created_by'] !== $byAdminId) {
            $admin = AdminModel::findById($byAdminId, $tenantId);
            if (!$admin || $admin['role'] !== 'general_manager') {
                Response::forbidden('Only the creator or general manager can void');
            }
        }

        SignatureRequestModel::setStatus($requestId, $tenantId, 'voided');
    }

    public static function issueOtp(int $tenantId, int $requestId, array $party): void {
        if ($party['signer_type'] !== 'employee') {
            Response::fail('OTP is only available for employee signers', 422);
        }
        if (empty($party['signer_employee_id'])) {
            Response::fail('No employee linked to this party', 422);
        }

        $otp = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        $otpHash = password_hash($otp, PASSWORD_BCRYPT);
        $expiresAt = date('Y-m-d H:i:s', time() + 600);

        SignaturePartyModel::setOtp($tenantId, (int) $party['id'], $otpHash, $expiresAt);

        $req = Database::fetchOne(
            "SELECT * FROM signature_requests WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$requestId, $tenantId]
        );

        $title = $req['title'] ?? 'مستند';
        try {
            Database::execute(
                "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
                 VALUES (?, ?, 'general', 'Signature OTP', 'رمز التحقّق للتوقيع', ?, ?, ?, 'in_app', NOW())",
                [
                    $tenantId,
                    $party['signer_employee_id'],
                    'Your OTP to sign "' . $title . '" is: ' . $otp,
                    'رمز التحقّق لتوقيع "' . $title . '": ' . $otp,
                    json_encode(['signature_request_id' => $requestId, 'otp' => true]),
                ]
            );
        } catch (Exception $e) {
            error_log('OTP notification insert error: ' . $e->getMessage());
        }
    }

    private static function notifyParty(int $tenantId, array $party, ?array $request): void {
        if ($party['signer_type'] === 'employee' && !empty($party['signer_employee_id'])) {
            $title = $request['title'] ?? 'مستند';
            try {
                Database::execute(
                    "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
                     VALUES (?, ?, 'general', 'Signature Required', 'توقيع مطلوب', ?, ?, ?, 'in_app', NOW())",
                    [
                        $tenantId,
                        $party['signer_employee_id'],
                        'You are requested to sign "' . $title . '".',
                        'يُطلب منك توقيع "' . $title . '".',
                        json_encode(['signature_request_id' => $request['id'] ?? null]),
                    ]
                );
            } catch (Exception $e) {
                error_log('Signature notification error: ' . $e->getMessage());
            }
        }
    }

    private static function captureMeta(): array {
        return [
            'ip' => $_SERVER['REMOTE_ADDR'] ?? null,
            'ua' => $_SERVER['HTTP_USER_AGENT'] ?? null,
        ];
    }

    private static function saveDrawnSignature(int $tenantId, string $dataUrl, int $partyId): string {
        if (!preg_match('#^data:image/(png|jpeg);base64,(.+)$#i', $dataUrl, $m)) {
            Response::fail('Invalid signature image format. Only data:image/png or data:image/jpeg accepted.', 422);
        }

        $imageData = base64_decode($m[2], true);
        if ($imageData === false || strlen($imageData) > 1048576) {
            Response::fail('Signature image too large or invalid (max 1MB)', 422);
        }

        $info = @getimagesizefromstring($imageData);
        if ($info === false) {
            Response::fail('Signature data is not a valid image', 422);
        }

        $ext = strtolower($m[1]) === 'jpeg' ? 'jpg' : 'png';
        $outDir = __DIR__ . '/../uploads/signatures/' . $tenantId . '/';
        if (!is_dir($outDir) && !mkdir($outDir, 0755, true) && !is_dir($outDir)) {
            throw new RuntimeException('Failed to create signatures directory');
        }

        $fileName = 'sig_' . $partyId . '_' . time() . '.' . $ext;
        $filePath = $outDir . $fileName;

        if (file_put_contents($filePath, $imageData) === false) {
            throw new RuntimeException('Failed to save signature image');
        }

        return $filePath;
    }
}
