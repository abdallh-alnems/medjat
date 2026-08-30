<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$admin = AdminAuth::require('superadmin');

$result = RemoteConfigService::getAll();
Response::success($result);
