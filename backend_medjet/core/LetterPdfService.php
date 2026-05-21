<?php

/**
 * Renders employee letters/certificates to a real PDF using mpdf.
 * Substitutes {{placeholders}} in a template body and stamps the document
 * with the company logo, signature and stamp configured in company settings.
 *
 * Requires: composer require mpdf/mpdf  (autoloaded via vendor/autoload.php)
 */
final class LetterPdfService {
    /** Build the {{placeholder}} => value map from tenant + employee + request extras. */
    public static function buildVariables(array $tenant, array $employee, array $extra): array {
        $currency = $tenant['currency'] ?? '';
        $baseSalary = isset($employee['base_salary']) ? (float) $employee['base_salary'] : 0.0;
        $nationalId = $employee['national_id'] ?: ($employee['iqama_number'] ?? '');

        return [
            'company_name'        => self::clean($tenant['name'] ?? ''),
            'commercial_register' => self::clean($tenant['commercial_register'] ?? ''),
            'company_address'     => self::clean($tenant['company_address'] ?? ''),
            'company_phone'       => self::clean($tenant['company_phone'] ?? ''),
            'employee_name'       => self::clean($employee['name'] ?? ''),
            'employee_code'       => self::clean($employee['employee_code'] ?? ''),
            'job_title'           => self::clean($employee['job_title'] ?? '—'),
            'department'          => self::clean($employee['department'] ?? '—'),
            'national_id'         => self::clean($nationalId),
            'iqama_number'        => self::clean($employee['iqama_number'] ?? ''),
            'nationality'         => self::clean($employee['nationality'] ?? ''),
            'branch_name'         => self::clean($employee['branch_name'] ?? '—'),
            'hire_date'           => self::clean($employee['hire_date'] ?? '—'),
            'contract_type'       => self::clean($employee['contract_type'] ?? ''),
            'base_salary'         => number_format($baseSalary, 2),
            'currency'            => self::clean($currency),
            'date_today'          => date('Y-m-d'),
            // From request extra_fields (used by bank letter and custom templates)
            'bank_name'           => self::clean($extra['bank_name'] ?? ''),
            'addressed_to'        => self::clean($extra['addressed_to'] ?? ''),
        ];
    }

    /** List of placeholders the UI can offer; keep in sync with buildVariables(). */
    public static function availableVariables(): array {
        return [
            'company_name', 'commercial_register', 'company_address', 'company_phone',
            'employee_name', 'employee_code', 'job_title', 'department',
            'national_id', 'iqama_number', 'nationality', 'branch_name',
            'hire_date', 'contract_type', 'base_salary', 'currency', 'date_today',
            'bank_name', 'addressed_to',
        ];
    }

    public static function substitute(string $body, array $vars): string {
        return preg_replace_callback('/\{\{\s*([a-z_]+)\s*\}\}/i', function ($m) use ($vars) {
            $key = $m[1];
            return array_key_exists($key, $vars) ? $vars[$key] : '';
        }, $body);
    }

