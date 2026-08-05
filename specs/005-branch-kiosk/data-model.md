# Phase 1 Data Model: Branch Kiosk

**Feature**: [spec.md](./spec.md) · **Research**: [research.md](./research.md) · **Date**: 2026-08-03

Target: **MySQL 8.4**. Every change is additive — no column is dropped or
narrowed. Enum widening is written as a full `MODIFY COLUMN` re-statement because
MySQL 8 has no additive enum syntax.

Four new tables, six new columns, two widened enums, one widened permission list.

**Actors are `admins`, not `employees`.** `paired_by`, `revoked_by`, and
`created_by` all reference `admins.id` — `Auth::authenticateUser()` resolves an
administrator from that table, and an employee never pairs a kiosk. None of the
three carries a foreign key, so a wrong JOIN here would silently return nothing
rather than fail.

---

## New tables

### `attendance_stations`

A tablet in service at one branch. Modelled on `attendance_devices`
(schema.sql:267), which solves the same problem for ZKTeco terminals.

| Column | Type | Notes |
|---|---|---|
| `id` | `int unsigned` PK AI | |
| `tenant_id` | `int unsigned NOT NULL` | FK → `tenants` ON DELETE CASCADE |
| `branch_id` | `int unsigned NOT NULL` | FK → `branches` ON DELETE CASCADE. A station belongs to exactly one branch (FR-003) |
| `name` | `varchar(100)` | Set at pairing, e.g. "Main gate" |
| `status` | `enum('active','revoked') NOT NULL DEFAULT 'active'` | Revocation is a state, not a delete (FR-005) |
| `device_model` | `varchar(100)` | Reported by the tablet |
| `platform` | `varchar(20) NOT NULL DEFAULT 'android'` | Reserved for a future iPad build |
| `app_version` | `varchar(20)` | Drives FR-052 / FR-053 |
| `last_seen_at` | `datetime` | Drives the dark-kiosk alert (FR-048) |
| `last_ip` | `varchar(45)` | |
| `last_punch_at` | `datetime` | |
| `punch_count` | `int unsigned NOT NULL DEFAULT 0` | FR-004 activity volume |
| `paired_by` | `int unsigned` | `admins.id` — administrators live in `admins`, not `employees`. FR-006 |
| `paired_at` | `datetime` | |
| `revoked_by` | `int unsigned` | `admins.id`. FR-006 |
| `revoked_at` | `datetime` | |
| `created_at` / `updated_at` | `timestamp` | |

**Indexes**: `idx_station_tenant (tenant_id, status)`,
`idx_station_branch (branch_id, status)`, `idx_station_last_seen (last_seen_at)`.

**Lifecycle**: `active` → `revoked`. There is no `unclaimed` state — unlike a
ZKTeco terminal, which dials in before anyone claims it, a kiosk row is created by
the pairing exchange and is bound from birth.

---

### `kiosk_auth_tokens`

Mirrors `employee_auth_tokens` (schema.sql:685). The credential the tablet
presents on every request.

| Column | Type | Notes |
|---|---|---|
| `id` | `int unsigned` PK AI | |
| `tenant_id` | `int unsigned NOT NULL` | FK → `tenants` ON DELETE CASCADE |
| `station_id` | `int unsigned NOT NULL` | FK → `attendance_stations` ON DELETE CASCADE |
| `token_hash` | `varchar(64) NOT NULL` | SHA-256 of the opaque token. **UNIQUE** — the plaintext is never stored |
| `device_id` | `varchar(100) NOT NULL` | Tablet's install identifier |
| `issued_at` | `timestamp DEFAULT CURRENT_TIMESTAMP` | |
| `last_used_at` | `timestamp ... ON UPDATE CURRENT_TIMESTAMP` | |
| `revoked_at` | `timestamp NULL` | |
| `revoke_reason` | `varchar(100)` | `'unpaired'`, `'branch_deleted'`, `'replaced'` |

**Indexes**: `UNIQUE (token_hash)`, `uniq_active_token_per_station (station_id,
revoked_at)`, `idx_kiosk_token_tenant (tenant_id)`.

The `(station_id, revoked_at)` unique key reproduces the employee table's trick:
because MySQL treats `NULL`s as distinct, it permits many revoked rows but only
one live token per station.

---

### `kiosk_codes`

Both short-lived secrets in one table, distinguished by `purpose`. Modelled on
`employee_activation_codes` (schema.sql), which already solves single-use +
expiry + consumption tracking.

| Column | Type | Notes |
|---|---|---|
| `id` | `int unsigned` PK AI | |
| `tenant_id` | `int unsigned NOT NULL` | FK → `tenants` ON DELETE CASCADE |
| `branch_id` | `int unsigned NOT NULL` | FK → `branches` ON DELETE CASCADE |
| `station_id` | `int unsigned` | NULL for `pair` (no station exists yet); set for `access` |
| `purpose` | `enum('pair','access') NOT NULL` | FR-002 vs FR-037 |
| `code_hash` | `varchar(64) NOT NULL` | SHA-256. The plaintext is shown once and never stored |
| `expires_at` | `datetime NOT NULL` | **Computed in SQL** — `DATE_ADD(NOW(), INTERVAL ? SECOND)` |
| `used_at` | `datetime` | Non-null ⇒ consumed (single-use) |
| `used_by_station` | `int unsigned` | Which tablet consumed it |
| `created_by` | `int unsigned NOT NULL` | `admins.id` — who authorised it. FR-006 / FR-041 |
| `created_at` | `timestamp DEFAULT CURRENT_TIMESTAMP` | |

