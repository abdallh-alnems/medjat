<?php

final class PayrollExportContext {
    /** @var array صفوف الرواتب الجاهزة (التي لها حساب بنكي) من getApprovedForBankFile */
    public array $rows;
    /** @var array بيانات الشركة من TenantModel::findById() */
    public array $tenant;
    /** @var string الشهر YYYY-MM */
    public string $month;
    /** @var string العملة الفعلية (من tenant) */
    public string $currency;

    public function __construct(array $rows, array $tenant, string $month, string $currency) {
        $this->rows = $rows;
        $this->tenant = $tenant;
        $this->month = $month;
        $this->currency = $currency;
    }
}
