<?php

final class PayrollExporterRegistry {
    /** @return PayrollExporter[] خريطة key => instance */
    private static function all(): array {
        $list = [
            new EgyptGenericBankExporter(),
        ];
        $map = [];
        foreach ($list as $e) { $map[$e->key()] = $e; }
        return $map;
    }

    public static function availableFor(array $tenant): array {
        $country = $tenant['country_code'] ?? null;
        $out = [];
        foreach (self::all() as $key => $e) {
            if ($e->countryCode() === '*' || $e->countryCode() === $country) {
                $out[] = ['key' => $key, 'label' => $e->label(), 'extension' => $e->fileExtension()];
            }
        }
        foreach (PayrollExportTemplateModel::listActive((int)$tenant['id']) as $tpl) {
            $out[] = ['key' => 'custom_' . $tpl['id'], 'label' => $tpl['name'], 'extension' => 'csv'];
        }
        return $out;
    }

    /**
     * يختار مُصدِّرًا. يرجّع null عند تعذّر إيجاد مُصدِّر مناسب
     * (مفتاح صريح غير موجود، أو دولة بلا مُصدِّر) — على المستدعي أن يرجع خطأً.
     */
    public static function resolve(?string $key, array $tenant): ?PayrollExporter {
        if ($key !== null && str_starts_with($key, 'custom_')) {
            $id = (int) substr($key, 7);
            $tpl = PayrollExportTemplateModel::findById($id, (int)$tenant['id']);
            if ($tpl === null) { return null; }
            $tpl['columns'] = json_decode($tpl['columns'], true) ?: [];
            return new CustomTemplateExporter($tpl);
        }

        $all = self::all();

        // مفتاح صريح: يجب أن يطابق تمامًا، وإلا فشل (لا سقوط صامت)
        if ($key !== null && $key !== '') {
            return $all[$key] ?? null;
        }

        // بلا مفتاح: المُصدِّر الافتراضي لدولة الشركة.
        // null/فارغ يُعامل كـ EG حفاظًا على التوافق الخلفي (قبل تطبيق الهجرة).
        $country = $tenant['country_code'] ?? null;
        if ($country === null || $country === '') {
            $country = 'EG';
        }
        foreach ($all as $e) {
            if ($e->countryCode() === $country) { return $e; }
        }
        // مُصدِّرات عامة متاحة لكل الدول
        foreach ($all as $e) {
            if ($e->countryCode() === '*') { return $e; }
        }
        return null; // لا مُصدِّر لهذه الدولة
    }
}
