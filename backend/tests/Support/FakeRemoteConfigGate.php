<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Shared\RemoteConfig\AppGate;
use App\Shared\RemoteConfig\RemoteConfigGate;

/**
 * Stands in for Firebase Remote Config in tests and in CI.
 *
 * Open by default, which is also the production failure mode: a configuration
 * outage must never stop a kiosk from recording attendance.
 */
final class FakeRemoteConfigGate implements RemoteConfigGate
{
    /** @var array<string, AppGate> */
    private array $gates = [];

    public function set(string $app, string $minVersion = '0.0.0', bool $maintenance = false, bool $stale = false): void
    {
        $this->gates[$app] = new AppGate($minVersion, $maintenance, $stale);
    }

    public function forApp(string $app): AppGate
    {
        return $this->gates[$app] ?? AppGate::open();
    }
}
