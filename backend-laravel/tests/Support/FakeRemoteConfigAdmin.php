<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Services\RemoteConfig\RemoteConfigAdmin;

/**
 * An in-memory gate, so the app-control endpoints are testable without Firebase
 * credentials — and so a test can prove a publish failure surfaces rather than
 * being reported as success.
 */
final class FakeRemoteConfigAdmin implements RemoteConfigAdmin
{
    /** @var array<string, array{min_version: string, maintenance: bool}> */
    public array $state = [
        'medjat_app' => ['min_version' => '1.0.0', 'maintenance' => false],
        'medjat_central' => ['min_version' => '1.0.0', 'maintenance' => false],
        'medjat_kiosk' => ['min_version' => '1.0.0', 'maintenance' => false],
    ];

    /** @return list<array{key: string, name: string, min_version: string, maintenance: bool, supports_maintenance: bool}> */
    public function all(): array
    {
        $apps = [];

        foreach ($this->state as $key => $values) {
            $apps[] = [
                'key' => $key,
                'name' => $key,
                'min_version' => $values['min_version'],
                'maintenance' => $values['maintenance'],
                'supports_maintenance' => true,
            ];
        }

        return $apps;
    }

    /** @return array{app: string, min_version: string, previous_min_version: string} */
    public function setMinVersion(string $app, string $version): array
    {
        $previous = $this->state[$app]['min_version'];
        $this->state[$app]['min_version'] = $version;

        return ['app' => $app, 'min_version' => $version, 'previous_min_version' => $previous];
    }

    /** @return array{app: string, maintenance: bool, previous_maintenance: bool} */
    public function setMaintenance(string $app, bool $enabled): array
    {
        $previous = $this->state[$app]['maintenance'];
        $this->state[$app]['maintenance'] = $enabled;

        return ['app' => $app, 'maintenance' => $enabled, 'previous_maintenance' => $previous];
    }
}
