<?php

final class SignedPdfService {
    /**
     * Produces the final signed PDF and returns its absolute path.
     *
     * Integrity-preserving approach: the EXACT pages of the original unsigned
     * document (source_pdf_path — the same bytes the signer previewed) are
     * imported via FPDI, then a signatures + verification page is appended.
     * The document body is never re-rendered from live data, so the issue date
     * and employee fields cannot drift from what was actually signed.
     */
    public static function render(int $tenantId, array $signatureRequest, array $parties): string {
        if (!class_exists('\\Mpdf\\Mpdf')) {
            throw new RuntimeException('PDF engine not installed. Run: composer require mpdf/mpdf');
        }

        $sourcePath = $signatureRequest['source_pdf_path'] ?? null;
        if (empty($sourcePath) || !is_file($sourcePath)) {
            throw new RuntimeException('Source PDF not found for signing');
        }

        $outDir = __DIR__ . '/../uploads/signatures/' . $tenantId . '/';
        if (!is_dir($outDir) && !mkdir($outDir, 0755, true) && !is_dir($outDir)) {
            throw new RuntimeException('Failed to create signatures directory');
        }
        $tmpDir = __DIR__ . '/../uploads/.mpdf_tmp';
        if (!is_dir($tmpDir)) {
            @mkdir($tmpDir, 0755, true);
        }

        $mpdf = new \Mpdf\Mpdf([
            'mode' => 'utf-8',
            'format' => 'A4',
            'margin_left' => 20,
            'margin_right' => 20,
            'margin_top' => 25,
            'margin_bottom' => 20,
            'directionality' => 'rtl',
            'autoScriptToLang' => true,
            'autoLangToFont' => true,
            'tempDir' => $tmpDir,
        ]);
        $mpdf->SetTitle('مستند موقّع إلكترونيًا');

        // 1) Import every page of the original document, preserving its exact content.
        $pageCount = $mpdf->setSourceFile($sourcePath);
        for ($p = 1; $p <= $pageCount; $p++) {
            $tplId = $mpdf->importPage($p);
            $size = $mpdf->getTemplateSize($tplId);
            if ($p > 1) {
                $mpdf->AddPageByArray([
                    'orientation' => $size['orientation'] ?? 'P',
                    'newformat' => [$size['width'], $size['height']],
                ]);
            }
            // First page is implicit; place the imported page full-size on it.
            $mpdf->useTemplate($tplId);
        }

        // 2) Append the signatures + verification page (the only new content).
        $signaturesHtml = self::renderSignaturesBlock($parties);
        $footerHtml = self::renderVerificationFooter($signatureRequest);
        $mpdf->AddPageByArray(['orientation' => 'P', 'newformat' => 'A4']);
        $mpdf->WriteHTML(self::pageWrapper($signaturesHtml . $footerHtml));

        $fileName = 'signed_' . $signatureRequest['id'] . '_' . time() . '.pdf';
        $filePath = $outDir . $fileName;
        $mpdf->Output($filePath, \Mpdf\Output\Destination::FILE);

        return $filePath;
    }

    private static function pageWrapper(string $inner): string {
        return '<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<style>
  body { font-size: 13pt; line-height: 1.9; color: #1a1a1a; }
</style></head><body>' . $inner . '</body></html>';
    }

    private static function renderSignaturesBlock(array $parties): string {
        $html = '<div style="margin-top: 10px; border-top: 2px solid #333; padding-top: 15px;">
  <div style="text-align: center; font-size: 14pt; font-weight: bold; margin-bottom: 20px;">—— التواقيع الإلكترونية ——</div>
  <table style="width: 100%; border-collapse: collapse;">';

        foreach ($parties as $party) {
            if ($party['status'] !== 'signed') {
                continue;
            }
            $name = htmlspecialchars($party['signer_name'] ?? '—', ENT_QUOTES, 'UTF-8');
            $role = htmlspecialchars($party['role_label'] ?? '', ENT_QUOTES, 'UTF-8');
            $signedAt = $party['signed_at'] ?? '—';
            $method = $party['sign_method'] ?? '';
            $methodLabel = $method === 'drawn' ? 'توقيع باليد' : ($method === 'typed' ? 'اسم مكتوب' : ($method === 'otp' ? 'إقرار برمز OTP' : ''));

            $sigContent = '';
            if ($method === 'drawn' && !empty($party['signature_image_path'])) {
                $imgSrc = $party['signature_image_path'];
                if (is_file($imgSrc)) {
                    $sigContent = '<img src="' . $imgSrc . '" style="max-height: 70px;" />';
                }
            } elseif ($method === 'typed' && !empty($party['typed_name'])) {
                $sigContent = '<span style="font-family: serif; font-size: 16pt; font-style: italic;">' .
                    htmlspecialchars($party['typed_name'], ENT_QUOTES, 'UTF-8') . '</span>';
            } elseif ($method === 'otp') {
                $sigContent = '<span style="font-size: 10pt; color: #555;">✓ إقرار إلكتروني عبر رمز التحقق</span>';
            }

            $html .= '<tr>
    <td style="width: 50%; text-align: center; padding: 15px; border: 1px solid #ddd; vertical-align: bottom;">
      ' . $sigContent . '<br/>
      <span style="font-size: 11pt;">' . $name . '</span><br/>
      <span style="font-size: 9pt; color: #666;">' . $role . '</span>
    </td>
    <td style="width: 50%; text-align: center; padding: 15px; border: 1px solid #ddd; font-size: 10pt; color: #444;">
      ' . $methodLabel . '<br/>
      ' . htmlspecialchars($signedAt, ENT_QUOTES, 'UTF-8') . '<br/>
      <span style="font-size: 8pt; color: #888;">وقّع إلكترونيًا</span>
    </td>
  </tr>';
        }

        $html .= '</table></div>';
        return $html;
    }

    private static function renderVerificationFooter(array $request): string {
        $code = htmlspecialchars($request['verify_code'], ENT_QUOTES, 'UTF-8');
        $hashShort = htmlspecialchars(substr($request['source_hash'], 0, 12), ENT_QUOTES, 'UTF-8');

        return '<div style="margin-top: 30px; border-top: 1px dashed #999; padding-top: 10px; text-align: center; font-size: 9pt; color: #666;">
  رمز التحقّق: <strong>' . $code . '</strong> — بصمة المستند: <strong>' . $hashShort . '</strong>
</div>';
    }
}
