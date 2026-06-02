# Phase 1 Data Model: Rebuild Employee App

**Date**: 2026-06-01 | **Feature**: `001-rebuild-employee-app`

Maps spec entities to **existing** DB tables (backend) and **app** models. No new tables are required — all backend tables already exist. App models marked **[NEW]** must be created; **[EDIT]** adjusted.

---

## Backend tables (existing — do not create)

### `employee_activation_codes`
| Field | Notes |
|---|---|
| id | PK |
| tenant_id, employee_id | owner scoping |
| code | 6 uppercase hex chars, globally searched on login |
| expires_at | +24h from generation |
| used_at | NULL = active; set on consume |
| used_by_firebase_uid | **reused** to store `'device:'+device_id` via `markUsedByDevice` |

**Lifecycle**: `generated (used_at NULL, expires_at>now)` → `consumed (used_at set)` on successful login → terminal. Re-issue (`activation_code.php`) marks prior unused codes used and inserts a fresh one.

### `employee_auth_tokens`
| Field | Notes |
|---|---|
| id | PK |
| tenant_id, employee_id | owner |
| token_hash | UNIQUE; SHA-256 of plaintext (plaintext never stored) |
| device_id, device_model, platform `enum('android','ios')`, app_version | device binding |
| issued_at, last_used_at, revoked_at, revoke_reason | lifecycle |
| constraint `uniq_active_token_per_emp(employee_id, revoked_at)` | ≤1 active token/employee |

**Lifecycle**: `active (revoked_at NULL)` → `revoked` (login re-issue `reissued_on_login` / logout `employee_logout` / admin code re-issue). Authentication matches active rows only.

### `employees`
Relevant fields used here: `id, tenant_id, branch_id, admin_id, name, phone (UNIQUE(tenant_id,phone)), job_title, status, profile_image, has_linked_account`. Login sets `status='active'`, `has_linked_account=1`, and links/creates `admin_id`.

### `branches`
Used for attendance + kiosk: `id, tenant_id, name, qr_code, latitude, longitude, station_enabled, station_methods enum('face_only','fingerprint_only','both_available'), station_confidence_threshold, station_anti_spoofing_enabled, station_gps_radius_meters, station_admin_pin_hash`.

### `attendance_stations` (Kiosk)
`id, tenant_id, branch_id, device_name, token (X-Station-Token), is_locked, locked_reason, last_sync_at, last_heartbeat_at, last_lat, last_lng`. Created by admin (`stations/create.php`); activated by device (`station/activate.php`).

### Other (reused, unchanged): `admins` (lightweight employee row for FCM), `admin_devices`, `notifications`, `leaves`, `payroll*`, biometric tables.

---

## App models

### `UserModel` **[EDIT]** (`lib/data/models/user_model.dart`)
Fields: `id, name, phone, tenantId, tenantName, branchId, branchName, jobTitle, photoUrl`.
- `fromJson`: `photoUrl = json['profile_image'] ?? json['photo_url']`; make `email` optional/removed (default `''`).
- `toJson`: persisted to secure storage as the cached user.

### `StationModel` **[NEW]** (`lib/data/models/station_model.dart`)
- `Station`: `{stationId, branchId, branchName, deviceName, methods (face_only|fingerprint_only|both_available), confidenceThreshold, antiSpoofing, gpsRadiusMeters, isLocked, lockedReason}` — from `station/activate.php` + `station/sync.php`.
- `BranchEmployee`: `{id, name, phone, jobTitle, biometricEnrollmentStatus}` — from `station/branch_employees.php`/`sync.php`.
- `KioskCheckInResult`: `{action (check_in|check_out|too_soon), attendanceId, employeeName, timestamp}`.
All with `fromJson` (+`toJson` where cached for offline).

### Existing models reused: `AttendanceModel`, `LeaveModel`, `PayrollModel`, `NotificationModel` (re-point their data sources to new endpoints; field shapes unchanged unless contracts say so).

---

## Local secure storage keys (`token_storage_service.dart` **[NEW]**)
| Key | Lifetime | Cleared by |
|---|---|---|
| `auth_token` | until logout / 401 | `clearSession()` |
| `user_data` (UserModel JSON) | until logout / 401 | `clearSession()` |
| `device_id` | permanent (create-once) | never (survives logout) |
| `station_token` | until kiosk unpaired | dedicated kiosk clear |

`clearSession()` deletes only `auth_token`+`user_data`. `clearAll()` (if used) must re-write `device_id` afterward.

---

## State transitions (app-visible)

- **Auth session**: `signed_out → signing_in → signed_in` (token+user stored) → `signed_out` (logout) or `expired` (401 → clearSession → login).
- **Splash routing**: has valid `auth_token` + cached user → `home`; else → `login`.
- **Personal attendance (today)**: `none → checked_in → checked_out`; offline action → queued → synced.
- **Kiosk**: `unpaired → pairing → paired(active) → locked(out_of_range/admin)`; exit requires admin PIN.

---

## Validation rules (from FRs)
- Phone normalized before compare (FR-004). Code must be unused+unexpired (FR-002). Phone must match code owner (FR-003).
- Leave: type ∈ {annual,sick,personal,unpaid}; reject overlap (FR-014/014a).
- Personal check-in: reject outside branch radius; reject QR mismatch (FR-016).
- Kiosk check-in: reject duplicate within short interval ("too soon"); refuse when locked (FR-032/033).
