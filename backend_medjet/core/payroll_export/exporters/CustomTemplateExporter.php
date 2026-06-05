<?php

final class CustomTemplateExporter implements PayrollExporter {
    private array $template;

    public function __construct(array $template) {
        $this->template = $template;
    }

    public function key(): string { return 'custom_' . (int)$this->template['id']; }
    public function label(): string { return (string)$this->template['name']; }
    public function countryCode(): string { return '*'; }
    public function fileExtension(): string { return 'csv'; }
    public function mimeType(): string { return 'text/csv; charset=utf-8'; }

    public function write($output, PayrollExportContext $ctx): void {
        $cols = $this->template['columns'];
        $delimiter = $this->template['delimiter'] ?: ',';
        $decimals = (int)($this->template['decimal_places'] ?? 2);
        $catalog = PayrollFieldCatalog::fields();

        if (!empty($this->template['include_bom'])) {
            fputs($output, "\xEF\xBB\xBF");
        }
        if (!empty($this->template['include_header_row'])) {
            $headers = array_map(fn($c) => (string)$c['label'], $cols);
            fputcsv($output, $headers, $delimiter, '"', '');
        }
        foreach ($ctx->rows as $row) {
            $line = [];
            foreach ($cols as $c) {
                $field = $c['field'] ?? '';
                if (!isset($catalog[$field])) { $line[] = ''; continue; }
                $def = $catalog[$field];
                $val = ($def['resolve'])($row, $ctx);
                if (!empty($def['numeric'])) {
                    $val = number_format((float)$val, $decimals, '.', '');
                }
                $line[] = $val;
            }
            fputcsv($output, $line, $delimiter, '"', '');
        }
    }
}
