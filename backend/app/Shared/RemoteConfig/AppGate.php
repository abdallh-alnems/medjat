<?php

declare(strict_types=1);

namespace App\Shared\RemoteConfig;

/**
 * The version and maintenance gate for one client app.
 */
final readonly class AppGate
{
    public function __construct(
        public string $minVersion,
        public bool $maintenance,
        /** True when this is the last known-good answer rather than a fresh one. */
        public bool $stale,
    ) {}

    public static function open(bool $stale = false): self
    {
        return new self('0.0.0', false, $stale);
    }

    public function isBelowMinimum(string $version): bool
    {
        return version_compare($version !== '' ? $version : '0.0.0', $this->minVersion ?: '0.0.0', '<');
    }
}
