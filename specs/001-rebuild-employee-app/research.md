# Phase 0 Research: Rebuild Employee App — Phone + Activation Code

**Date**: 2026-06-01 | **Feature**: `001-rebuild-employee-app`

This file records the **technical decisions** grounded in the current code (`backend_medjet`, `front_end/medjat_app`). Product ambiguities were already resolved in the spec's Clarifications (Sessions 2026-05-31 / 2026-06-01); nothing here is a NEEDS CLARIFICATION.

---

## D1 — Parallel backend auth, never touch the management path

- **Decision**: Add `Auth::authenticateEmployee(PDO): array` alongside the existing `Auth::authenticateUser` (which verifies a Firebase ID token, looks up `admins.firebase_uid`, returns `admin_id`). Leave `authenticateUser` byte-for-byte unchanged.
- **Rationale**: `authenticateUser` backs the entire management app. The spec (FR-023, SC-008) forbids regressions. A sibling function isolates risk.
- **Shape returned** (so endpoints change minimally): `['employee_id','employee','tenant_id','branch_id','admin_id','input']` — `employee` pre-resolved and `tenant_id` taken from the token (trusted), so endpoints stop calling `EmployeeModel::findByAdminId(...)`.
- **Token transport**: header `X-Employee-Token` (fallbacks `employee_token` in body/query). Mirrors the existing station pattern (`X-Station-Token`).
- **Alternatives rejected**: (a) Branching inside `authenticateUser` — too risky for the management app. (b) JWT — unnecessary; the DB already has `employee_auth_tokens` with a uniqueness constraint.

> **Verified against code**: `activation_code.php` (admin) ALREADY does the right thing for FR-009 — on POST it calls `EmployeeAuthTokenModel::revokeForEmployee($id,'admin_regenerated_code')`, sets `employees.status='pending_activation'`, and generates a fresh code. So "code re-issue invalidates the session" needs **no backend change** beyond what exists. Also note login must set status back to `active` (D3), since re-issue moves it to `pending_activation`.

## D2 — Token issuance & hashing

- **Decision**: On login, generate `bin2hex(random_bytes(32))` (64 hex chars), store only `hash('sha256', token)` in `employee_auth_tokens.token_hash`, return the plaintext **once** in the login response. Authenticate by hashing the incoming token and matching `token_hash WHERE revoked_at IS NULL`; bump `last_used_at`.
- **One active token per employee**: call `revokeForEmployee($employeeId, 'reissued_on_login')` immediately before `INSERT` (honors the `uniq_active_token_per_emp(employee_id, revoked_at)` constraint and FR-008).
- **Rationale**: Plaintext never persisted server-side (constitution V analog). Matches REBUILD plan §أ-1.
- **New `EmployeeAuthTokenModel` methods**: `issue(tenantId, employeeId, deviceId, deviceModel, platform, appVersion): string`, `findActiveByPlain(plain): ?array`, `revokeByPlain(plain, reason): void`. (`findActiveForEmployee`/`revokeForEmployee` already exist.)

## D3 — Code identifies employee; phone is the second factor

- **Decision**: `employee_login.php` resolves the employee via `ActivationCodeModel::findByCode($code)` (already filters `used_at IS NULL AND expires_at > NOW()` across all tenants), then verifies the entered phone matches `employees.phone` **after normalization** (strip spaces/dashes/leading `+`).
- **Rationale**: Phone is unique only per tenant (`UNIQUE(tenant_id, phone)`); the code is globally unique enough to identify one employee (spec Assumption). FR-003/FR-004.
- **On success (single transaction)**: set `employees.status='active'`, ensure a lightweight `admins` row exists for the employee (so the existing FCM/notification machinery keyed on `admin_id` works — see D6), `ActivationCodeModel::markUsedByDevice(codeId, deviceId)`, then `issue()` the token.
- **New `ActivationCodeModel` method**: `markUsedByDevice(codeId, deviceId)` — reuses `used_by_firebase_uid` column storing `'device:'+deviceId`. Keep the old `markUsed(codeId, firebaseUid)` so the legacy `activate_employee.php` is not broken.

## D4 — Re-login requires a new code (no silent reuse)

- **Decision**: Logout revokes the token; the consumed code stays consumed. Re-entry needs a freshly generated code from administration (`employees/activation_code.php`, which already revokes prior unused codes and issues a new 6-char/24h code).
- **Rationale**: Spec clarification (Session 2026-05-31). No app/back-end change needed beyond honoring it; the login screen copy (FR-025) tells the employee to ask administration.

## D5 — Session never auto-expires; 401 handled centrally in the app

- **Decision**: Backend does not expire tokens by time (only by logout or re-issue) — FR-007. The app treats **HTTP 401** from any protected call as "session ended": clear local session (`clearSession()` — keeps `device_id`) and route to login with an Arabic "انتهت الجلسة" message.
- **Implementation point**: central hook in `CRUD._handleResponse` (or a thin wrapper the controllers consult) so every feature inherits it (constitution III). Avoid duplicating logout logic per controller.
- **Alternatives rejected**: per-controller 401 checks (violates DRY/layering).

