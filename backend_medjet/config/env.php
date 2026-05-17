<?php

define('DB_DSN', getenv('DB_DSN') ?: 'mysql:host=localhost;port=8889;dbname=medjat;charset=utf8mb4');
define('DB_USER', getenv('DB_USER') ?: 'root');
define('DB_PASS', getenv('DB_PASS') ?: 'root');

define('API_VERSION', '1.0');
define('API_RATE_LIMIT', 100);
define('API_RATE_WINDOW', 3600);

define('CORS_ALLOWED_ORIGINS', getenv('CORS_ALLOWED_ORIGINS') ?: '');
define('CORS_ALLOWED_METHODS', 'GET,POST,PUT,DELETE,OPTIONS');
define('CORS_ALLOWED_HEADERS', 'Content-Type,Authorization,X-Requested-With,X-Tenant-Id');

$envKeys = [
    'JWT_SECRET',
    'OTP_HMAC_SECRET',
    'OTP_EXPIRY_MINUTES',
    'OTP_MAX_ATTEMPTS',
    'OTP_RESEND_MAX',
    'OTP_LOCKOUT_MINUTES',
    'WASENDER_API_KEY',
    'WASENDER_API_URL',
    'UPLOAD_MAX_SIZE',
    'UPLOAD_ALLOWED_TYPES',
    'PAYMOB_API_KEY',
    'PAYMOB_INTEGRATION_ID',
    'S3_KEY',
    'S3_SECRET',
    'S3_BUCKET',
    'S3_REGION',
];

$defaults = [
    'JWT_SECRET' => 'change_this_to_a_random_64_char_hex_secret',
    'OTP_HMAC_SECRET' => 'change_this_to_a_random_64_char_hex_secret',
    'OTP_EXPIRY_MINUTES' => '10',
    'OTP_MAX_ATTEMPTS' => '5',
    'OTP_RESEND_MAX' => '3',
    'OTP_LOCKOUT_MINUTES' => '15',
    'WASENDER_API_KEY' => '',
    'WASENDER_API_URL' => 'https://wasenderapi.com/api/send-message',
    'UPLOAD_MAX_SIZE' => '10485760',
    'UPLOAD_ALLOWED_TYPES' => 'jpg,jpeg,png,pdf',
    'PAYMOB_API_KEY' => '',
    'PAYMOB_INTEGRATION_ID' => '',
    'S3_KEY' => '',
    'S3_SECRET' => '',
    'S3_BUCKET' => 'medjat-documents',
    'S3_REGION' => 'me-south-1',
];

foreach ($envKeys as $key) {
    if (getenv($key) === false && isset($defaults[$key])) {
        putenv("{$key}={$defaults[$key]}");
    }
}

$requiredKeys = ['JWT_SECRET'];
foreach ($requiredKeys as $key) {
    if (getenv($key) === false || getenv($key) === '') {
        error_log("WARNING: {$key} is not set.");
    }
}
