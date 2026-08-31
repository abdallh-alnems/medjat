---
description: "Task list for Branch Kiosk — Shared Tablet Attendance"
---

# Tasks: Branch Kiosk — Shared Tablet Attendance

**Input**: Design documents from `/specs/005-branch-kiosk/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/)

**Tests**: No automated test tasks are generated. The specification does not ask
for TDD, and this repository has **no PHP test harness** — `medjat_app` has no
widget-test suite either. Each story therefore ends with explicit **manual
verification** tasks drawn from [quickstart.md](./quickstart.md). These are not
optional: they are the only gate this feature has.

**Organization**: Grouped by user story so each can be built, verified, and
shipped on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different files, no dependency on incomplete work
- **[Story]**: US1–US7, mapping to the user stories in [spec.md](./spec.md)

## Path Conventions

- Backend: `backend_medjet/` — one endpoint per file under `app/<module>/`, shared logic in `core/`
- Kiosk app: `frontend/mobile/kiosk/` — a **standalone Flutter project**
- Shared: `frontend/mobile/shared/` — the face pipeline and its model, depended on by both `medjat_app` and `medjat_kiosk`
- Management: `frontend/mobile/manager/` (Flutter) and `frontend/web/manager/` (Next.js)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffolding that everything else lands in.

- [X] T001 [P] Create backend module directories `backend_medjet/app/kiosk/` and `backend_medjet/app/kiosk/admin/`
- [X] T002 [P] Create capture storage directory `backend_medjet/uploads/kiosk/`. Note: `uploads/` is entirely gitignored in this repo and directories are created at runtime with `mkdir(..., 0755, true)` — see `BiometricEnrollment::storeReferencePhoto()`. No tracked keeper file; the local directory is for MAMP only
- [X] T003 Create the shared package `frontend/mobile/shared/` (`publish_to: none`) and move `face_embedder.dart`, `face_liveness.dart`, and `assets/models/mobilefacenet.tflite` into it from `medjat_app`. Change the asset key to `packages/medjat_shared/assets/models/mobilefacenet.tflite` — a package asset is not reachable at its bare path
- [X] T004 Migrate `frontend/mobile/employee/` onto the package: add the path dependency, drop `assets/models/` from its pubspec so the 5 MB model is not bundled twice, delete the two local face files, repoint the three importers to `package:medjat_shared/medjat_shared.dart`, and confirm `flutter analyze lib` is clean
- [X] T005 Create the standalone kiosk project `frontend/mobile/kiosk/` (`flutter create --platforms=android`), set `applicationId`/`namespace` to `com.khawarizmie.medjat.kiosk`, move the Kotlin source to the matching package, set `minSdk = 29`, wire release signing from `key.properties` as `medjat_app` does, and write `android/app/src/main/AndroidManifest.xml` with `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`, camera, portrait, `showWhenLocked`, and an optional HOME intent filter so a supervisor can make it the launcher
- [X] T006 Run `backend_medjet/check-drift.sh` and resolve any pre-existing drift before writing migrations — starting dirty makes your damage indistinguishable from existing damage

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema, identity, and permissions. **No user story can begin until this phase is complete.**

### Migrations (order matters — each runs once)

- [X] T007 Write `backend_medjet/migrations/2026_08_03_kiosk_1_stations.sql` creating `attendance_stations`, `kiosk_auth_tokens`, and `kiosk_codes` per [data-model.md](./data-model.md), including the `uniq_active_token_per_station (station_id, revoked_at)` key
- [X] T008 Write `backend_medjet/migrations/2026_08_03_kiosk_2_recognition_logs.sql` creating `station_recognition_logs` with nullable `employee_id`, `runner_up_score`, `candidates_searched`, and `capture_expires_at`
- [X] T009 [P] Write `backend_medjet/migrations/2026_08_03_kiosk_3_branch_employee_columns.sql` adding `branches.station_match_threshold`, `station_match_margin`, `station_code_fallback_enabled` and `employees.kiosk_pin_hash`, `kiosk_pin_set_at`, `face_enrolled_by_station_id`
- [X] T010 Write `backend_medjet/migrations/2026_08_03_kiosk_4_enum_widening.sql` re-stating `attendance_security_logs.reason` in full with the six kiosk values, making `face_challenges.employee_id` nullable, and adding `attendance.kiosk_idempotency_key` with its unique index — plain `ADD COLUMN`, no MariaDB `IF NOT EXISTS`
- [X] T011 Apply all four locally with `backend_medjet/migrations/migrate.sh` against MAMP and confirm `--status` records them

### Identity and authorisation

- [X] T012 Add `authenticateKiosk(PDO $con): array` to `backend_medjet/core/Auth.php` — resolves `SHA-256(X-Kiosk-Token)` against `kiosk_auth_tokens`, rejects revoked tokens and non-`active` stations, touches `last_seen_at`, and returns `tenant_id`/`branch_id`/`station_id` and **never** an `employee_id`
- [X] T013 Create `backend_medjet/models/KioskTokenModel.php` with `findActiveByPlain()`, `issueFor()`, and `revokeForStation()`, mirroring `EmployeeAuthTokenModel`
- [X] T014 [P] Create `backend_medjet/models/KioskStationModel.php` — create, list by branch/tenant, revoke, and `touchSeen()`
- [X] T015 [P] Create `backend_medjet/models/StationRecognitionLogModel.php` — insert an attempt, query with filters, and a score-distribution aggregate
- [X] T016 Add `kiosk_devices`, `kiosk_access`, `kiosk_evidence` to `PermissionMiddleware::PERMISSIONS` in `backend_medjet/core/PermissionMiddleware.php`, **and** to `ROLE_DEFAULTS` per the table in [R-006](./research.md). In the same edit add the missing `biometric_enroll` and `biometric_delete` to `PERMISSIONS` — they are already granted in `ROLE_DEFAULTS` but absent from the canonical list
- [X] T017 [P] Add `'kiosk'` to `AttendanceMethodResolver::ALLOWED` in `backend_medjet/core/AttendanceMethodResolver.php`
- [X] T018 [P] Add a `medjat_kiosk` entry to `RemoteConfigService::APPS` in `backend_medjet/core/RemoteConfigService.php` with `min_version_key` and `maintenance_key`
- [X] T019 [P] Add kiosk message keys to `backend_medjet/lang/ar.php` and `backend_medjet/lang/en.php` — every refusal returns a `message_key`, never a rendered English string

### Kiosk app foundation

- [X] T020 Create `frontend/mobile/kiosk/lib/core/network/kiosk_crud.dart` — a `CRUD` variant that sends `X-Kiosk-Token` on every request and POSTs all mutations
- [X] T021 [P] Create `frontend/mobile/kiosk/lib/core/storage/kiosk_token_store.dart` storing the token in platform secure storage and wiping it on revocation

**Checkpoint**: Schema applied, a kiosk can be authenticated, permissions exist. User stories can begin.

---

## Phase 3: User Story 1 — Administrator puts a tablet into service (Priority: P1) 🎯 MVP

**Goal**: An administrator pairs a tablet to a branch, sees it in a device list, and can revoke it.

**Independent Test**: Pair a device, confirm it names the correct branch, confirm a second use of the same code is refused, revoke it and confirm it stops being served.

- [X] T022 [US1] Create `backend_medjet/core/KioskPairing.php` — issue a hashed single-use code with `expires_at` computed **in SQL** (`DATE_ADD(NOW(), INTERVAL ? SECOND)`), and redeem it through one guarded `UPDATE ... WHERE used_at IS NULL AND expires_at > NOW()` so two tablets racing one code cannot both pair
- [X] T023 [US1] Implement `backend_medjet/app/kiosk/create_pairing_code.php` — `X-Firebase-Token`, permission `kiosk_devices`, refuses when `branches.station_enabled = 0`, returns the plaintext code exactly once
- [X] T024 [US1] Implement `backend_medjet/app/kiosk/pair.php` — unauthenticated, rate-limited per IP via `RateLimiter`, creates the station row and issues the token, returns branch name and tenant timezone. Unknown/expired/consumed all return one `410` so the endpoint is not an oracle
- [X] T025 [US1] Implement `backend_medjet/app/kiosk/heartbeat.php` — `X-Kiosk-Token`, returns tenant-zone `server_time` via `TenantClock` plus branch settings; returns `401` on revocation, `426` below `medjat_kiosk_min_version`, `503` in maintenance
- [X] T026 [P] [US1] Implement `backend_medjet/app/kiosk/list.php` — permission `kiosk_devices`, returns each station's `app_version`, `below_min_version`, `last_seen_at`, `is_offline`, and `punch_count`
- [X] T027 [P] [US1] Implement `backend_medjet/app/kiosk/revoke.php` — permission `kiosk_devices`, sets station `revoked` and stamps the live token row; must not orphan `attendance.station_id` on historical rows
- [X] T028 [US1] Build the pairing screen in `frontend/mobile/kiosk/lib/view/pairing_screen.dart` — code entry, branch confirmation, and persistence of the returned token
- [X] T029 [US1] Build the heartbeat/bootstrap controller in `frontend/mobile/kiosk/lib/logic/kiosk_controller.dart` — on launch, resolve stored token → heartbeat → route to identify, pairing, update-required, or maintenance
- [X] T030 [P] [US1] Add a Kiosks tab to the branch screen in `frontend/mobile/manager/` — list, add (shows the code), and revoke, gated on `kiosk_devices`
- [X] T031 [P] [US1] Add the same Kiosks surface to `frontend/web/manager/`, gated on `kiosk_devices` from the permissions `login.php` already returns
- [ ] T032 [US1] **Verify**: pair a tablet; re-enter the same code on a second device and confirm `410`; revoke and confirm the first device gets `401` on its next heartbeat and wipes local state
- [ ] T033 [US1] **Verify**: sign in as a user without `kiosk_devices` and confirm both that `create_pairing_code.php` refuses and that the UI never shows the control (FR-061)

**Checkpoint**: A tablet can be put into service and taken out of service. Nothing can yet be recorded.

---

## Phase 4: User Story 2 — Administrator enrolls employees at the kiosk (Priority: P1)

**Goal**: A supervisor opens the kiosk's administration area with a generated code and enrolls a branch's workers face by face.

**Independent Test**: Enroll a previously unenrolled branch employee at the kiosk; confirm the enrollment appears in the management app attributed to that kiosk and that administrator.

- [X] T034 [US2] Implement `backend_medjet/app/kiosk/create_access_code.php` — `X-Firebase-Token`, permission `kiosk_access`, six digits, five-minute SQL-computed expiry, single use, stored hashed
- [X] T035 [US2] Implement `backend_medjet/app/kiosk/open_admin.php` — `X-Kiosk-Token` plus the code; issues a ten-minute `admin_session` refreshed by activity and returns `authorised_by` for the audit trail
- [X] T036 [P] [US2] Implement `backend_medjet/app/kiosk/admin/roster.php` — `X-Kiosk-Token` + `X-Kiosk-Admin-Session`, returns only **active** employees of the station's branch with their `face_enrolled` state, unenrolled sorted first
- [X] T037 [US2] Implement `backend_medjet/app/kiosk/admin/enroll.php` — validates `model_version` against `FaceMatchService::MODEL_VERSION`, enforces `BiometricEnrollment::MIN_QUALITY_SCORE` **server-side**, stores the photo via `BiometricEnrollment::storeReferencePhoto()`, writes the same `employees.face_*` columns as `app/biometric/enroll_face.php`, plus `face_enrolled_by_station_id`
- [X] T038 [US2] Add re-enrollment handling to `admin/enroll.php` — without `confirm_replace: true` an already-enrolled employee returns `409` naming the existing enrollment date; with it, the replacement is recorded rather than silently overwriting (FR-041)
- [X] T039 [P] [US2] Implement `backend_medjet/app/kiosk/admin/close.php` — ends the admin session, and with `release_kiosk_mode: true` releases kiosk mode
- [X] T040 [US2] Build the admin area in `frontend/mobile/kiosk/lib/view/admin_screen.dart` — code entry, roster list, and an idle timer that closes the area by itself (FR-038)
- [X] T041 [US2] Build the enrollment capture flow in `frontend/mobile/kiosk/lib/logic/enrollment_controller.dart`, reusing `lib/core/services/face_embedder.dart` and `face_liveness.dart` unchanged
- [X] T042 [P] [US2] Add "Open kiosk settings" (generate access code) to the branch screen in `frontend/mobile/manager/` and `frontend/web/manager/`, gated on `kiosk_access`
- [X] T043 [P] [US2] Surface enrollment provenance on the employee screen in `frontend/mobile/manager/` — enrolled, when, by whom, at which kiosk
- [ ] T044 [US2] **Verify**: enroll three employees in one session; confirm an employee of another branch never appears in the roster; confirm a deliberately blurred capture is refused with a reason and stores nothing
- [ ] T045 [US2] **Verify**: leave the admin area untouched and confirm it closes itself and returns to the identification screen; confirm a spent access code returns `410`

**Checkpoint**: A branch's workforce can be enrolled without anybody touching a phone.

---

## Phase 5: User Story 3 — Employee records attendance by face (Priority: P1)

**Goal**: An enrolled worker walks up, is recognised, and records a punch. This is the reason the feature exists.

**Independent Test**: An enrolled employee punches and a correctly attributed attendance row appears; an unenrolled person is matched to nobody; two lookalikes produce `ambiguous` rather than a guess.

- [X] T046 [US3] Create `backend_medjet/core/KioskIdentifier.php` — loads `face_embedding` for every active enrolled employee of the station's branch, scores all with `FaceMatchService::similarity()`, and returns best, runner-up, and candidate count
- [X] T047 [US3] Implement the acceptance rule in `KioskIdentifier` — accept only when `best ≥ threshold` **and** `best − runner_up ≥ margin`, reading `branches.station_match_threshold` / `station_match_margin` with system defaults 0.55 / 0.08. Failing the margin returns `ambiguous`, never the higher score (FR-044)
- [X] T048 [US3] Implement `backend_medjet/app/kiosk/challenge.php` — issues a nonce and liveness challenge into `face_challenges` with `employee_id = NULL`, `expires_at` computed **in SQL**
- [X] T049 [US3] Implement `backend_medjet/app/kiosk/identify.php` — consumes the nonce, rejects a mismatched `model_version`, runs `KioskIdentifier`, applies `station_gps_radius_meters` (FR-028) and the resolved attendance method (FR-030), honours `tenants.face_enforce_mode = 'log_only'`, and issues a short-lived `punch_ticket` naming the resolved employee
- [X] T050 [US3] Write a `station_recognition_logs` row on **every** outcome from `identify.php` — matched, ambiguous, no_match, liveness_failed, out_of_branch, wrong_method, too_soon, out_of_range — carrying `match_score`, `runner_up_score`, `threshold`, `margin`, and `candidates_searched` (FR-013, FR-046)
- [X] T051 [US3] Store the capture from each identification under `backend_medjet/uploads/kiosk/`, downscaled to a long edge of ~640 px at JPEG ~70 (target under 80 KB), and set `capture_expires_at` **in SQL** to the close of the punch's payroll cycle
- [X] T052 [US3] Implement `backend_medjet/app/kiosk/punch.php` — redeems the `punch_ticket`, writes through the existing `AttendanceModel` methods so `late_minutes`/`worked_minutes`/`overtime_minutes`/`status` cannot diverge from other channels, stamps time via `TenantClock`, and sets `check_in_method`/`check_out_method` = `kiosk`, `recognition_method` = `station_face`, `recognition_confidence`, and `station_id`
- [X] T053 [US3] Add idempotency to `punch.php` — a repeated `kiosk_idempotency_key` returns the **original** result with `200`, not an error (FR-027)
- [X] T054 [US3] Mirror kiosk refusals that resolve to a known employee into `attendance_security_logs` with the new `kiosk_*` reasons; attempts that identify nobody live only in `station_recognition_logs`, because that table's `employee_id` is `NOT NULL` (FR-034)
- [X] T055 [US3] Build the identification screen in `frontend/mobile/kiosk/lib/view/identify_screen.dart` — camera preview, liveness prompt, and a result state that renders `message_key` as guidance rather than as an error
- [X] T056 [US3] Build the confirmation screen in `frontend/mobile/kiosk/lib/view/confirm_screen.dart` — shows the resolved name and the correct direction, records on one press, then returns to identification after a short pause
- [ ] T057 [US3] **Verify**: enroll two similar-looking people, present a capture that scores close to both, and confirm `ambiguous` with no attendance row and both scores logged. **This is the single most important behaviour in the feature**
- [X] T058 [US3] **Verify**: send the same `punch.php` request twice with one idempotency key and confirm two `200`s and exactly one `attendance` row
- [ ] T059 [US3] **Verify**: set `tenants.timezone` to `Asia/Dubai`, punch, and confirm `attendance.check_in_time` reflects Dubai — a bare `date()` or `NOW()` anywhere in the write path shows up here as a multi-hour offset

**Checkpoint**: The MVP is complete. A worker with no smartphone can record their own attendance.

---

## Phase 6: User Story 4 — Employee records attendance by personal code (Priority: P2)

**Goal**: A fallback for the employee whose face will not resolve today.

**Independent Test**: Record a punch by code and confirm the resulting row is distinguishable in reporting from a face-identified one.

- [X] T060 [P] [US4] Implement `backend_medjet/app/kiosk/set_pin.php` — permission `manage_employees`, generates and hashes into `employees.kiosk_pin_hash`, returns the plaintext once, invalidates the previous code immediately
- [X] T061 [US4] Implement `backend_medjet/app/kiosk/identify_by_code.php` — returns the same envelope as `identify.php` with `method = 'code'`; refuses with `422` when `branches.station_code_fallback_enabled = 0`
- [X] T062 [US4] Add per-station rate limiting to `identify_by_code.php` via `RateLimiter`; crossing the threshold writes `kiosk_pin_bruteforce` to `attendance_security_logs` and returns `429` (FR-019)
- [X] T063 [US4] Build the code entry screen in `frontend/mobile/kiosk/lib/view/code_entry_screen.dart`, reachable from a failed identification and hidden when the branch has the fallback disabled
- [X] T064 [P] [US4] Add the kiosk code control to the employee screen in `frontend/mobile/manager/` and `frontend/web/manager/`, gated on `manage_employees`
- [X] T065 [P] [US4] Add the per-branch `station_code_fallback_enabled` toggle to the branch settings screen in `frontend/mobile/manager/`
- [ ] T066 [US4] **Verify**: punch by code and confirm the attendance row and its log row both show code identification, not face; confirm repeated wrong codes are throttled and flagged

**Checkpoint**: A bad face day no longer sends the branch back to manual entry.

---

## Phase 7: User Story 5 — The tablet stays a kiosk (Priority: P2)

**Goal**: An unattended wall tablet that cannot be navigated out of, and that comes back by itself after a power cut.

**Independent Test**: Attempt to leave the kiosk through every ordinary device gesture; confirm only an access code releases it; power-cycle and confirm it returns unattended.

- [X] T067 [US5] Implement screen pinning (lock task) entry and exit in `frontend/mobile/kiosk/lib/logic/kiosk_lock_controller.dart` — deliberately **not** `DEVICE_ADMIN`, which attracts Play policy scrutiny for no gain here
- [X] T068 [P] [US5] Hold a wakelock while the kiosk screen is foreground and return to identification after each interaction or a short idle period (FR-021)
- [X] T069 [P] [US5] Add a `BOOT_COMPLETED` receiver in `frontend/mobile/kiosk/android/app/src/main/kotlin/com/khawarizmie/medjat/kiosk/` so the tablet returns to its branch's kiosk screen after a restart with nobody signing in (FR-023)
- [X] T070 [US5] Wire kiosk-mode release to `admin/close.php` with `release_kiosk_mode: true`, reachable only through the administration area — never a static PIN
- [X] T071 [US5] Throttle repeated invalid access codes on the tablet and record the event (User Story 5 scenario 4)
- [ ] T072 [US5] **Verify on a physical Android tablet** — screen pinning and boot behaviour do not reproduce in an emulator. Confirm back, home, and recents cannot leave the kiosk, and that the screen never sleeps
- [ ] T073 [US5] **Verify the separation holds**: build both apps and run `aapt dump permissions` on each. The employee APK must carry **neither** `RECEIVE_BOOT_COMPLETED` nor `WAKE_LOCK`, and the two must report different package names. Then confirm the employee app still enrolls and verifies a face after the `medjat_shared` migration — that path now loads its model from a package asset, and a wrong asset key fails as "face unavailable" rather than as a build error

**Checkpoint**: The tablet behaves like an appliance rather than a phone lying on a table.

---

## Phase 8: User Story 6 — The kiosk fails honestly without internet (Priority: P2)

**Goal**: When the server is unreachable the tablet says so plainly, records nothing, tells management, and recovers by itself.

**Independent Test**: Disconnect the tablet, confirm it identifies nobody and states why; reconnect and confirm it resumes unattended with no punches invented and none lost.

- [X] T074 [US6] Add connectivity detection and a blocking offline state to `frontend/mobile/kiosk/lib/logic/kiosk_controller.dart` — no queue, no local roster, no local decision (FR-024)
- [X] T075 [US6] Build the offline screen in `frontend/mobile/kiosk/lib/view/offline_screen.dart` — tells the employee what to do instead, in the tenant's language, never a technical error
- [X] T076 [P] [US6] Build the update-required and maintenance screens in `frontend/mobile/kiosk/lib/view/` for the `426` and `503` heartbeat responses — the update message is addressed to a **supervisor**, not to the employee standing in front of it (FR-053)
- [X] T077 [US6] Implement outcome resolution on reconnect in the kiosk client — replay the pending punch with its original idempotency key rather than creating a new one, so a lost response cannot become a double punch
- [X] T078 [US6] Assert that no embedding, roster, or capture is written to device storage anywhere in the kiosk app — audit `lib/kiosk/` for persistence and confirm only the token is stored (FR-025)
- [X] T079 [US6] Add dark-kiosk detection to the existing alerting cron in `backend_medjet/app/cron/run_alerts.php` — a station whose `last_seen_at` has gone stale during its branch's working hours notifies management (FR-048)
- [ ] T080 [P] [US6] Surface kiosk outage windows beside branch attendance in `frontend/mobile/manager/` so missing punches have an explanation (FR-050)
- [ ] T081 [US6] **Verify**: pull the network mid-shift, confirm the tablet identifies nobody and states why; reconnect and confirm it resumes with no intervention and no invented punches
- [ ] T082 [US6] **Verify**: inspect the tablet's app storage after a full session and confirm no biometric data persists. If anything does, the offline capability was given up for a security property that was never delivered

**Checkpoint**: The failure mode is honest and visible instead of silent.

---

## Phase 9: User Story 7 — Management sees and governs kiosk activity (Priority: P3)

**Goal**: Kiosk activity is visible, tunable, and auditable — without which the threshold can never be set and the company eventually turns the feature off.

**Independent Test**: Produce a mix of successful and failed identifications and confirm all of them, with outcomes, are visible and filterable in the management app.

- [X] T083 [US7] Implement `backend_medjet/app/kiosk/recognition_logs.php` — permission `manage_attendance`, filters on branch/station/result/date, plus `view: "distribution"` returning a score histogram in the same shape as `app/attendance/face_logs.php`. **Omit `capture_path`** — reaching the image costs a different permission
- [X] T084 [US7] Implement `backend_medjet/app/kiosk/capture.php` — permission `kiosk_evidence`, returns a short-lived signed URL, writes an audit row on every call, and returns `410` once `capture_expires_at` has passed (FR-055, FR-059)
- [X] T085 [US7] Create `backend_medjet/app/cron/purge_kiosk_captures.php` — unlinks the file **then** nulls `capture_path`; deleting the row alone leaves the image on disk (FR-056)
- [X] T086 [P] [US7] Add kiosk activity and score distribution to the attendance section of `frontend/mobile/manager/` and `frontend/web/manager/`, gated on `manage_attendance`
- [X] T087 [P] [US7] Add "view capture" beside kiosk attendance rows, gated on `kiosk_evidence` — visible only to holders, per FR-061
- [X] T088 [P] [US7] Surface branches whose identification failure rate is abnormal, and kiosks unseen for an extended period, in the existing alerts surface (FR-032)
- [X] T089 [US7] Implement the roster-size warning (FR-047) — warn when a branch's enrolled roster passes the size at which the configured threshold and margin can still hold SC-013
- [ ] T090 [US7] **Verify**: confirm a user with `manage_attendance` but not `kiosk_evidence` can read scores and outcomes but cannot retrieve a single image
- [X] T091 [US7] **Verify**: run the purge against a capture with a past `capture_expires_at` and confirm the file is gone from disk, not merely hidden

**Checkpoint**: The feature can be tuned on real data instead of on the figures in research.md.

---

## Phase 10: Polish & Cross-Cutting Concerns

- [ ] T092 [P] Tune capture downscaling against real branch volume — at the 2 MB enrollment cap ten branches would generate roughly 34 GB a month, which is why kiosk captures are evidence, not reference images
- [X] T093 [P] Confirm every kiosk refusal path returns a `message_key` resolved through `I18n` in both `ar` and `en`, and that the kiosk renders RTL correctly with IBM Plex Sans Arabic
- [X] T094 Create the two Firebase Remote Config parameters `medjat_kiosk_min_version` and `medjat_kiosk_maintenance_enabled` in project `medjat` — without them the kiosk entry resolves to `0.0.0` and no version gate exists
- [X] T095 Add the capture purge to `/etc/cron.d/medjat` (Africa/Cairo) alongside the existing rollover, catch-up, and alert jobs
- [X] T096 Deploy with `backend_medjet/deploy.sh --dry-run`, then `deploy.sh`, then `backend_medjet/check-drift.sh` — never edit a file on the server, never run SQL by hand
- [X] T097 Write the threshold tuning runbook into `backend_medjet/app/kiosk/README.md` — ship every tenant in `log_only`, read the distribution, set threshold and margin, then switch to `enforce`. Record that `FaceMatchService::DEFAULT_THRESHOLD` is 0.450 for 1:1 while `tenants.face_match_threshold` still carries a column default of 0.650, so stored data and the PHP constant disagree
- [ ] T098 Run the full [quickstart.md](./quickstart.md) verification pass end to end on a physical tablet against the live backend

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: needs Setup — **blocks every user story**
- **US1 (Phase 3)**: needs Foundational. Blocks US2–US6 in practice: nothing can reach a kiosk that was never paired
- **US2 (Phase 4)**: needs US1. Blocks US3 in practice — 1:N has nothing to match against until somebody is enrolled
- **US3 (Phase 5)**: needs US2
- **US4 (Phase 6)**: needs US1; independent of US3 — a code path can be exercised without face matching working
- **US5 (Phase 7)**: needs US1 only. Almost entirely client-side, so it can run alongside US3/US4
- **US6 (Phase 8)**: needs US3 for the idempotency replay; the offline screens need only US1
- **US7 (Phase 9)**: needs US3 to have produced log rows worth reading
- **Polish (Phase 10)**: after the stories you intend to ship

### Honest note on story independence

The template asks for stories that are independently testable, and most here are.
**US1 → US2 → US3 is a genuine chain, not a scheduling preference.** You cannot
enroll at a kiosk that does not exist, and you cannot identify against an empty
roster. Treat those three as one MVP rather than three shippable increments.

### Parallel opportunities

- **Phase 1**: T001, T002 in parallel; T003 → T004 → T005 are sequential (the package must exist before either app can depend on it)
- **Phase 2**: T014, T015, T017, T018, T019, T021 all touch different files
- **US1**: T026 and T027 in parallel; T030 and T031 are the two management surfaces and can be split
- **US2**: T036 and T039 in parallel; T042 and T043 in parallel
- **US4**: T060, T064, T065 in parallel
- **US5**: T068 and T069 in parallel
- **US7**: T086, T087, T088 in parallel

---

## Implementation Strategy

### MVP

**Phases 1, 2, 3, 4, and 5** — Setup, Foundational, US1, US2, US3. That is the
whole of "a worker with no smartphone records their own attendance", and nothing
smaller delivers it.

At that point the feature is demonstrable but not deployable: it has no fallback
when a face will not resolve (US4), the tablet can be navigated out of (US5), and
it fails opaquely when the branch loses internet (US6).

### Incremental delivery

1. **MVP** (T001–T059) — the core loop works
2. **+ US5** (T067–T073) — it behaves like an appliance; ship to one pilot branch
3. **+ US4** (T060–T066) — bad-face days stop generating support calls
4. **+ US6** (T074–T082) — safe to deploy where connectivity is unreliable
5. **+ US7** (T083–T091) — the threshold can be tuned, which is what keeps it switched on
6. **Polish** (T092–T098)

### Sequencing warning

Do not defer **T057** (the ambiguity verification) to the end. It is the task most
likely to invalidate the operating point in [R-001](./research.md), and every
threshold in this plan is a starting point derived from LFW pairs rather than from
a branch. If the margin rule proves insufficient at realistic roster sizes, the
answer is a roster ceiling (T089) — not a looser margin.

---

## Task Summary

| Phase | Story | Tasks | Count |
|---|---|---|---|
| 1 | Setup | T001–T006 | 6 |
| 2 | Foundational | T007–T021 | 15 |
| 3 | US1 — pairing (P1) | T022–T033 | 12 |
| 4 | US2 — enrollment (P1) | T034–T045 | 12 |
| 5 | US3 — face attendance (P1) | T046–T059 | 14 |
| 6 | US4 — personal code (P2) | T060–T066 | 7 |
| 7 | US5 — kiosk lockdown (P2) | T067–T073 | 7 |
| 8 | US6 — honest offline (P2) | T074–T082 | 9 |
| 9 | US7 — governance (P3) | T083–T091 | 9 |
| 10 | Polish | T092–T098 | 7 |
| | **Total** | | **98** |

**MVP scope**: T001–T059 (49 tasks).
**Manual verification tasks**: 16, distributed across the stories — the only gate
this feature has, since the repository carries no test harness.
