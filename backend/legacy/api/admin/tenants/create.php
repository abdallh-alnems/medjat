<?php
// Onboard a new client company from the super-admin panel.
//
// This is the one path where WE create a company rather than the customer
// signing themselves up through app/tenant/create.php. The difference matters:
// there, the caller is already a signed-in Firebase user and simply becomes the
// company's general_manager. Here there is no such user — a super admin has no
// row in `admins` at all — so the company would be born with nobody able to log
// into it. That is exactly what used to happen: the panel collected the owner's
// name, email and phone, sent them, and this endpoint dropped them on the floor
// because it only ever read `name`.
//
// So onboarding is two things in one transaction: the tenant row, and a pending
// general_manager invitation for the owner's email. The owner signs up (or
// signs in) with that email and redeems the code — the same flow, the same
// email and the same 72-hour window as a colleague-to-colleague invite.
require_once __DIR__ . '/../../../config/bootstrap.php';

class TenantCreateApi extends AdminBaseApi {
    protected ?string $minRole = 'superadmin';

    public function __construct() {
        parent::__construct();
        Auth::requirePost();

        $this->handleRequest(function () {
            $name = trim((string) $this->getField('name', ''));
            if ($name === '') {
                $this->error('اسم الشركة مطلوب', 422);
            }

            // Locale settings — all optional, all falling back to the column
            // defaults, mirroring app/tenant/create.php so a company created
            // from the panel is indistinguishable from a self-signup.
            $timezone = $this->trimOrNull($this->getField('timezone'));
            if ($timezone !== null && !in_array($timezone, timezone_identifiers_list(), true)) {
                $this->error('المنطقة الزمنية غير صالحة', 422);
            }

            $currency = $this->trimOrNull($this->getField('currency'));
            if ($currency !== null) {
                $currency = strtoupper($currency);
                if (!preg_match('/^[A-Z]{3}$/', $currency)) {
                    $this->error('العملة يجب أن تكون رمزًا من 3 أحرف (مثل EGP)', 422);
                }
            }

            $cycleStartDay = $this->trimOrNull($this->getField('cycle_start_day'));
            if ($cycleStartDay !== null) {
                $cycleStartDay = (int) $cycleStartDay;
                if ($cycleStartDay < 1 || $cycleStartDay > 28) {
                    $this->error('بداية دورة الحضور يجب أن تكون بين 1 و 28', 422);
                }
            }

            $weekStartDay = $this->trimOrNull($this->getField('week_start_day'));
            if ($weekStartDay !== null) {
                $weekStartDay = (int) $weekStartDay;
                if ($weekStartDay < 1 || $weekStartDay > 7) {
                    $this->error('بداية الأسبوع يجب أن تكون بين 1 (الاثنين) و 7 (الأحد)', 422);
                }
            }

            // Who we call about this account. Kept even when no invitation is
            // sent — a company onboarded over the phone still needs a contact.
            $contactName = $this->trimOrNull($this->getField('contact_name'));
            $contactPhone = $this->trimOrNull($this->getField('contact_phone'));
            $contactEmail = $this->trimOrNull($this->getField('contact_email'));
            $opsNotes = $this->trimOrNull($this->getField('ops_notes'));
            if ($contactEmail !== null && !filter_var($contactEmail, FILTER_VALIDATE_EMAIL)) {
                $this->error('بريد جهة الاتصال غير صالح', 422);
            }

            // The owner invitation. Optional: a company can be created first and
            // its manager invited later from the company screen.
            $ownerEmail = $this->trimOrNull($this->getField('owner_email'));
            $ownerName = $this->trimOrNull($this->getField('owner_name')) ?? $contactName ?? '';
            if ($ownerEmail !== null) {
                if (!filter_var($ownerEmail, FILTER_VALIDATE_EMAIL)) {
                    $this->error('بريد المالك غير صالح', 422);
                }
                // Someone already inside another company cannot be handed a
                // second one — same guard as app/managers/invite.php.
                $existing = Database::fetchOne(
                    "SELECT id, tenant_id FROM admins WHERE email = ? LIMIT 1",
                    [$ownerEmail]
                );
                if ($existing && $existing['tenant_id']) {
                    $this->error('هذا البريد ينتمي لشركة أخرى بالفعل', 409);
                }
            }

            $pdo = db();
            $invitation = null;
            try {
                $pdo->beginTransaction();

                $columns = ['name', 'is_active', 'email_verified_at'];
                $placeholders = ['?', '1', 'NOW()'];
                $values = [$name];

                if ($timezone !== null) {
                    $columns[] = 'timezone';
                    $placeholders[] = '?';
                    $values[] = $timezone;
                    $columns[] = 'timezone_is_explicit';
                    $placeholders[] = '1';
                }
                foreach ([
                    'currency' => $currency,
                    'cycle_start_day' => $cycleStartDay,
                    'week_start_day' => $weekStartDay,
                    'contact_name' => $contactName,
                    'contact_email' => $contactEmail,
                    'contact_phone' => $contactPhone,
                    'ops_notes' => $opsNotes,
                ] as $column => $value) {
                    if ($value !== null) {
                        $columns[] = $column;
                        $placeholders[] = '?';
                        $values[] = $value;
                    }
                }

                $stmt = $pdo->prepare(
                    'INSERT INTO tenants (' . implode(', ', $columns) . ')
                     VALUES (' . implode(', ', $placeholders) . ')'
                );
                $stmt->execute($values);
                $tenantId = (int) $pdo->lastInsertId();

                if ($ownerEmail !== null) {
                    // invited_by stays NULL: a super admin is not an `admins` row.
                    $invitation = ManagerInvitationModel::create($tenantId, null, [
                        'name' => $ownerName,
                        'email' => $ownerEmail,
                        'role' => 'general_manager',
                    ]);
                }

                $pdo->commit();
            } catch (Throwable $e) {
                if ($pdo->inTransaction()) {
                    $pdo->rollBack();
                }
                error_log('Admin tenant create failed: ' . $e->getMessage());
                $this->error('تعذّر إنشاء الشركة', 500);
                return;
            }

            AdminAuth::logAction('tenant.create', 'tenant', $tenantId, [
                'name' => $name,
                'owner_email' => $ownerEmail,
                'invited' => $invitation !== null,
            ]);

            if ($invitation !== null) {
                ManagerInviteMailer::queue($ownerEmail, $invitation['code'], 'general_manager', $name);
            }

            $this->success([
                'tenant_id' => $tenantId,
                'name' => $name,
                'invitation' => $invitation === null ? null : [
                    'code' => $invitation['code'],
                    'email' => $ownerEmail,
                    'expires_at' => $invitation['expires_at'],
                    'expires_in_hours' => 72,
                    'join_url' => ManagerInviteMailer::joinUrl($invitation['code']),
                ],
            ]);
        }, 'admin.tenants.create');
    }

    private function trimOrNull($value): ?string {
        if ($value === null) {
            return null;
        }
        $value = trim((string) $value);
        return $value === '' ? null : $value;
    }
}

new TenantCreateApi();
