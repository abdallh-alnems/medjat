<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$code = trim((string) ($_GET['code'] ?? ''));
if ($code === '') {
    Response::fail('code is required', 422);
}

$rec = SignatureRequestModel::findByVerifyCode($code);
if (!$rec || $rec['status'] !== 'completed') {
    Response::success(['valid' => false]);
}

Response::success([
    'valid' => true,
    'document' => $rec['title'],
    'completed_at' => $rec['completed_at'],
    'signers' => array_map(function ($p) {
        return [
            'name' => $p['signer_name'],
            'role' => $p['role_label'],
            'signed_at' => $p['signed_at'],
        ];
    }, $rec['signed_parties']),
]);
