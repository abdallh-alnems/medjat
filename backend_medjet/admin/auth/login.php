<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true);
$username = $input['username'] ?? null;
$password = $input['password'] ?? null;

Validator::required($username, 'username');
Validator::required($password, 'password');

$ip = $_SERVER['REMOTE_ADDR'] ?? '';
$ua = $_SERVER['HTTP_USER_AGENT'] ?? '';

$result = AdminAuth::login($username, $password, $ip, $ua);

Response::success($result);
