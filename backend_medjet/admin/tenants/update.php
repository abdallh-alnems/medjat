<?php
// Edit a client company from the support desk: its name, its locale settings,
// and the contact/notes fields that exist only for us.
//
// Only the fields actually present in the request are written. A support agent
// correcting a phone number must not silently reset a timezone they never saw.
require_once __DIR__ . '/../../config/bootstrap.php';

class TenantUpdateApi extends AdminBaseApi {
    protected ?string $minRole = 'admin';

    public function __construct() {
        parent::__construct();
        Auth::requirePost();

        $this->handleRequest(function () {
            $id = (int) $this->getField('id');
            if ($id <= 0) {
                $this->error('معرّف الشركة مطلوب', 422);
            }

            $tenant = Database::fetchOne("SELECT id, name FROM tenants WHERE id = ? LIMIT 1", [$id]);
            if (!$tenant) {
                $this->notFound('Tenant');
            }

            $updates = [];

            $name = $this->getField('name');
            if ($name !== null) {
                $name = trim((string) $name);
                if ($name === '') {
                    $this->error('اسم الشركة لا يمكن أن يكون فارغًا', 422);
                }
                $updates['name'] = $name;
            }

            $timezone = $this->getField('timezone');
            if ($timezone !== null && trim((string) $timezone) !== '') {
                $timezone = trim((string) $timezone);
                if (!in_array($timezone, timezone_identifiers_list(), true)) {
                    $this->error('المنطقة الزمنية غير صالحة', 422);
                }
                // Changing the zone by hand is always a deliberate choice, so it
                // also clears the "we guessed this" flag the settings screen reads.
                $updates['timezone'] = $timezone;
                $updates['timezone_is_explicit'] = 1;
            }

            $currency = $this->getField('currency');
            if ($currency !== null && trim((string) $currency) !== '') {
                $currency = strtoupper(trim((string) $currency));
                if (!preg_match('/^[A-Z]{3}$/', $currency)) {
                    $this->error('العملة يجب أن تكون رمزًا من 3 أحرف (مثل EGP)', 422);
                }
                $updates['currency'] = $currency;
            }

            $cycleStartDay = $this->getField('cycle_start_day');
            if ($cycleStartDay !== null && trim((string) $cycleStartDay) !== '') {
                $cycleStartDay = (int) $cycleStartDay;
                if ($cycleStartDay < 1 || $cycleStartDay > 28) {
                    $this->error('بداية دورة الحضور يجب أن تكون بين 1 و 28', 422);
                }
                $updates['cycle_start_day'] = $cycleStartDay;
            }

            $weekStartDay = $this->getField('week_start_day');
            if ($weekStartDay !== null && trim((string) $weekStartDay) !== '') {
                $weekStartDay = (int) $weekStartDay;
                if ($weekStartDay < 1 || $weekStartDay > 7) {
                    $this->error('بداية الأسبوع يجب أن تكون بين 1 (الاثنين) و 7 (الأحد)', 422);
                }
                $updates['week_start_day'] = $weekStartDay;
            }

            // Contact fields accept '' as "clear it" — unlike the settings above,
            // erasing a stale phone number is a normal support action.
            foreach (['contact_name', 'contact_email', 'contact_phone', 'ops_notes'] as $field) {
                $value = $this->getField($field);
                if ($value === null) {
                    continue;
                }
                $value = trim((string) $value);
                if ($field === 'contact_email' && $value !== '' && !filter_var($value, FILTER_VALIDATE_EMAIL)) {
                    $this->error('بريد جهة الاتصال غير صالح', 422);
                }
                $updates[$field] = $value === '' ? null : $value;
            }

            if (!$updates) {
                $this->error('لا يوجد ما يتم تحديثه', 422);
            }

            $sets = [];
            $values = [];
            foreach ($updates as $column => $value) {
                $sets[] = "`{$column}` = ?";
                $values[] = $value;
            }
            $values[] = $id;

            Database::execute(
                'UPDATE tenants SET ' . implode(', ', $sets) . ' WHERE id = ?',
                $values
            );

            AdminAuth::logAction('tenant.update', 'tenant', $id, array_keys($updates));

            $this->success([
                'tenant_id' => $id,
                'updated' => array_keys($updates),
            ]);
        }, 'admin.tenants.update');
    }
}

new TenantUpdateApi();
