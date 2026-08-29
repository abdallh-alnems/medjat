<?php
http_response_code((int) ($_GET['code'] ?? 500));
header('Content-Type: application/json; charset=utf-8');
echo json_encode([
    'status' => 'error',
    'code' => (int) ($_GET['code'] ?? 500),
    'message' => [
        400 => 'Bad Request',
        401 => 'Unauthorized',
        403 => 'Forbidden',
        404 => 'Not Found',
        429 => 'Too Many Requests',
        500 => 'Internal Server Error',
    ][(int) ($_GET['code'] ?? 500)] ?? 'Error',
], JSON_UNESCAPED_UNICODE);
