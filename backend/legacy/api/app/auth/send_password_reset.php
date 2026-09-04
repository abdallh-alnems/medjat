<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    $input = [];
}

$email = isset($input['email']) ? trim(strtolower((string) $input['email'])) : '';
$lang = $input['lang'] ?? 'ar';
if (!in_array($lang, ['ar', 'en'], true)) {
    $lang = 'ar';
}

if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    Response::fail('Invalid email', 400, 'invalid_email');
}

// Email enumeration protection: never reveal whether the account exists.
// We always respond success; we only actually send if the user exists.
// The link opens Firebase's own default password-reset page.
try {
    $link = FirebaseInit::getAuth()->getPasswordResetLink($email);
    // Route the action through our own branded page (which enforces the app's
    // password rules) instead of Firebase's default handler. We keep Firebase's
    // query string (mode, oobCode, apiKey, lang) and only swap the base URL — no
    // Firebase Console action-URL change needed.
    $actionBase = getenv('APP_ACTION_URL') ?: 'https://permedjat.com/auth-action.html';
    $q = parse_url($link, PHP_URL_QUERY);
    if ($actionBase !== '' && $q) {
        $link = $actionBase . (strpos($actionBase, '?') !== false ? '&' : '?') . $q;
    }
    $subject = AuthEmail::resetSubject($lang);
    $html = AuthEmail::resetHtml($lang, '', $link);
    EmailService::send($email, $subject, $html);
} catch (\Throwable $e) {
    // user-not-found and similar are swallowed on purpose (no info leak).
    error_log('send_password_reset (silenced): ' . $e->getMessage());
}

Response::success(['success' => true]);
