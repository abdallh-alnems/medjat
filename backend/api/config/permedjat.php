<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Permedjat application settings
|--------------------------------------------------------------------------
|
| Values the old backend read straight from getenv() at the point of use.
| They live here instead because env() returns null once the configuration is
| cached in production, which turns a tuned limit into a silent default.
|
*/

return [

    'uploads' => [
        // Identity documents and contracts. Deliberately narrow: anything that
        // is not one of these is either a mistake or an attempt to store
        // something executable behind a document name.
        'allowed_types' => explode(',', (string) env('UPLOAD_ALLOWED_TYPES', 'jpg,jpeg,png,pdf')),
        'max_bytes' => (int) env('UPLOAD_MAX_SIZE', 5242880),
    ],

    'app_secret' => [
        // The HTTP Basic credential the published app bundles carry. Unset
        // disables the gate, which is how local development runs — the
        // alternative makes a fresh checkout answer 401 to everything.
        'user' => (string) env('SECURITY_USER', ''),
        'key' => (string) env('SECURITY_KEY', ''),
    ],

    'cron' => [
        // The shared secret the scheduled jobs authenticate with. No default:
        // an empty secret must refuse every request rather than accept one,
        // since these endpoints terminate employees and delete photographs.
        'secret' => (string) env('CRON_SECRET', ''),
    ],

    'web' => [
        // Where the management web app lives, for links the panel hands an
        // operator (impersonation, and anything else that opens a real session).
        'base_url' => (string) env('CENTRAL_WEB_URL', 'https://app.permedjat.com'),
    ],

    'stores' => [
        // Where a visitor without the app is sent. Per app, because the
        // employee app and the management app are separate listings.
        'employee_android' => (string) env('STORE_URL_EMPLOYEE_ANDROID',
            'https://play.google.com/store/apps/details?id=com.khawarizmie.permedjat'),
        'employee_ios' => (string) env('STORE_URL_EMPLOYEE_IOS', ''),
        'central_android' => (string) env('STORE_URL_CENTRAL_ANDROID',
            'https://play.google.com/store/apps/details?id=com.khawarizmie.permedjat_central'),
        'central_ios' => (string) env('STORE_URL_CENTRAL_IOS', ''),
    ],

    'join' => [
        // Must be a domain that hosts the App Links / Universal Links association
        // files, or the link opens a web page instead of the app.
        'base_url' => (string) env('APP_JOIN_BASE_URL', 'https://permedjat.com'),
    ],

    'mail' => [
        // Our own branded action page, which enforces the app's password rules.
        // Firebase's query string is carried across unchanged, so switching this
        // needs no change in the Firebase console.
        'action_url' => (string) env('APP_ACTION_URL', 'https://permedjat.com/auth-action.html'),
        'logo_url' => (string) env('APP_LOGO_URL', 'https://permedjat.com/email-logo.png'),
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
