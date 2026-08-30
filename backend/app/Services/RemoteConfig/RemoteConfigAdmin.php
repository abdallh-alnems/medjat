<?php

declare(strict_types=1);

namespace App\Services\RemoteConfig;

/**
 * Reading and changing the gate, for the panel that operates it.
 *
 * Separate from RemoteConfigGate, which every request consults, because the two
 * want opposite things. The gate is cached and fails open — an outage must not
 * take every kiosk out of service. This one is uncached and fails loudly: an
 * operator who presses "enable maintenance" and is told it worked, when it did
 * not, will not press it again.
 *
 * An interface for the same reason as the gate: CI has no Firebase credentials.
 */
interface RemoteConfigAdmin
{
    /**
     * Every app the panel can operate, whether or not one has been configured.
     *
     * @return list<array{key: string, name: string, min_version: string, maintenance: bool, supports_maintenance: bool}>
     */
    public function all(): array;

    /**
     * @return array{app: string, min_version: string, previous_min_version: string}
     */
    public function setMinVersion(string $app, string $version): array;

    /**
     * @return array{app: string, maintenance: bool, previous_maintenance: bool}
     */
    public function setMaintenance(string $app, bool $enabled): array;
}
