<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Medjat application settings
|--------------------------------------------------------------------------
|
| Values the old backend read straight from getenv() at the point of use.
| They live here instead because env() returns null once the configuration is
| cached in production, which turns a tuned limit into a silent default.
|
*/

return [

    'mail' => [
        // Our own branded action page, which enforces the app's password rules.
        // Firebase's query string is carried across unchanged, so switching this
        // needs no change in the Firebase console.
        'action_url' => (string) env('APP_ACTION_URL', 'https://medjatapp.com/auth-action.html'),
        'logo_url' => (string) env('APP_LOGO_URL', 'https://medjatapp.com/email-logo.png'),
    ],

    'firebase' => [
        // Service-account JSON. Owned by the server and never deployed, which
        // is why the path is configuration and not a file in the repo.
        'credentials_path' => (string) env('FIREBASE_CREDENTIALS_PATH', ''),
    ],

    'review_demo' => [
        // Google Play and the App Store need credentials a reviewer can reuse
        // indefinitely, which a single-use 24-hour activation code is not. Set
        // both to enable one fixed phone+code that signs into a designated
        // employee without consuming an activation row. Unset in production,
        // which makes the whole path inert there.
        'phone' => (string) env('REVIEW_DEMO_PHONE', ''),
        'code' => (string) env('REVIEW_DEMO_CODE', ''),
        // The permanent demo QR, so reviewers can also test the scan flow.
        'token' => (string) env('REVIEW_DEMO_TOKEN', ''),
    ],

    'rate_limit' => [
        // Requests per minute per IP. High on purpose: a branch punching in at
        // shift change shares one NAT address, so this stops a runaway client
        // rather than shaping normal traffic. Mirrors API_RATE_LIMIT.
        'per_minute' => (int) env('API_RATE_LIMIT', 600),
    ],

];
