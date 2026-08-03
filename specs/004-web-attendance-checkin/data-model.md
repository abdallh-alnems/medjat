# Phase 1 Data Model — Web Attendance Check-In / Check-Out

**Feature**: `004-web-attendance-checkin` · **Date**: 2026-08-02

All changes are **additive**. Nothing is dropped or renamed, and no existing
default changes, so deploying this migration set alters no current behaviour
until a company enables the channel (FR-021, SC-006).

Target is **MySQL 8.4** (live). It has no `ADD COLUMN IF NOT EXISTS` — that is
MariaDB — so every migration runs exactly once, in order, recorded in
`schema_migrations` by `deploy.sh`.

---

## 1. New — `employee_web_credentials`

The repeatable secret the employee identity has never had ([R-002](./research.md)).

| Column | Type | Notes |
|---|---|---|
| `id` | `int unsigned` PK auto | |
| `tenant_id` | `int unsigned` NOT NULL | Tenant isolation; indexed with `employee_id` |
| `employee_id` | `int unsigned` NOT NULL | **UNIQUE** — one credential per employee |
| `pin_hash` | `varchar(255)` NOT NULL | `password_hash()`, never the PIN itself |
| `failed_attempts` | `tinyint unsigned` NOT NULL DEFAULT 0 | Reset to 0 on success |
| `locked_until` | `datetime` NULL | Set in SQL, never from PHP |
| `pin_set_at` | `datetime` NOT NULL | |
| `last_used_at` | `datetime` NULL | |
| `created_at` / `updated_at` | `timestamp` | |

**Rules**

- PIN is exactly **6 digits**; validated server-side, never accepted from a
  client claim of validity.
- Trivial PINs are refused: all-same (`111111`) and simple runs (`123456`,
  `654321`). Refusing more than that trades real usability for little entropy.
- **5** consecutive failures sets `locked_until`; only an administrator reset
  clears the credential.
- A row here is created **only** by consuming a valid activation code. There is
  no self-service path to a first PIN.

**Lifecycle**: `absent → set (on activation) → locked (5 failures) → reset by admin (row deleted, new activation code issued) → set`

---

## 2. Extended — `employee_auth_tokens`

Existing table, reused so that web and app sessions authenticate through one
path (`Auth::authenticateEmployee`, which reads `X-Employee-Token`).

| Change | Detail |
|---|---|
| `platform` | `enum('android','ios')` → **`enum('android','ios','web')`**. `MODIFY` restates all values — omitting one invalidates existing rows ([R-010](./research.md)). |
| `expires_at` (new) | `datetime` **NULL**. NULL = never expires, which preserves today's app behaviour exactly. Web sessions set it; app sessions do not. |

**Why nullable rather than a default**: app tokens are deliberately perpetual
(the table has no expiry today). A non-null default would silently start expiring
every phone in the field.

**Rules**

- A web session sets `expires_at = DATE_ADD(NOW(), INTERVAL 16 HOUR)` — computed
  **in SQL** ([R-006](./research.md)).
- Issuing a web session revokes the employee's other **`platform='web'`** rows
  only. App tokens are untouched (FR-005 is about browser identity).
- A successful **check-out** on a web session revokes it immediately (FR-004a).
- `device_id` (already `NOT NULL`) carries the browser UUID cookie for
  shared-device detection ([R-009](./research.md)).

---

## 3. Extended — `attendance`

| Column | Type | Notes |
|---|---|---|
| `check_in_origin` | `enum('app','web')` NULL | NULL for every existing row and for device/manual punches; set from the **session**, never the request body ([R-011](./research.md)) |
| `check_out_origin` | `enum('app','web')` NULL | Same |
| `check_in_photo` | `varchar(255)` NULL | Relative path under `uploads/attendance/` |
| `check_out_photo` | `varchar(255)` NULL | Same |
| `shared_device_flag` | `tinyint(1)` NOT NULL DEFAULT 0 | Advisory only — never blocks (FR-020) |