    /**
     * Generate the PDF and return its absolute filesystem path.
     *
     * @throws RuntimeException if mpdf is unavailable or rendering fails.
     */
    public static function generate(array $tenant, array $employee, array $template, array $extra, int $requestId): string {
        if (!class_exists('\\Mpdf\\Mpdf')) {
            throw new RuntimeException('PDF engine not installed. Run: composer require mpdf/mpdf');
        }

        $vars = self::buildVariables($tenant, $employee, $extra);
        $titleAr = $template['name_ar'] ?? 'خطاب';
        $bodyText = self::substitute($template['body_ar'] ?? '', $vars);

        $html = self::renderHtml($tenant, $titleAr, $bodyText, $vars);

        $tenantId = (int) ($tenant['id'] ?? 0);
        $outDir = __DIR__ . '/../uploads/letters/' . $tenantId . '/';
        if (!is_dir($outDir) && !mkdir($outDir, 0755, true) && !is_dir($outDir)) {
            throw new RuntimeException('Failed to create letters directory');
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
        $mpdf->SetTitle($titleAr);
        $mpdf->WriteHTML($html);

        $fileName = 'letter_' . $requestId . '_' . time() . '.pdf';
        $filePath = $outDir . $fileName;
        $mpdf->Output($filePath, \Mpdf\Output\Destination::FILE);

        return $filePath;
    }

    /**
     * Loads everything for a stored request and generates the PDF.
     * Returns the absolute PDF path. Throws on missing template/employee.
     */
    public static function generateForRequest(array $request, int $tenantId): string {
        $tenant = TenantModel::findById($tenantId);
        if (!$tenant) {
            throw new RuntimeException('Tenant not found');
        }

        $employee = Database::fetchOne(
            "SELECT e.*, b.name AS branch_name
             FROM employees e
             LEFT JOIN branches b ON b.id = e.branch_id
             WHERE e.id = ? AND e.tenant_id = ? LIMIT 1",
            [(int) $request['employee_id'], $tenantId]
        );
        if (!$employee) {
            throw new RuntimeException('Employee not found');
        }

        $template = null;
        if (!empty($request['template_id'])) {
            $template = DocumentTemplateModel::find((int) $request['template_id'], $tenantId);
        }
        if (!$template) {
            throw new RuntimeException('Template not found');
        }

        $extra = DocumentRequestModel::decodeExtra($request['extra_fields'] ?? null);

        return self::generate($tenant, $employee, $template, $extra, (int) $request['id']);
    }

    private static function renderHtml(array $tenant, string $title, string $body, array $vars): string {
        $logo = self::imageTag($tenant['logo_url'] ?? null, 90);
        $stamp = self::imageSrc($tenant['stamp_url'] ?? null);
        $signature = self::imageSrc($tenant['signature_url'] ?? null);

        $companyName = htmlspecialchars($vars['company_name'], ENT_QUOTES, 'UTF-8');
        $crLine = $vars['commercial_register'] !== ''
            ? 'سجل تجاري: ' . htmlspecialchars($vars['commercial_register'], ENT_QUOTES, 'UTF-8')
            : '';
        $addressLine = trim(
            htmlspecialchars($vars['company_address'], ENT_QUOTES, 'UTF-8') .
            ($vars['company_phone'] !== '' ? ' — هاتف: ' . htmlspecialchars($vars['company_phone'], ENT_QUOTES, 'UTF-8') : '')
        );
        $dateLine = 'التاريخ: ' . htmlspecialchars($vars['date_today'], ENT_QUOTES, 'UTF-8');
        $bodyHtml = nl2br(htmlspecialchars($body, ENT_QUOTES, 'UTF-8'));
        $titleHtml = htmlspecialchars($title, ENT_QUOTES, 'UTF-8');

        $signatureBlock = '';
        if ($signature !== null) {
            $signatureBlock .= '<img src="' . $signature . '" style="height:60px;" /><br/>';
        }
        $signatureBlock .= 'التوقيع المعتمد';

        $stampBlock = $stamp !== null
            ? '<img src="' . $stamp . '" style="height:110px;" />'
            : '';

        return '<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<style>
  body { font-size: 13pt; line-height: 1.9; color: #1a1a1a; }
  .header { text-align: center; border-bottom: 2px solid #333; padding-bottom: 10px; margin-bottom: 6px; }
  .company { font-size: 18pt; font-weight: bold; }
  .meta { font-size: 10pt; color: #555; }
  .date { font-size: 11pt; color: #333; margin: 14px 0 18px; text-align: left; }
  .title { text-align: center; font-size: 16pt; font-weight: bold; text-decoration: underline; margin: 10px 0 22px; }
  .body { text-align: justify; }
  .sign-row { width: 100%; margin-top: 60px; }
  .sign-cell { width: 50%; text-align: center; font-size: 11pt; vertical-align: bottom; }
</style></head><body>
  <div class="header">
    ' . $logo . '
    <div class="company">' . $companyName . '</div>
    ' . ($crLine !== '' ? '<div class="meta">' . $crLine . '</div>' : '') . '
    ' . ($addressLine !== '' ? '<div class="meta">' . $addressLine . '</div>' : '') . '
  </div>
  <div class="date">' . $dateLine . '</div>
  <div class="title">' . $titleHtml . '</div>
  <div class="body">' . $bodyHtml . '</div>
  <table class="sign-row"><tr>
    <td class="sign-cell">' . $signatureBlock . '</td>
    <td class="sign-cell">' . $stampBlock . '</td>
  </tr></table>
</body></html>';
    }

    /** Returns an <img> tag for an optional image, or '' if unavailable. */
    private static function imageTag(?string $stored, int $maxHeight): string {
        $src = self::imageSrc($stored);
        if ($src === null) {
            return '';
        }
        return '<img src="' . $src . '" style="max-height:' . $maxHeight . 'px; margin-bottom:6px;" />';
    }

    /** Resolves a stored image (absolute path or http URL) to an mpdf-usable src. */
    private static function imageSrc(?string $stored): ?string {
        if (empty($stored)) {
            return null;
        }
        if (is_file($stored)) {
            return $stored;
        }
        if (preg_match('#^https?://#i', $stored)) {
            return $stored;
        }
        // Relative path stored under the project root.
        $candidate = __DIR__ . '/../' . ltrim($stored, '/');
        return is_file($candidate) ? $candidate : null;
    }

    private static function clean($value): string {
        return is_string($value) ? trim($value) : (string) $value;
    }
}
