<?php

final class PayrollFieldCatalog {
    public static function fields(): array {
        return [
            'employee_name'        => ['label' => 'اسم الموظف',          'resolve' => fn($r,$c) => (string)($r['employee_name'] ?? '')],
            'employee_id'          => ['label' => 'رقم الموظف',          'resolve' => fn($r,$c) => (string)($r['employee_id'] ?? '')],
            'national_id'          => ['label' => 'الرقم القومي/الهوية',  'resolve' => fn($r,$c) => (string)($r['national_id'] ?? '')],
            'iqama_number'         => ['label' => 'رقم الإقامة',         'resolve' => fn($r,$c) => (string)($r['iqama_number'] ?? '')],
            'nationality'          => ['label' => 'الجنسية',             'resolve' => fn($r,$c) => (string)($r['nationality'] ?? '')],
            'bank_name'            => ['label' => 'اسم البنك',           'resolve' => fn($r,$c) => (string)($r['bank_name'] ?? '')],
            'bank_account_number'  => ['label' => 'رقم الحساب',          'resolve' => fn($r,$c) => (string)($r['bank_account_number'] ?? '')],
            'bank_iban'            => ['label' => 'IBAN',                'resolve' => fn($r,$c) => (string)($r['bank_iban'] ?? '')],
            'bank_swift'           => ['label' => 'سويفت/رمز البنك',     'resolve' => fn($r,$c) => (string)($r['bank_swift'] ?? '')],
            'base_salary'          => ['label' => 'الراتب الأساسي',      'numeric' => true, 'resolve' => fn($r,$c) => (string)($r['base_salary'] ?? '0')],
            'total_bonuses'        => ['label' => 'إجمالي البدلات',      'numeric' => true, 'resolve' => fn($r,$c) => (string)($r['total_bonuses'] ?? '0')],
            'total_deductions'     => ['label' => 'إجمالي الخصومات',     'numeric' => true, 'resolve' => fn($r,$c) => (string)($r['total_deductions'] ?? '0')],
            'net_salary'           => ['label' => 'صافي الراتب',         'numeric' => true, 'resolve' => fn($r,$c) => (string)($r['net_salary'] ?? '0')],
            'working_days'         => ['label' => 'أيام العمل',          'resolve' => fn($r,$c) => (string)($r['working_days'] ?? '')],
            'currency'             => ['label' => 'العملة',              'resolve' => fn($r,$c) => $c->currency],
            'month'                => ['label' => 'الشهر',               'resolve' => fn($r,$c) => $c->month],
        ];
    }

    public static function has(string $key): bool {
        return isset(self::fields()[$key]);
    }

    public static function listForUi(): array {
        $out = [];
        foreach (self::fields() as $k => $def) {
            $out[] = ['key' => $k, 'label' => $def['label']];
        }
        return $out;
    }
}
