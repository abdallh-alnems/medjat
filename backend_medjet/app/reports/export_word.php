<?php

/**
 * Generates a real Word (.docx) file from report data supplied by the client.
 *
 * The client already builds the report rows for the on-screen view, so instead
 * of re-querying per report type we accept the finished table and render it
 * with PhpWord. This keeps a single source of truth for the figures and avoids
 * the "format & extension don't match" warning of HTML-as-.doc exports.
 *
 * POST JSON: { title, subtitle?, company?, headers: [..], rows: [[..], ..], dir? }
 * Response : binary .docx (Word2007) as an attachment.
 */

require_once __DIR__ . '/../../config/bootstrap.php';

use PhpOffice\PhpWord\PhpWord;
use PhpOffice\PhpWord\IOFactory;
use PhpOffice\PhpWord\Shared\Converter;

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'view_reports');

$input = json_decode(file_get_contents('php://input'), true) ?: [];

$title = trim((string) ($input['title'] ?? 'Report'));
$subtitle = trim((string) ($input['subtitle'] ?? ''));
$company = trim((string) ($input['company'] ?? ''));
$dir = ($input['dir'] ?? 'rtl') === 'ltr' ? 'ltr' : 'rtl';
$headers = $input['headers'] ?? [];
$rows = $input['rows'] ?? [];

if (!is_array($headers) || count($headers) === 0 || !is_array($rows)) {
    Response::fail('headers and rows are required', 422);
}
// Guard against abusive payloads.
if (count($headers) > 40 || count($rows) > 10000) {
    Response::fail('Report too large to export', 413);
}

$isRtl = $dir === 'rtl';

$phpWord = new PhpWord();
$phpWord->setDefaultFontName('Arial');
$phpWord->setDefaultFontSize(10);

$section = $phpWord->addSection([
    'marginTop'    => Converter::cmToTwip(1.5),
    'marginBottom' => Converter::cmToTwip(1.5),
    'marginLeft'   => Converter::cmToTwip(1.5),
    'marginRight'  => Converter::cmToTwip(1.5),
]);

$centerPara = ['alignment' => 'center', 'bidi' => $isRtl];

if ($company !== '') {
    $section->addText($company, ['bold' => true, 'size' => 14, 'rtl' => $isRtl], $centerPara);
}
$section->addText($title, ['bold' => true, 'size' => 18, 'rtl' => $isRtl], $centerPara);
if ($subtitle !== '') {
    $section->addText($subtitle, ['size' => 11, 'color' => '666666', 'rtl' => $isRtl], $centerPara);
}
$section->addTextBreak(1);

$tableStyle = [
    'borderSize'  => 6,
    'borderColor' => '999999',
    'cellMargin'  => 60,
    'bidiVisual'  => $isRtl, // render columns right-to-left for Arabic
];
$phpWord->addTableStyle('reportTable', $tableStyle);
$table = $section->addTable('reportTable');

$cellPara = ['alignment' => 'center', 'bidi' => $isRtl];

// Header row.
$table->addRow();
foreach ($headers as $h) {
    $cell = $table->addCell(null, ['bgColor' => 'E8E8E8']);
    $cell->addText((string) $h, ['bold' => true, 'size' => 10, 'rtl' => $isRtl], $cellPara);
}

// Data rows.
foreach ($rows as $row) {
    if (!is_array($row)) {
        continue;
    }
    $table->addRow();
    foreach ($headers as $i => $_) {
        $value = isset($row[$i]) ? (string) $row[$i] : '';
        $cell = $table->addCell();
        $cell->addText($value, ['size' => 9, 'rtl' => $isRtl], $cellPara);
    }
}

$safeName = preg_replace('/[^\p{L}\p{N}_-]+/u', '_', $title);
if ($safeName === '' || $safeName === null) {
    $safeName = 'report';
}

header('Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document');
header('Content-Disposition: attachment; filename="' . $safeName . '.docx"');
header('Cache-Control: max-age=0');

$writer = IOFactory::createWriter($phpWord, 'Word2007');
$writer->save('php://output');
exit;
