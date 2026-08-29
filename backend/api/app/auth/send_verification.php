<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    $input = [];
}

// Token may arrive in the body or in the X-Firebase-Token header (sent by the app's CRUD layer).
$token = $input['token']
    ?? $_SERVER['HTTP_X_FIREBASE_TOKEN']
    ?? null;
if (!$token) {
    Response::fail('Token is required', 400, 'token_required');
}

$lang = $input['lang'] ?? 'ar';
if (!in_array($lang, ['ar', 'en'], true)) {
    $lang = 'ar';
}

$verifiedToken = Auth::verifyFirebaseToken($token);
$email = $verifiedToken->claims()->get('email');
$emailVerified = (bool) $verifiedToken->claims()->get('email_verified');
$nameClaim = $verifiedToken->claims()->get('name');
$name = is_string($nameClaim) ? trim($nameClaim) : '';

if (!$email) {
    Response::fail('Account has no email address', 400, 'account_email_address');
}

// Already verified — nothing to send.
if ($emailVerified) {
    Response::success(['success' => true, 'already_verified' => true]);
}

// Generate the official Firebase verification link (the link opens Firebase's
// own default action page); we only deliver it inside our branded message.
try {
    $link = FirebaseInit::getAuth()->getEmailVerificationLink($email);
} catch (Exception $e) {
    error_log('send_verification: failed to generate link: ' . $e->getMessage());
    Response::fail('Failed to generate verification link', 500, 'failed_generate_verification_link');
}

// Route the verification action through our own branded page instead of
// Firebase's default handler (keeps mode/oobCode/apiKey/lang, swaps base URL).
$actionBase = getenv('APP_ACTION_URL') ?: 'https://medjatapp.com/auth-action.html';
$q = parse_url($link, PHP_URL_QUERY);
if ($actionBase !== '' && $q) {
    $link = $actionBase . (strpos($actionBase, '?') !== false ? '&' : '?') . $q;
}

$subject = AuthEmail::verifySubject($lang);
$html = AuthEmail::verifyHtml($lang, $name, $link);

$sent = EmailService::send($email, $subject, $html);
if (!$sent) {
    Response::fail('Failed to send verification email', 502, 'failed_send_verification_email');
}

Response::success(['success' => true]);
