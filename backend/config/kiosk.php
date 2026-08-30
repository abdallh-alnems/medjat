<?php

declare(strict_types=1);

return [
    /*
     * Server-side pepper for kiosk fallback codes.
     *
     * The codes are looked up by hash rather than verified one at a time, so
     * they cannot be salted per row. The pepper is what stops a dump of the
     * employees table from being brute-forced back to working codes: an
     * attacker needs the application's secret as well. Falls back to the app
     * key when unset, so a missing value degrades to "still peppered" rather
     * than to plaintext.
     */
    'code_pepper' => env('KIOSK_CODE_PEPPER'),
];
