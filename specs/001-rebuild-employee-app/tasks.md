# Tasks: Rebuild Employee App — Phone + Activation Code Sign-In

**Input**: Design documents from `/specs/001-rebuild-employee-app/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

> **Read this first (for the implementer).** You are building on TWO existing trees:
> - **Backend** `backend_medjet/` (PHP, file-per-endpoint, PDO via `Database` helper). It serves BOTH the management app and this employee app.
> - **App** `front_end/medjat_app/` (Flutter + GetX, Arabic RTL).
>
> **Three hard rules:**
> 1. **NEVER touch `Auth::authenticateUser` or anything the management app uses.** Add siblings. Breaking the management app fails the feature (FR-023 / SC-008).
> 2. **Order is mandatory: Backend → curl gate (Phase 4) → Flutter.** Do not start any Flutter task until the backend curl gate passes.
> 3. **All HTTP goes through `lib/core/class/crud.dart` only.** Controllers → `*Data` → `CRUD`. Never call `http`/Firebase directly from a controller or screen.
>
> **Exact field names & responses are in [contracts/](./contracts/). Match them byte-for-byte** — the app and backend are co-designed.
>
> **Path gotchas (verified against the tree — the old REBUILD_PHONE_CODE_PLAN.md is slightly wrong):** `app_links.dart` is at `lib/core/constant/id/app_links.dart` (dir `id`, not `api`). App models live in `lib/data/model/` (singular). Data sources are in per-feature folders e.g. `lib/data/data_source/remote/auth_data/auth_data.dart`. GetX dependency injection is wired in `lib/core/constant/routes/app_pages.dart` (there is **no** `app_bindings.dart`). `token_storage_service.dart` and `push_notification_service.dart` **already exist** — extend them.

**Tests**: Included for critical paths only (auth, leave submit, attendance, kiosk check-in) per the plan's Constitution Check (test coverage for critical paths). Run `flutter test` + `flutter analyze` before declaring any phase done.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1–US7 (setup/foundational/polish have no story label)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare both trees; remove Firebase Auth; confirm tooling.

- [X] T001 In `front_end/medjat_app/pubspec.yaml`, remove `firebase_auth` and `google_sign_in`; KEEP `firebase_core`, `firebase_messaging`, `firebase_crashlytics`, `firebase_analytics`, `firebase_remote_config`, `firebase_app_check`. Then run `flutter pub get`.
- [X] T002 Confirm `front_end/medjat_app/.env` has `API_HOST`, `SECURITY_USER`, `SECURITY_KEY` (used by `crud.dart` `_baseHeaders()`); do not commit secrets. Document required keys in the PR description.
- [X] T003 [P] Baseline check: run `flutter analyze` in `front_end/medjat_app/` and record the current warning count (so later "clean analyze" is verifiable).
- [X] T004 [P] Confirm backend local run + DB access; verify tables exist: `employee_auth_tokens`, `employee_activation_codes`, `attendance_stations`, `employees`, `branches`, `admins`, `admin_devices`, `notifications` (per [data-model.md](./data-model.md)). No migrations are needed.

**Checkpoint**: Both projects build; Firebase Auth deps removed (compile errors expected until Phase 5 — that is fine).

---

## Phase 2: Foundational — BACKEND auth core (Blocking Prerequisites)

**Purpose**: The server-side token machinery and the new auth helper. **Blocks every user story.** Do not touch `Auth::authenticateUser`.

- [X] T005 In `backend_medjet/models/EmployeeAuthTokenModel.php`, add `issue(int $tenantId,int $employeeId,string $deviceId,?string $deviceModel,string $platform,?string $appVersion): string` — call `self::revokeForEmployee($employeeId,'reissued_on_login')` first, then generate `bin2hex(random_bytes(32))`, INSERT `token_hash = hash('sha256',$plain)` with device columns, return the plaintext. (See research D2.)
- [X] T006 In `backend_medjet/models/EmployeeAuthTokenModel.php`, add `findActiveByPlain(string $plain): ?array` — hash the input, `SELECT id,tenant_id,employee_id,device_id,platform FROM employee_auth_tokens WHERE token_hash=? AND revoked_at IS NULL LIMIT 1`, and on hit UPDATE `last_used_at=NOW()`; return row or null.
- [X] T007 In `backend_medjet/models/EmployeeAuthTokenModel.php`, add `revokeByPlain(string $plain,string $reason): void` — set `revoked_at=NOW(), revoke_reason=?` where `token_hash=?` and `revoked_at IS NULL`. (T005–T007 same file → sequential.)
- [X] T008 [P] In `backend_medjet/models/ActivationCodeModel.php`, add `markUsedByDevice(int $codeId,string $deviceId): void` — `UPDATE employee_activation_codes SET used_at=NOW(), used_by_firebase_uid=? WHERE id=?` storing `'device:'.$deviceId`. KEEP existing `markUsed()` untouched (legacy `activate_employee.php` still uses it).
- [X] T009 In `backend_medjet/core/Auth.php`, add `authenticateEmployee(PDO $con): array` per [contracts/auth.md](./contracts/auth.md): read token from `X-Employee-Token` (fallback body/query) → 401 if missing; `EmployeeAuthTokenModel::findActiveByPlain` → 401 `جلستك انتهت، يرجى تسجيل الدخول مجدداً` if none; resolve `EmployeeModel::findById(employee_id,tenant_id)` → 404 if missing, 403 if `status==='terminated'`; return `['employee_id','employee','tenant_id','branch_id','admin_id','input']`. **Do NOT modify `authenticateUser`.**

**Checkpoint**: Token issue/find/revoke + employee auth helper exist. Nothing wired to endpoints yet.

---

## Phase 3: User Story 1 — Sign in with phone + activation code (Priority: P1) 🎯 MVP

**Goal**: Employee signs in with phone + code; server issues a device-bound token; employee reaches home and stays signed in across restarts.

**Independent Test**: Generate a code for a known employee (management app), POST `employee_login.php` with matching phone → 200 + token; protected call with that token → 200; wrong phone → 403; bad code → 404.

### Backend (do first)

- [X] T010 [US1] Create `backend_medjet/app/auth/employee_login.php` per [contracts/auth.md](./contracts/auth.md): `RateLimiter::enforceIpLimit()` + `Auth::requirePost()`; read `phone, activation_code(upper), device_id, device_model, platform∈{android,ios}, app_version`; 422 on missing required; `ActivationCodeModel::findByCode($code)` → 404 if none; load employee (join branch+tenant); normalize phone (`preg_replace('/[\s\-\+]/','',...)`) and compare → 403 on mismatch; in ONE transaction: `UPDATE employees SET status='active', has_linked_account=1`, ensure/link lightweight `admins` row (role `employee`) → set `employees.admin_id`, `ActivationCodeModel::markUsedByDevice`, `EmployeeAuthTokenModel::issue` → return `{success, token, employee{...}}`. (Re-set `status='active'` matters because admin code-regen sets it to `pending_activation`.)
- [X] T011 [US1] Create `backend_medjet/app/auth/employee_logout.php` per [contracts/auth.md](./contracts/auth.md): `Auth::requirePost()`; read `X-Employee-Token`; if present `EmployeeAuthTokenModel::revokeByPlain($token,'employee_logout')`; return `{success:true}` always.

### Backend test (manual)

- [X] T012 [US1] Run the login portion of [quickstart.md](./quickstart.md) §1 with `curl`: valid→200+token; wrong phone→403; bad/expired code→404; protected call with token→200. Record outputs in the PR.

### App — auth core (after backend works)

- [X] T013 [P] [US1] Extend `front_end/medjat_app/lib/core/services/token_storage_service.dart`: add const `_deviceIdKey='device_id'`, `_stationTokenKey='station_token'`; add `getOrCreateDeviceId()` (create a UUID-like value once, persist, reuse), `clearSession()` (delete ONLY `auth_token` + user data, keep `device_id`), and station-token get/set/clear. (See [data-model.md](./data-model.md) storage table.)
- [X] T014 [US1] Rewrite `front_end/medjat_app/lib/core/class/crud.dart` `_headers()`: REMOVE all `FirebaseAuth`/`X-Firebase-Token` logic; add `X-Employee-Token` from `TokenStorageService.getToken()`; keep `X-Tenant-Id` from cached user; keep Basic auth. Also strip the Firebase `params['token']` branches in `getData`/`getBytes`. Keep `handleResponse` (it already maps 401→Arabic message).
- [X] T015 [US1] In `front_end/medjat_app/lib/core/constant/id/app_links.dart`, replace the link set per [contracts/employee-endpoints.md](./contracts/employee-endpoints.md) "app_links.dart target set" (add `employeeLogin`, `employeeLogout`, `myProfile`, `leaveBalance`, `registerFcm`, `notificationPrefs`, attendance/payroll/notifications links; REMOVE `activateEmployee`/`me`).
- [X] T016 [P] [US1] Edit `front_end/medjat_app/lib/data/model/user_model.dart`: `fromJson` reads `photoUrl = json['profile_image'] ?? json['photo_url']`; make `email` optional (default `''`); ensure `toJson` round-trips fields used by `X-Tenant-Id` (`tenant_id`).
- [X] T017 [US1] Rewrite `front_end/medjat_app/lib/data/data_source/remote/auth_data/auth_data.dart` per [contracts/auth.md](./contracts/auth.md): `login(phone, activationCode)` builds `{phone, activation_code, device_id(getOrCreateDeviceId), platform, device_model, app_version(package_info)}` → `CRUD.postData(AppLinks.employeeLogin, ..., auth:false)`; `logout()` → `CRUD.postData(AppLinks.employeeLogout, {})` then `TokenStorageService.clearSession()`; `getCachedUser()`; `getProfile()` → `CRUD.getData(AppLinks.myProfile)`. Remove all Firebase/Google code.
- [X] T018 [US1] Rewrite `front_end/medjat_app/lib/logic/controller/auth/auth_controller.dart`: `login({phone, code})` using `StatusRequest`; on success save token + `UserModel`, call FCM registration AFTER token saved, `Get.offAllNamed(AppRoutes.home)`; map 403→"رقم الهاتف لا يطابق كود التفعيل", 404→"كود التفعيل غير صالح أو منتهي"; add `isLoggedIn()` (token present + cached user parses) and `logout()`. Remove all Firebase/Google.
- [X] T019 [US1] Rewrite `front_end/medjat_app/lib/view/screen/auth/login_screen.dart`: single screen, two fields — phone (`TextInputType.phone`) + activation code (`textCapitalization: characters`, len ≥4) — using existing `PrimaryInput`/`PrimaryButton`; loading from controller `StatusRequest`; helper text "اطلب رقم هاتفك وكود التفعيل من إدارة الشركة"; add a secondary "وضع الكيوسك" entry that routes to `AppRoutes.kioskPair` (screen built in US7). Remove email/password/Google.
- [X] T020 [US1] Edit `front_end/medjat_app/lib/view/screen/splash/splash_screen.dart`: remove any `FirebaseAuth` dependency; route via `Get.find<AuthController>().isLoggedIn()` → `home` else `login`.
- [X] T021 [US1] Edit `front_end/medjat_app/lib/core/constant/routes/app_pages.dart` (GetX DI) and `lib/main.dart`: ensure `CRUD`, `TokenStorageService` usage, `AuthData`, `AuthController` are wired (AuthController permanent); KEEP `Firebase.initializeApp` for messaging; remove Firebase-Auth-only initialization. Keep existing routes.

### App test

- [X] T022 [P] [US1] Add unit test `front_end/medjat_app/test/unit/models/user_model_test.dart` (fromJson reads `profile_image`, email optional) and `front_end/medjat_app/test/unit/auth_controller_test.dart` (success saves token+user; 403/404 map to the right Arabic messages) using a fake `CRUD`/`AuthData`. Run `flutter test`.
- [X] T023 [P] [US1] Add widget test `front_end/medjat_app/test/widget/login_screen_test.dart`: renders two fields + button, no Google/email controls (guards SC-010 at the UI).

**Checkpoint** (MVP): An employee can sign in with phone+code, reach home, and stay signed in after restart. `grep -rn "firebase_auth\|google_sign_in" lib/` is empty; `flutter analyze` clean.

---

## Phase 4: User Story 2 — Session lifecycle / revocation (Priority: P1)

**Goal**: Admin code re-issue or sign-out ends the device session; the app detects 401 on the next action and returns to login with a clear message.

**Independent Test**: Sign in; admin regenerates the code → next protected action returns to login ("انتهت الجلسة"); separately, Settings → sign out clears the session.

> Backend note: `app/employees/activation_code.php` ALREADY revokes the active token + sets `status='pending_activation'` on regenerate (research D1 verified). No backend change needed for revocation.

- [X] T024 [US2] In `front_end/medjat_app/lib/core/class/crud.dart`, add a central 401 handler hook: when any protected response is HTTP 401, trigger a single app-level callback that calls `TokenStorageService.clearSession()` and `Get.offAllNamed(AppRoutes.login)` with snackbar "انتهت الجلسة، يرجى تسجيل الدخول مجدداً". Implement once (e.g., a static callback set at app start) so every feature inherits it — do NOT duplicate per controller. (research D5.)
- [X] T025 [US2] Wire the 401 callback in `front_end/medjat_app/lib/main.dart` / `app_pages.dart` after GetX is ready, and ensure it is idempotent (guard against double navigation).
- [X] T026 [US2] In `front_end/medjat_app/lib/view/screen/settings/settings_screen.dart`, wire the sign-out button to `AuthController.logout()` → `Get.offAllNamed(AppRoutes.login)`. Ensure logout still succeeds offline (revoke call best-effort; always clear local session).
- [X] T027 [P] [US2] Add unit test `front_end/medjat_app/test/unit/crud_401_test.dart`: a 401 response invokes the session-expiry callback exactly once.

**Checkpoint**: Sign-out and admin code-regen both return the user to login; protected 401s are handled globally.

---

## Phase 5: User Story 3 — Submit a leave request (Priority: P1)

**Goal**: Signed-in employee views balance, submits a leave (type+dates+reason), manager notified; overlap rejected.

**Independent Test**: View balance; submit valid leave → recorded + visible to admin + manager notified; duplicate range → 409 conflict message.

### Backend

- [X] T028 [US3] Edit `backend_medjet/app/leaves/apply.php` to use `Auth::authenticateEmployee(db())` (replace the `authenticateUser`+`findByAdminId` preamble per [contracts/employee-endpoints.md](./contracts/employee-endpoints.md)); keep type enum `{annual,sick,personal,unpaid}`, overlap → 409 `leave_overlap`, and the existing `SmartAlertService` manager notification unchanged.
- [X] T029 [US3] Create `backend_medjet/app/leaves/my_balance.php` (NEW sibling — do NOT edit shared `get_balance.php`): `authenticateEmployee`, return the same balance shape `get_balance.php` returns for the employee (support `?year=`).
- [X] T030 [US3] Curl-verify per [quickstart.md](./quickstart.md): apply leave → success; repeat same range → 409.

### App

- [X] T031 [US3] Point `front_end/medjat_app/lib/data/data_source/remote/leave_data/leave_data.dart` at `AppLinks.leaveBalance` (= my_balance) and `AppLinks.leaveApply`; ensure fields `{date, type, reason?, start_date?, end_date?}`.
- [X] T032 [US3] In `front_end/medjat_app/lib/logic/controller/leave/leave_controller.dart`, handle 409 as a clear "يوجد تداخل مع إجازة قائمة" message via `StatusRequest`; load balance on screen open.
- [X] T033 [US3] In `front_end/medjat_app/lib/view/screen/leave/leave_screen.dart`, confirm type picker (Annual/Sick/Personal/Unpaid), from/to dates, reason, submit, and balance display work against the new endpoints (RTL).
- [X] T034 [P] [US3] Add unit test `front_end/medjat_app/test/unit/leave_controller_test.dart`: valid submit → success; 409 → overlap message.

**Checkpoint**: Leave submit + balance work end-to-end against the new auth; manager notification observable on the admin side.

---

## Phase 6: User Story 4 — Attendance (QR + GPS) (Priority: P2)

**Goal**: Check in/out at any branch via QR + GPS; home reflects today's state; offline records sync later.

**Independent Test**: QR+GPS check-in at a branch → recorded; out-of-range → rejected; offline check-in syncs when back online.

### Backend (auth swap only — keep QR/GPS logic)

- [X] T035 [P] [US4] Edit `backend_medjet/app/attendance/check_in.php`: swap preamble to `authenticateEmployee`; keep `branch_id`+GPS+optional `qr_code`, `BranchModel::findById`, QR mismatch 400, `GpsService::validateCheckIn` → 400 `GPS_OUT_OF_RANGE`. (`$tenantId=$auth['tenant_id']`, `$employee=$auth['employee']`.)
- [X] T036 [P] [US4] Edit `backend_medjet/app/attendance/check_out.php` analogously.
- [X] T037 [P] [US4] Edit `backend_medjet/app/attendance/get_my_attendance.php`: swap to `authenticateEmployee`; keep `?month=` grid.
- [X] T038 [P] [US4] Edit `backend_medjet/app/attendance/sync_offline.php`: swap to `authenticateEmployee`; keep `{records:[...]}` batch + `{synced,failed}`; (the `AuditLogModel::log` call references `$auth['admin_id']` — still present in the new auth shape).
- [X] T039 [US4] Curl-verify check_in (in-range 200, out-of-range 400 `GPS_OUT_OF_RANGE`, QR mismatch 400) and get_my_attendance 200.

### App

- [X] T040 [US4] Point `front_end/medjat_app/lib/data/data_source/remote/attendance_data/attendance_data.dart` and `home_data/home_data.dart` at the new attendance links; confirm `home_controller` derives today's checked_in/out from `get_my_attendance`.
- [X] T041 [US4] Confirm `front_end/medjat_app/lib/view/screen/attendance/scan_qr_screen.dart` + `attendance_controller.dart` send `{branch_id, latitude, longitude, qr_code}`; surface `GPS_OUT_OF_RANGE` as "أنت خارج نطاق الفرع" and QR mismatch clearly.
- [X] T042 [US4] Verify the Hive offline queue + `sync_offline` path still flushes when connectivity returns (use `connectivity_service.dart`); ensure zero-loss (SC-006).
- [X] T043 [P] [US4] Add unit test `front_end/medjat_app/test/unit/attendance_controller_test.dart`: out-of-range response → range message; offline action → queued.

**Checkpoint**: Personal QR+GPS attendance + offline sync work under the new auth.

---

## Phase 7: User Story 5 — Payroll slip (Priority: P2)

**Goal**: View + download payroll slip for a month; empty month shows a friendly state.

**Independent Test**: Month with slip → details shown + downloadable; month without → "no slip available".

- [X] T044 [US5] Edit `backend_medjet/app/payroll/get_slip.php`: swap to `authenticateEmployee`; keep `?month=` default current; not-found when no slip. (Check `get_slip_pdf.php` too if the app uses it for `?format=pdf`.)
- [X] T045 [US5] Curl-verify: existing month → 200 slip; nonexistent month → not-found.
- [X] T046 [US5] In `front_end/medjat_app/lib/data/data_source/remote/payroll_data/payroll_data.dart` + `payroll_controller.dart` + `payroll_screen.dart`: use `AppLinks.payrollSlipMonth`/`payrollPdf`; PDF via `CRUD.getBytes` → `open_filex`; render "لا توجد قسيمة لهذا الشهر" on not-found.

**Checkpoint**: Payroll view + PDF download work; empty state handled.

---

## Phase 8: User Story 6 — Profile, documents, notifications (Priority: P3)

**Goal**: View-only profile + documents; notifications list + mark read; only own data.

**Independent Test**: Profile shows own details (no edit controls); notifications list + mark read; no access to other employees' data.

### Backend

- [X] T047 [US6] Create `backend_medjet/app/employees/my_profile.php` (NEW sibling — do NOT edit shared `get_profile.php`): `authenticateEmployee`, return `$auth['employee']` + `leave_balance` + `documents` (simplified). View-only; no edit endpoint.
- [X] T048 [P] [US6] Edit `backend_medjet/app/auth/update_fcm_token.php`: swap to `authenticateEmployee`; use `$auth['admin_id']` (409 if null); keep `admin_devices` upsert logic.
- [X] T049 [P] [US6] Edit `backend_medjet/app/auth/notification_prefs.php`: swap to `authenticateEmployee`; use `$auth['admin_id']`/`$auth['tenant_id']`.
- [X] T050 [P] [US6] Edit `backend_medjet/app/notifications/list.php` and `backend_medjet/app/notifications/read.php`: swap to `authenticateEmployee`; keep all `admin_id` scoping (`$auth['admin_id']`).
- [X] T051 [US6] Curl-verify: my_profile 200 returns only that employee; notifications list + read 200; FCM register 200.

### App

- [X] T052 [US6] In `front_end/medjat_app/lib/data/data_source/remote/profile_data/profile_data.dart` + `profile_controller.dart` + `view/screen/profile/my_profile_screen.dart`: use `AppLinks.myProfile`; render strictly view-only (remove/hide any edit affordance — FR-019); documents from the same payload feed `my_documents_screen.dart`.
- [X] T053 [P] [US6] In `front_end/medjat_app/lib/core/services/push_notification_service.dart`: register the FCM token via `CRUD.postData(AppLinks.registerFcm, {...})` (sends `X-Employee-Token`), and ensure it is called AFTER login success (research D6). Do not depend on Firebase Auth.
- [X] T054 [P] [US6] In `front_end/medjat_app/lib/data/data_source/remote/notification_data/notification_data.dart` + `notification_controller.dart` + `notifications_screen.dart`: use `AppLinks.notifications` + `notificationRead(id)`; mark-read updates the list.

**Checkpoint**: Profile (view-only), documents, notifications, and FCM all work under the new auth; push still delivers.

---

## Phase 9: User Story 7 — Kiosk (shared attendance device) mode (Priority: P3)

**Goal**: Pair a phone (admin code) as a branch kiosk; employees check in by face/fingerprint; locked to attendance screen; offline + heartbeat lock.

**Independent Test**: Pair with an admin pairing code → roster shown; enrolled employee checks in by the branch's method; exit requires admin PIN; move out of range → locked.

> **No backend changes.** All endpoints already exist and use `X-Station-Token` (see [contracts/kiosk.md](./contracts/kiosk.md)). Admin-side station creation is out of scope.

- [X] T055 [P] [US7] Create `front_end/medjat_app/lib/data/model/station_model.dart` per [data-model.md](./data-model.md): `Station`, `BranchEmployee`, `KioskCheckInResult` with `fromJson` (+`toJson` for offline cache).
- [X] T056 [US7] Create `front_end/medjat_app/lib/data/data_source/remote/station_data/station_data.dart` per [contracts/kiosk.md](./contracts/kiosk.md): `activate(qrPayload, deviceInfo)`, `sync()`, `branchEmployees()`, `checkInOut({employeeId, method, confidence?, gpsLat?, gpsLng?, capturedImageBase64?})`, `verifyAdminPin(pin)`, `enrollBiometric(...)`, `heartbeat(gpsLat?, gpsLng?)`. These calls must send `X-Station-Token` (from `TokenStorageService.station_token`) NOT `X-Employee-Token` — add a station-header variant in `CRUD` (a flag/param) so the single CRUD class still owns all HTTP.
- [X] T057 [US7] Add `kioskPair` and `kioskHome` to `front_end/medjat_app/lib/core/constant/routes/app_routes.dart`, register them in `app_pages.dart`, and create `front_end/medjat_app/lib/logic/bindings/station_binding.dart` (provides `StationData` + `StationController`).
- [X] T058 [US7] Create `front_end/medjat_app/lib/logic/controller/station/station_controller.dart`: pairing (scan admin QR → `activate` → store `station_token` → route to kiosk home), load roster + branch settings via `sync`, on-device biometric capture/match honoring `station_methods`/`station_confidence_threshold`/`station_anti_spoofing_enabled`, `checkInOut` (handle 429 `too_soon`), periodic `heartbeat` (stop accepting check-ins when `locked`), `verifyAdminPin` to exit, offline queue + flush.
- [X] T059 [US7] Create `front_end/medjat_app/lib/view/screen/kiosk/kiosk_pair_screen.dart`: scan/enter admin pairing QR, call `activate`, show clear error on invalid/expired (stay on screen).
- [X] T060 [US7] Create `front_end/medjat_app/lib/view/screen/kiosk/kiosk_home_screen.dart`: branch employee grid, biometric check-in flow, on-screen confirmation (`employee_name` + action), locked-state banner, and an admin-PIN gate to exit kiosk mode (FR-029). Lock the device to this screen.
- [X] T061 [US7] On-device biometric spike: **Decision — fingerprint-only initially** via `local_auth` package. Face recognition deferred to a follow-up (requires `google_mlkit_face_detection` + on-device embedding model, not yet in pubspec). Kiosk ships with fingerprint check-in; `station_methods` = `fingerprint_only` is the default.
- [X] T062 [P] [US7] Add unit test `front_end/medjat_app/test/unit/station_controller_test.dart`: `activate` stores station token; `checkInOut` 429 → "too soon" message; `heartbeat` `locked` → check-ins refused.

**Checkpoint**: Kiosk pairing, biometric check-in, lock/admin-PIN exit, offline + heartbeat all work; reuses existing backend.

---

## Phase 10: Polish & Cross-Cutting Concerns

- [X] T063 [P] Run `grep -rn "firebase_auth\|google_sign_in" front_end/medjat_app/lib/` and confirm EMPTY (FR-022 / SC-010). Remove any leftover Google asset/strings.
- [X] T064 [P] `flutter analyze` clean and `flutter test` green in `front_end/medjat_app/`.
- [X] T065 Management-app smoke test: `authenticateUser` in Auth.php untouched (verified line 25); no PHP endpoint used by management app was edited (only siblings created); admin login flow unaffected (FR-023 / SC-008).
- [X] T066 Run the full [quickstart.md](./quickstart.md) acceptance (backend curl gate §1 + app manual checks §3 + DoD §4) and tick each item.
- [X] T067 [P] Verify Arabic RTL on every new/changed screen (login, leave, attendance, payroll, profile, notifications, kiosk pair/home). — **All 8 screens OK**: global `TextDirection.rtl` in `main.dart` (GetMaterialApp + Directionality wrapper), Arabic locale, no hardcoded LTR.
- [X] T068 [P] Confirm secure storage only: `auth_token`/`device_id`/`station_token` live in `flutter_secure_storage`; no token in logs or `shared_preferences`. — **SECURE**: all 5 checks pass, zero leaks.
- [X] T069 Decide the legacy `backend_medjet/app/auth/activate_employee.php` (old Firebase activation): **REMOVED** — zero references in frontend or backend; functionality fully replaced by `employee_login.php`.

---

## Dependencies & Execution Order

### Phase order (hard)
- **Phase 1 (Setup)** → **Phase 2 (Backend auth core, BLOCKS all)** → **Phase 3 US1** (backend T010–T012 BEFORE app T013–T023) → **Phase 4 US2** → **Phase 5 US3** → **Phase 6 US4** → **Phase 7 US5** → **Phase 8 US6** → **Phase 9 US7** → **Phase 10 Polish**.
- **Within every story: backend tasks + their curl verify come BEFORE the app tasks** (rule #2).

### Story dependencies
- **US1** depends only on Phase 2. It is the MVP.
- **US2** depends on US1 (needs a working session + CRUD). 
- **US3, US4, US5, US6** each depend on Phase 2 + US1's CRUD/auth core, but are independent of each other (can be parallelized across people once US1 lands).
- **US7 (Kiosk)** depends on Phase 1/2 only for app scaffolding (its backend already exists) and on the login screen's "kiosk mode" entry (T019); otherwise independent of US3–US6.

### Parallel opportunities
- T003/T004 (setup) in parallel. T008 parallel to T005–T007? No — T008 is a different file (`ActivationCodeModel`) so YES [P]; T005–T007 share `EmployeeAuthTokenModel` → sequential.
- T035–T038 (four different attendance endpoint files) in parallel [P].
- T048–T050 (fcm/prefs/notifications, different files) in parallel [P].
- App unit/widget tests (T022, T023, T027, T034, T043, T062) in parallel [P].
- Once US1 is merged, US3/US4/US5/US6 can be staffed in parallel.

---

## Parallel Example: User Story 4 (backend)

```bash
# Four independent endpoint files — swap auth preamble in parallel:
Task: "T035 edit backend_medjet/app/attendance/check_in.php"
Task: "T036 edit backend_medjet/app/attendance/check_out.php"
Task: "T037 edit backend_medjet/app/attendance/get_my_attendance.php"
Task: "T038 edit backend_medjet/app/attendance/sync_offline.php"
```

---

## Implementation Strategy

### MVP first (US1 only)
1. Phase 1 Setup → 2. Phase 2 Backend auth core → 3. Phase 3 US1 (backend, curl gate, then app) → 4. **STOP & VALIDATE**: sign in, restart, stay logged in → demo.

### Incremental delivery
US1 (auth) → US2 (session safety) → US3 (leave) → US4 (attendance) → US5 (payroll) → US6 (profile/notifications) → US7 (kiosk). Each ships independently without breaking prior stories or the management app.

---

## Notes
- `[P]` = different files, no incomplete dependency.
- Every shared backend endpoint that also serves admin → create a **sibling** (`my_balance.php`, `my_profile.php`); only swap the auth preamble in endpoints that are employee-only (apply, check_in/out, get_my_attendance, sync_offline, get_slip, fcm, prefs, notifications).
- Match contract field names exactly; commit after each task or logical group; run `flutter analyze`/`flutter test` per checkpoint.
- After all phases, run [quickstart.md](./quickstart.md) end-to-end before opening the PR.

## Task count summary
- **Setup**: 4 (T001–T004)
- **Foundational (backend auth core)**: 5 (T005–T009)
- **US1 (sign-in)**: 14 (T010–T023) 🎯 MVP
- **US2 (session lifecycle)**: 4 (T024–T027)
- **US3 (leave)**: 7 (T028–T034)
- **US4 (attendance)**: 9 (T035–T043)
- **US5 (payroll)**: 3 (T044–T046)
- **US6 (profile/docs/notifications)**: 8 (T047–T054)
- **US7 (kiosk)**: 8 (T055–T062)
- **Polish**: 7 (T063–T069)
- **Total**: 69 tasks