**Indexes**: `idx_kiosk_code_lookup (code_hash, used_at, expires_at)`,
`idx_kiosk_code_branch (branch_id, purpose)`, `idx_kiosk_code_expires
(expires_at)`.

**Why hashed rather than plaintext**: the removed `kiosk_pins` table stored
`pin_hash`, and `employee_activation_codes` stores the code in plaintext. The
hashed form is correct here — an access code opens enrollment and kiosk-mode
release, so a database read must not yield a working credential.

**Suggested lifetimes**: `pair` 15 minutes, `access` 5 minutes. Both single-use.

---

### `station_recognition_logs`

Every identification attempt, including the ones that identify nobody. Restores a
table name the removed system used; see [R-005](./research.md) for why
`face_verification_logs` cannot absorb these rows.

| Column | Type | Notes |
|---|---|---|
| `id` | `bigint unsigned` PK AI | Expected to be the highest-volume table here |
| `tenant_id` | `int unsigned NOT NULL` | FK → `tenants` ON DELETE CASCADE |
| `station_id` | `int unsigned NOT NULL` | FK → `attendance_stations` |
| `branch_id` | `int unsigned NOT NULL` | Denormalised for reporting |
| `employee_id` | `int unsigned NULL` | **Nullable** — this is the whole point (FR-013) |
| `purpose` | `enum('check_in','check_out','enroll') NOT NULL DEFAULT 'check_in'` | |
| `method` | `enum('face','code') NOT NULL DEFAULT 'face'` | FR-011 |
| `result` | `enum('matched','ambiguous','no_match','below_threshold','liveness_failed','out_of_branch','spoofing_suspected','not_enrolled','wrong_method','too_soon','out_of_range','bad_embedding','model_mismatch') NOT NULL` | |
| `accepted` | `tinyint(1) NOT NULL DEFAULT 0` | False in `log_only` even when `matched` |
| `match_score` | `decimal(4,3)` | Best candidate's cosine similarity |
| `runner_up_score` | `decimal(4,3)` | Second-best. Makes FR-044 auditable after the fact |
| `threshold` | `decimal(4,3)` | Value in force at the time |
| `margin` | `decimal(4,3)` | Value in force at the time |
| `candidates_searched` | `smallint unsigned` | FR-046 — correlate mis-attribution with roster size |
| `liveness_passed` | `tinyint(1) NOT NULL DEFAULT 0` | |
| `challenge` | `varchar(20)` | Which liveness challenge was issued |
| `capture_path` | `varchar(500)` | NULL unless retained under FR-055 / FR-058 |
| `capture_expires_at` | `datetime` | Drives the purge (FR-056). **Computed in SQL** |
| `latitude` / `longitude` | `decimal(10,7)` | FR-028 |
| `attendance_id` | `int unsigned NULL` | Set when the attempt produced a punch |
| `created_at` | `timestamp DEFAULT CURRENT_TIMESTAMP` | |

**Indexes**: `idx_srl_station (station_id, created_at)`,
`idx_srl_employee (tenant_id, employee_id, created_at)`,
`idx_srl_result (tenant_id, result, created_at)`,
`idx_srl_purge (capture_expires_at)`.

**Retention note**: rows are kept; **captures** are purged. `capture_path` is
nulled and the file unlinked once `capture_expires_at` passes. The score history
that threshold tuning depends on survives.

---

## Modified tables

### `branches` — two new columns

```sql
ALTER TABLE `branches`
  ADD COLUMN `station_match_threshold` decimal(4,3) DEFAULT NULL
    COMMENT 'Kiosk 1:N absolute threshold; NULL = system default. Stricter than 1:1 selfie matching',
  ADD COLUMN `station_match_margin` decimal(4,3) DEFAULT NULL
    COMMENT 'Required gap between best and runner-up candidate; NULL = system default',
  ADD COLUMN `station_code_fallback_enabled` tinyint(1) NOT NULL DEFAULT 1
    COMMENT 'Whether the personal-code path is offered at this branchs kiosks (FR-020)';
```

Reused as-is: `station_enabled`, `station_gps_radius_meters`,
`station_anti_spoofing_enabled`. Left in place and unused:
`station_confidence_threshold` (two decimal places), `station_methods` (assumes
fingerprint hardware), `station_admin_pin_hash` (superseded by `kiosk_codes`).
See [R-004](./research.md).

### `employees` — three new columns

