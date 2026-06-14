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
        return $out;
    }

    /**
     * يختار مُصدِّرًا. يرجّع null عند تعذّر إيجاد مُصدِّر مناسب
     * (مفتاح صريح غير موجود، أو دولة بلا مُصدِّر) — على المستدعي أن يرجع خطأً.
     */
    public static function resolve(?string $key, array $tenant): ?PayrollExporter {
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
