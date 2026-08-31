<?php

declare(strict_types=1);

namespace App\Modules\Reports\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Support\Value;
use Illuminate\Http\Request;
use PhpOffice\PhpWord\IOFactory;
use PhpOffice\PhpWord\PhpWord;
use PhpOffice\PhpWord\Shared\Converter;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Port of api/app/reports/export_word.php.
 *
 * Renders a real .docx from a table the client already has on screen.
 *
 * Deliberately not a re-query. The client built those rows for the view, and
 * re-deriving them here would give two answers to the same question — a export
 * that disagrees with the screen it came from is worse than no export. It also
 * avoids Word's "format and extension don't match" warning, which is what
 * HTML-served-as-.doc produces.
 */
final class WordExportController
{
    /** Wider than this and the page is unreadable anyway. */
    private const MAX_COLUMNS = 40;

    /** A guard against a payload that would exhaust memory, not a product limit. */
    private const MAX_ROWS = 10000;

    public function __invoke(Request $request): StreamedResponse
    {
        $headers = $request->input('headers');
        $rows = $request->input('rows', []);

        if (! is_array($headers) || $headers === [] || ! is_array($rows)) {
            throw new ApiFailure('headers and rows are required', 422, 'headers_rows_required');
        }

        if (count($headers) > self::MAX_COLUMNS || count($rows) > self::MAX_ROWS) {
            throw new ApiFailure('Report too large to export', 413, 'report_too_large_export');
        }

        // Arabic unless told otherwise: these reports are read in Arabic, and a
        // table laid out left-to-right reverses the column order a reader
        // expects.
        $rtl = Value::string($request->input('dir'), 'rtl') !== 'ltr';

        $title = trim(Value::string($request->input('title'), 'Report')) ?: 'Report';

        $document = $this->render(
            $title,
            trim(Value::string($request->input('subtitle'))),
            trim(Value::string($request->input('company'))),
            array_values($headers),
            array_values($rows),
            $rtl,
        );

        return $this->stream($document, self::filename($title));
    }

    /**
     * @param  list<mixed>  $headers
     * @param  list<mixed>  $rows
     */
    private function render(
        string $title,
        string $subtitle,
        string $company,
        array $headers,
        array $rows,
        bool $rtl,
    ): PhpWord {
        $document = new PhpWord;
        $document->setDefaultFontName('Arial');
        $document->setDefaultFontSize(10);

        $section = $document->addSection([
            'marginTop' => Converter::cmToTwip(1.5),
            'marginBottom' => Converter::cmToTwip(1.5),
            'marginLeft' => Converter::cmToTwip(1.5),
            'marginRight' => Converter::cmToTwip(1.5),
        ]);

        $centred = ['alignment' => 'center', 'bidi' => $rtl];

        if ($company !== '') {
            $section->addText($company, ['bold' => true, 'size' => 14, 'rtl' => $rtl], $centred);
        }

        $section->addText($title, ['bold' => true, 'size' => 18, 'rtl' => $rtl], $centred);

        if ($subtitle !== '') {
            $section->addText($subtitle, ['size' => 11, 'color' => '666666', 'rtl' => $rtl], $centred);
        }

        $section->addTextBreak(1);

        $document->addTableStyle('reportTable', [
            'borderSize' => 6,
            'borderColor' => '999999',
            'cellMargin' => 60,
            // Renders the columns themselves right-to-left, not just the text
            // inside them.
            'bidiVisual' => $rtl,
        ]);

        $table = $section->addTable('reportTable');

        $table->addRow();

        foreach ($headers as $header) {
            $table->addCell(null, ['bgColor' => 'E8E8E8'])
                ->addText(Value::string($header), ['bold' => true, 'size' => 10, 'rtl' => $rtl], $centred);
        }

        foreach ($rows as $row) {
            if (! is_array($row)) {
                continue;
            }

            $cells = array_values($row);
            $table->addRow();

            // Driven by the headers, not by the row: a short row still produces
            // a full-width one, so the table cannot go ragged halfway down.
            foreach (array_keys($headers) as $index) {
                $table->addCell()
                    ->addText(Value::string($cells[$index] ?? null), ['size' => 9, 'rtl' => $rtl], $centred);
            }
        }

        return $document;
    }

    private function stream(PhpWord $document, string $filename): StreamedResponse
    {
        return new StreamedResponse(
            static function () use ($document): void {
                IOFactory::createWriter($document, 'Word2007')->save('php://output');
            },
            200,
            [
                'Content-Type' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                'Content-Disposition' => 'attachment; filename="'.$filename.'"',
                'Cache-Control' => 'max-age=0',
            ],
        );
    }

    /**
     * The title, reduced to what survives a filename.
     *
     * Letters and numbers in any script, so an Arabic report keeps an Arabic
     * name rather than becoming a row of underscores.
     */
    private static function filename(string $title): string
    {
        $safe = preg_replace('/[^\p{L}\p{N}_-]+/u', '_', $title);

        return ($safe === null || $safe === '' ? 'report' : $safe).'.docx';
    }
}