```sql
ALTER TABLE `employees`
  ADD COLUMN `kiosk_pin_hash` varchar(255) DEFAULT NULL
    COMMENT 'Per-employee kiosk fallback code, hashed (FR-018)',
  ADD COLUMN `kiosk_pin_set_at` datetime DEFAULT NULL,
  ADD COLUMN `face_enrolled_by_station_id` int unsigned DEFAULT NULL
    COMMENT 'Which kiosk performed the enrollment, if any (FR-041)';
```

`face_enrolled_at`, `face_quality_score`, `face_embedding`, `face_model_version`,
and `face_embedding_dim` already exist and are written unchanged by kiosk
enrollment.

### `attendance_security_logs` — widened `reason`

```sql
ALTER TABLE `attendance_security_logs`
  MODIFY COLUMN `reason` enum(
    'mock_location','rooted','jailbroken','vpn','gps_out_of_range',
    'no_local_biometric',
    'kiosk_ambiguous_match','kiosk_spoofing_suspected','kiosk_out_of_branch',
    'kiosk_pin_bruteforce','kiosk_revoked_token','kiosk_version_blocked'
  ) NOT NULL;
```

Full re-statement, existing values first and unchanged, so no stored row is
invalidated.

**Known constraint**: `attendance_security_logs.employee_id` is `NOT NULL` with an
FK. Kiosk refusals that identify nobody therefore **cannot** be written here —
they live in `station_recognition_logs`, and only refusals that resolve to a known
employee are mirrored into the security log. FR-034 is satisfied by that pair, not
by the security log alone.

### `face_challenges` — `employee_id` becomes nullable

```sql
ALTER TABLE `face_challenges`
  MODIFY COLUMN `employee_id` int unsigned DEFAULT NULL
    COMMENT 'NULL for kiosk challenges — at challenge time the identity is not yet known';
```

Required by the 1:N flow and easy to miss. The selfie flow issues a challenge to a
**known** employee; the kiosk issues one before anybody has been identified, so
the column cannot stay `NOT NULL`. Widening a constraint invalidates no existing
row.

The `purpose` enum already carries `check_in`, `check_out`, and `enroll`, so
kiosk-side enrollment needs no change there.

### `attendance` — no schema change

`station_id`, `recognition_confidence`, and `recognition_method` (with
`station_face` already among its values) survive in production and are written as
they stand. Kiosk punches route through the existing `AttendanceModel` write path
so `late_minutes`, `status`, `worked_minutes`, and `overtime_minutes` stay
consistent with every other channel.

**One new column** for the evidence link and idempotency:

```sql
ALTER TABLE `attendance`
  ADD COLUMN `kiosk_idempotency_key` char(36) DEFAULT NULL
    COMMENT 'Client-generated key so a retried kiosk punch cannot double-insert (FR-027)',
  ADD UNIQUE KEY `uniq_att_kiosk_idem` (`kiosk_idempotency_key`);
```

A unique index over a nullable column permits unlimited non-kiosk rows while
making a replayed kiosk punch a no-op.

### `PermissionMiddleware` — three new permissions

Not a schema change; `core/PermissionMiddleware.php` holds the list as a PHP
constant. Add `kiosk_devices`, `kiosk_access`, `kiosk_evidence` to `PERMISSIONS`
**and** to `ROLE_DEFAULTS` per the table in [R-006](./research.md) — and add the
missing `biometric_enroll` / `biometric_delete` to `PERMISSIONS` at the same time,
since they are already granted in `ROLE_DEFAULTS` but absent from the canonical
list.

### `AttendanceMethodResolver` — one new method

```php
public const ALLOWED = ['qr_gps','gps_only','face_selfie','wifi_gps','device','manual','kiosk'];
```

Makes the kiosk assignable at employee / category / branch / tenant level
(FR-030) through machinery that already exists.

---

## Migration order

Additive throughout; each file runs once, in order, recorded in
`schema_migrations` by `migrate.sh`.

| # | File | Contents |
|---|---|---|
| 1 | `2026_08_03_kiosk_stations.sql` | `attendance_stations`, `kiosk_auth_tokens`, `kiosk_codes` |
| 2 | `2026_08_03_kiosk_recognition_logs.sql` | `station_recognition_logs` |
| 3 | `2026_08_03_kiosk_branch_employee_columns.sql` | `branches` + `employees` columns |
| 4 | `2026_08_03_kiosk_enum_widening.sql` | `attendance_security_logs.reason`, `face_challenges.employee_id` nullable, `attendance.kiosk_idempotency_key` |

Split so that a failure in the enum re-statement — the only step that rewrites an
existing table — does not strand the new tables half-created.

---

## Entity relationships

```
tenants ──┬── branches ──┬── attendance_stations ──┬── kiosk_auth_tokens
          │              │                          └── station_recognition_logs
          │              └── kiosk_codes                        │
          │                                                     │
          └── employees ──┬── face_embedding (enrollment) ───────┤
                          ├── kiosk_pin_hash (fallback)          │
                          └── attendance ────────────────────────┘
                                  (station_id, recognition_method,
                                   recognition_confidence, kiosk_idempotency_key)
```

Every table carries `tenant_id` so `TenantMiddleware` isolation holds without a
join.
