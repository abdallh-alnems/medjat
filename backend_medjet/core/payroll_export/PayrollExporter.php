<?php

interface PayrollExporter {
    public function key(): string;

    public function label(): string;

    public function countryCode(): string;

    public function fileExtension(): string;

    /** نوع MIME للملف الناتج، مثل 'text/csv; charset=utf-8' */
    public function mimeType(): string;

    public function write($output, PayrollExportContext $context): void;
}
