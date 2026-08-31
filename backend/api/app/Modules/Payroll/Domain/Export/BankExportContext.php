<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Domain\Export;

/**
 * Everything an exporter needs and nothing it does not: the payable rows, the
 * company they belong to, and the month and currency they are stated in.
 */
final readonly class BankExportContext
{
    /**
     * @param  list<array<string, mixed>>  $rows
     * @param  array<string, mixed>  $tenant
     */
    public function __construct(
        public array $rows,
        public array $tenant,
        public string $month,
        public string $currency,
    ) {}
}
