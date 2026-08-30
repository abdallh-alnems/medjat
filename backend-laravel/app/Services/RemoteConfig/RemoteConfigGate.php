<?php

declare(strict_types=1);

namespace App\Services\RemoteConfig;

/**
 * What the server knows about which client builds are still allowed to run.
 *
 * Behind an interface for the same reason the Firebase token verifier is: the
 * test suite and CI have no Firebase credentials, and a gate that cannot be
 * substituted would make every kiosk test depend on a network call to Google.
 */
interface RemoteConfigGate
{
    /**
     * The gate for one app, by its key: medjat_app, medjat_central,
     * medjat_kiosk.
     *
     * Implementations must fail open. A configuration outage must never stop
     * every kiosk in every company from recording attendance — the worst
     * outcome of an open gate is that an outdated build keeps working for a few
     * more minutes.
     */
    public function forApp(string $app): AppGate;
}
