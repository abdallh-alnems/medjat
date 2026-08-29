<?php

declare(strict_types=1);

namespace App\Domain\Payroll\Export;

/**
 * One bank's idea of what a salary transfer file looks like.
 *
 * There is no universal format — each bank, and often each country, wants its
 * own columns in its own order. Rather than one function full of country
 * branches, each format is its own small class and the registry picks one.
 */
interface BankExporter
{
    public function key(): string;

    public function label(): string;

    /** ISO country code, or '*' for a format that suits anywhere. */
    public function countryCode(): string;

    public function fileExtension(): string;

    public function mimeType(): string;

    /**
     * @param  resource  $output
     */
    public function write($output, BankExportContext $context): void;
}
