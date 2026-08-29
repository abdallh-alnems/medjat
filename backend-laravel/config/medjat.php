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

    'rate_limit' => [
        // Requests per minute per IP. High on purpose: a branch punching in at
        // shift change shares one NAT address, so this stops a runaway client
        // rather than shaping normal traffic. Mirrors API_RATE_LIMIT.
        'per_minute' => (int) env('API_RATE_LIMIT', 600),
    ],

];
