<?php

declare(strict_types=1);

namespace App\Modules\Reports\Domain;

/**
 * Turning query-builder rows into plain arrays.
 *
 * Reports project their own columns rather than returning models, so this is
 * the one place that conversion lives instead of being repeated in every
 * report.
 */
final class Rows
{
    /**
     * @param  array<int, mixed>  $rows
     * @return list<array<string, mixed>>
     */
    public static function of(array $rows): array
    {
        return array_values(array_map(self::one(...), $rows));
    }

    /**
     * @return array<string, mixed>
     */
    public static function one(mixed $row): array
    {
        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }
}