**Not touched**: `check_in_method` / `check_out_method` keep their existing enum
values. The web is a **channel**, not an attendance method — FR-023b — so a web
punch still records `gps_only` or `qr_gps` as its method and records `web` as its
origin. This is what keeps the feature from deepening the existing conflation of
*how attendance is proven* with *where it was recorded from*.

---

## 4. Extended — `tenants`

| Column | Type | Default | Notes |
|---|---|---|---|
| `web_attendance_enabled` | `tinyint(1)` NOT NULL | **0** | FR-021 — off for every existing company |
| `web_attendance_photo_required` | `tinyint(1)` NOT NULL | **1** | FR-017a — on by default *when* the channel is enabled |

The photo default being `1` while the channel default is `0` is intentional: a
company that switches the weakest channel on gets the evidence control with it,
and has to opt out deliberately.

---

## 5. Extended — `employee_categories`

| Column | Type | Default | Notes |
|---|---|---|---|
| `web_attendance_allowed` | `tinyint(1)` **NULL** | NULL | NULL = inherit the company setting |

**Resolution** (FR-023, FR-023a) — deliberately *not* the four-level method
resolver:

```
company disabled                                  → refuse
company enabled, no category sets a value         → allow
company enabled, ≥1 of the employee's categories
  sets web_attendance_allowed = 1                 → allow
otherwise                                         → refuse
```

Union-with-any semantics match how category attendance methods already resolve,
so administrators meet one mental model, not two.

---

## 6. Extended — `attendance_security_logs`

The `reason` enum gains three values, restating all existing ones (`MODIFY`
replaces the definition wholesale — the same care taken in
`2026_07_31_local_biometric_gate.sql`):

| New reason | Written when |
|---|---|
| `web_not_permitted` | Company or category forbids the channel |
| `web_pin_locked` | Credential locked after repeated failures |
| `web_shared_device` | A device served a second employee in one working day |

Existing values retained: `mock_location`, `rooted`, `jailbroken`, `vpn`,
`gps_out_of_range`, `no_local_biometric`.

---

## 7. Entity relationships

```
tenants ──1:N── employees ──1:1── employee_web_credentials
   │                │
   │                ├──1:N── employee_auth_tokens   (platform: android | ios | web)
   │                └──1:N── attendance             (origin: app | web, photo, shared_device_flag)
   │
   ├──1:N── employee_categories  (web_attendance_allowed: NULL | 0 | 1)
   └──1:N── branches ──1:N── branch_networks  (kind: bssid | ip_v4 | ip_cidr)
                                   └─ web channel reads ip_v4 / ip_cidr only  (R-005)
```

---

## 8. Migration files

Three dated files, applied by `deploy.sh` in order:

| File | Contents |
|---|---|
| `2026_08_03_employee_web_sessions.sql` | Create `employee_web_credentials`; extend `platform` enum; add `expires_at` |
| `2026_08_03_attendance_punch_photo.sql` | Add origin, photo and flag columns to `attendance`; extend the security-log reason enum |
| `2026_08_03_web_attendance_settings.sql` | Add tenant settings and the category column |

Each must state in its header comment **why** it exists and what it deliberately
does not change, matching the standard set by the existing migrations.

---

## 9. Validation rules summary

| Rule | Where enforced | Requirement |
|---|---|---|
| PIN is 6 digits, not trivial | Server, on activation and reset | FR-002a |
| 5 failures → lock | `EmployeeWebCredentialModel` | FR-002b |
| Web session ≤ 16 h, expiry computed in SQL | `WebSessionService` | FR-003, R-006 |
| One live web session per employee | `WebSessionService` on issue | FR-005 |
| Session revoked on check-out | `check_out.php` | FR-004a |
| Punch refused outside the geofence | `GpsService` (unchanged) | FR-012 |
| IP/CIDR checked when the branch defines one | `NetworkVerifier` (unchanged) | FR-013 |
| Punch refused if photo required and absent | `check_in.php` / `check_out.php` | FR-017b |
| Origin taken from session, not body | `check_in.php` / `check_out.php` | R-011 |
| Every refusal logged | `attendance_security_logs` | FR-015 |
| Times from `TenantClock` | All write paths | FR-010 |