## D6 — FCM/notifications keep working without Firebase Auth

- **Decision**: Keep `firebase_core` + `firebase_messaging` + crashlytics/analytics/remote_config/app_check. Remove only `firebase_auth` + `google_sign_in`. Messaging does not require Firebase **Auth**.
- **Backend**: notifications are keyed on `admin_id` (`admin_devices`, `notifications`, `SmartAlertService`). Because login creates/links a lightweight `admins` row for the employee (D3), `update_fcm_token.php`/`notification_prefs.php`/`notifications/{list,read}.php` keep using `admin_id` — they just switch to `authenticateEmployee` and read `$auth['admin_id']`.
- **Timing**: register the FCM token **after** successful login (the request needs `X-Employee-Token`).
- **Rationale**: Smallest change that preserves delivery (FR-021, SC-009) without rewriting `SmartAlertService`.

## D7 — Stable `device_id`

- **Decision**: Generate once, store in `flutter_secure_storage` under `device_id`, reuse forever (`getOrCreateDeviceId()`). Survives logout (`clearSession()` deletes only `auth_token`+`user_data`, never `device_id`). `device_model` via `Platform`/optional `device_info_plus`; `platform` = `ios`/`android`; `app_version` via `package_info_plus`.
- **Rationale**: token is device-bound; a churning id would defeat the binding and the per-device session model.

## D8 — Offline attendance (personal, US4)

- **Decision**: Reuse existing Hive-backed offline queue + `attendance/sync_offline.php` (sends a `records[]` batch). Gate behind the company's "allow offline attendance" setting. Personal check-in stays **QR + GPS** (`branch_id`, `latitude`, `longitude`, optional `qr_code`); backend rejects out-of-range via `GpsService::validateCheckIn` (`GPS_OUT_OF_RANGE`).
- **De-dup**: rely on backend `AttendanceModel::syncOffline` reconciliation; include a stable client key per queued record if the backend supports it (verify in `AttendanceModel`). Goal: zero lost/duplicated records (SC-006).
- **Note**: this plan does NOT change the personal check-in contract; it only re-points auth.

## D9 — Kiosk reuses existing station endpoints as-is

- **Decision**: Kiosk mode (US7) is a separate device mode that calls the **already-implemented** station endpoints with `X-Station-Token`; no new backend work for kiosk.
  - Pair: `POST app/station/activate.php` `{qr_payload, device_info}` → returns station token + branch info. (Admin generates the pairing QR via `stations/create.php` in the management app — out of scope here.)
  - Roster/settings: `GET app/station/sync.php` and `GET app/station/branch_employees.php`.
  - Check-in/out: `POST app/station/check_in_out.php` `{employee_id, method ∈ face|fingerprint|both, confidence?, gps_lat?, gps_lng?, captured_image_base64?}`.
  - Unlock/admin: `POST app/station/verify_admin_pin.php`; enroll: `POST app/station/enroll_employee_biometric.php` (admin-PIN gated).
  - Liveness: `POST app/station/heartbeat.php` (server auto-locks if GPS drifts > 3× `station_gps_radius_meters`).
- **Branch settings** (`station_methods ∈ face_only|fingerprint_only|both_available`, `station_confidence_threshold`, `station_anti_spoofing_enabled`, `station_gps_radius_meters`, admin PIN) come from `sync.php`; the app honors them (FR-027/028/033).
- **Rationale**: The spec's clarifications were verified directly against these files. Reuse avoids backend churn and keeps the management app authoritative over station config.

## D10 — On-device biometric matching (kiosk)

- **Decision**: Face/fingerprint capture + matching happen **on the device**; only `confidence` (and optionally a captured image marker) is sent. The chosen on-device library/SDK is an **implementation detail for the tasks/coding phase** — not fixed here — but it MUST: run offline, honor `station_confidence_threshold`, and support the branch's `station_methods`. Fingerprint may use the platform biometric API; face matching needs an on-device model. Enrollment uploads embeddings/templates via `enroll_employee_biometric.php`.
- **Rationale**: Backend already expects `confidence` and stores embeddings/templates; matching server-side is out of scope and offline kiosk requires local inference.
- **Open for tasks phase** (not blocking the plan): exact face-matching package selection; anti-spoofing/liveness depth. Tracked as a task spike, defaulting to platform fingerprint first if face tooling slips (US7 is P3).

---

## Resolved unknowns summary

| Technical Context item | Resolution |
|---|---|
| Auth method/transport | `X-Employee-Token` via `authenticateEmployee` (D1) |
| Token format/storage | random 32-byte, SHA-256 at rest, plaintext once (D2) |
| Session expiry | none by time; 401-driven logout in app (D5) |
| Push without Firebase Auth | keep messaging; key on linked `admin_id` (D6) |
| device_id stability | secure-storage, create-once (D7) |
| Offline attendance | reuse Hive queue + sync_offline.php (D8) |
| Kiosk backend | reuse station/* endpoints, X-Station-Token (D9) |
| Biometric matching | on-device, send confidence; library deferred to tasks (D10) |
