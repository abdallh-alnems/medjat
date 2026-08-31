<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Cross-origin requests
|--------------------------------------------------------------------------
|
| Only the browser surfaces need this — the Flutter apps and the attendance
| terminals are not browsers and never send an Origin. It exists for the web
| port, the desktop shell that wraps it, and the employee browser channel.
|
| The allow-list comes from the environment and is empty by default, which
| denies every cross-origin request. That is the right default for an API
| holding payroll: a permissive one would let any page on the internet make
| authenticated requests from a signed-in employee's browser.
|
*/

return [

    'paths' => ['*'],

    'allowed_methods' => ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],

    'allowed_origins' => array_values(array_filter(
        array_map('trim', explode(',', (string) env('CORS_ALLOWED_ORIGINS', '')))
    )),

    'allowed_origins_patterns' => [],

    // The headers the clients actually send: the app secret and the session
    // tokens ride in Authorization and the X-* headers below.
    'allowed_headers' => [
        'Content-Type',
        'Authorization',
        'X-Requested-With',
        'X-Tenant-Id',
        'X-Firebase-Token',
        'X-Employee-Token',
        'X-Kiosk-Token',
        'X-Device-Id',
        'X-Cron-Secret',
    ],

    'exposed_headers' => [],

    'max_age' => 0,

    // False, and deliberately: every surface authenticates with a token in a
    // header, not a cookie. Allowing credentials would also forbid the '*'
    // origin, and buys nothing that is used.
    'supports_credentials' => false,

];
