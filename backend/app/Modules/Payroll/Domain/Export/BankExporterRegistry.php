<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Domain\Export;

use App\Modules\Payroll\Domain\Export\Exporters\EgyptGenericBankExporter;
use App\Support\Value;

/**
 * Which transfer formats a company may use, and which one it gets by default.
 *
 * An explicitly named format must exist. There is no falling back to "whatever
 * else we have" — a company that asked for its own bank's layout and silently
 * received a different one would upload a file the bank rejects.
 */
final class BankExporterRegistry
{
    /**
     * @return array<string, BankExporter>
     */
    private static function all(): array
    {
        $exporters = [];

        foreach ([new EgyptGenericBankExporter] as $exporter) {
            $exporters[$exporter->key()] = $exporter;
        }

        return $exporters;
    }

    /**
     * @param  array<string, mixed>  $tenant
     * @return list<array{key: string, label: string, extension: string}>
     */
    public static function availableFor(array $tenant): array
    {
        $country = Value::nullableString($tenant['country_code'] ?? null);
        $available = [];

        foreach (self::all() as $key => $exporter) {
            if ($exporter->countryCode() === '*' || $exporter->countryCode() === $country) {
                $available[] = [
                    'key' => $key,
                    'label' => $exporter->label(),
                    'extension' => $exporter->fileExtension(),
                ];
            }
        }

        return $available;
    }

    /**
     * @param  array<string, mixed>  $tenant
     */
    public static function resolve(?string $key, array $tenant): ?BankExporter
    {
        $all = self::all();

        if ($key !== null && $key !== '') {
            return $all[$key] ?? null;
        }

        // Companies that predate the country column are treated as Egyptian,
        // which is where every one of them actually is.
        $country = Value::nullableString($tenant['country_code'] ?? null) ?: 'EG';

        foreach ($all as $exporter) {
            if ($exporter->countryCode() === $country) {
                return $exporter;
            }
        }

        foreach ($all as $exporter) {
            if ($exporter->countryCode() === '*') {
                return $exporter;
            }
        }

        return null;
    }
}
