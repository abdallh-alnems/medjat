# Tasks: Web Attendance Check-In / Check-Out

**Input**: Design documents from `/specs/004-web-attendance-checkin/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: The specification does not request TDD. Test tasks appear only where
`plan.md` already commits to the tooling (`vitest`, `playwright` — both already
configured in `medjat_central_web`). There is no PHP test harness in this repo,
so backend verification is the manual matrix in `quickstart.md`.

**Organization**: Grouped by user story so each can be implemented, tested and
shipped on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different files, no dependency on incomplete work
- **[Story]**: US1 / US2 / US3, mapping to the user stories in spec.md

## Path Conventions

- Backend: `backend_medjet/` — one endpoint per file under `app/<module>/`, shared logic in `core/`
- Employee web: `frontend/web/central/src/`
- Admin app: `frontend/mobile/central/lib/`

---

## Phase 1: Setup

**Purpose**: Establish a known-clean starting point and the route scaffolding.

- [X] T001 Run `backend_medjet/check-drift.sh` and resolve any drift before writing code — starting from a drifted state makes your changes indistinguishable from someone else's later
- [X] T002 [P] Create the isolated employee route group at `frontend/web/central/src/app/(employee)/layout.tsx` with its own providers, importing nothing from the `(app)` admin tree
- [X] T003 [P] Create the employee API client at `frontend/web/central/src/lib/api/employee.ts` — separate axios instance sending `X-Employee-Token`, never the admin Firebase token
- [X] T004 [P] Create the feature folder `frontend/web/central/src/features/employee-attendance/` with `schemas.ts` (Zod) and `hooks.ts` (TanStack Query) stubs
- [X] T005 Confirm `npm run dev:https` serves over TLS — geolocation and camera are secure-context APIs and fail confusingly over plain HTTP

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema and core services every user story depends on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T006 Write migration `backend_medjet/migrations/2026_08_03_employee_web_sessions.sql` — create `employee_web_credentials`; `MODIFY` `employee_auth_tokens.platform` to `enum('android','ios','web')` restating **all three** values; add nullable `expires_at`. Header comment must state why nullable (a non-null default would start expiring every phone already in the field)
- [X] T007 [P] Write migration `backend_medjet/migrations/2026_08_03_attendance_punch_photo.sql` — add `check_in_origin`, `check_out_origin`, `check_in_photo`, `check_out_photo`, `shared_device_flag` to `attendance`; `MODIFY` the `attendance_security_logs.reason` enum adding `web_not_permitted`, `web_pin_locked`, `web_shared_device` while restating every existing value
- [X] T008 [P] Write migration `backend_medjet/migrations/2026_08_03_web_attendance_settings.sql` — add `tenants.web_attendance_enabled` DEFAULT 0 and `tenants.web_attendance_photo_required` DEFAULT 1; add nullable `employee_categories.web_attendance_allowed`
- [X] T009 Apply all three locally with `backend_medjet/migrations/migrate.sh` and confirm against MAMP that defaults leave existing rows untouched
- [X] T010 [P] Create `backend_medjet/models/EmployeeWebCredentialModel.php` — `password_hash` storage, 6-digit and non-trivial validation, `failed_attempts`, `locked_until` computed **in SQL** via `DATE_ADD(NOW(), INTERVAL ? SECOND)`
- [X] T011 [P] Create `backend_medjet/core/WebSessionService.php` — issue (expiry in SQL, 16 h), verify, revoke; issuing revokes the employee's other `platform='web'` rows **only**, never app tokens
- [X] T012 [P] Create `backend_medjet/core/PunchPhotoService.php` — mirror `BiometricEnrollment::storeReferencePhoto()`: base64 decode, byte cap, `getimagesizefromstring()` confirmation before writing under `.jpg`, store to `uploads/attendance/`
- [X] T013 [P] Create `backend_medjet/core/SharedDeviceDetector.php` — given tenant, `device_id` and the tenant working day, return the other employees who punched from that device
- [X] T014 Extend `backend_medjet/models/EmployeeAuthTokenModel.php` so `findActiveByPlain()` treats a past `expires_at` as inactive — **without this the 16-hour limit silently does nothing**, since the current query only checks `revoked_at`
- [X] T015 Create `backend_medjet/core/WebAccessPolicy.php` — resolves company + category permission into allow/refuse; returns a reason so callers can log it. Used by every web endpoint

**Checkpoint**: Schema applied, services unit-callable, app behaviour unchanged.

---

## Phase 3: User Story 1 — Employee records attendance from a browser (P1) 🎯 MVP

**Goal**: An employee with no app installed can activate, check in, and check out from a browser.

**Independent test**: On a device with no Medjat app, open the link, activate with a phone and activation code, check in inside a branch's approved area, and confirm the punch appears in that employee's attendance record carrying the same fields an app punch carries.

**Note**: Testable with `tenants.web_attendance_enabled = 1` set directly in the test database — the settings UI is US2.

### Backend

- [X] T016 [US1] Create `backend_medjet/app/auth/employee_web_activate.php` — consume the single-use activation code, create the credential and issue the session **in one transaction** (a consumed code that produced no credential strands the employee), per `contracts/employee-web-auth.md`
- [X] T017 [US1] Create `backend_medjet/app/auth/employee_web_login.php` — phone + PIN; return an **identical** `invalid_credentials` error for wrong phone and wrong PIN, so the response cannot be used to discover which numbers are enrolled
- [X] T018 [P] [US1] Create `backend_medjet/app/auth/employee_web_logout.php` — revoke the presenting session; idempotent
- [X] T019 [P] [US1] Create `backend_medjet/app/attendance/web_status.php` — today's state from **any** channel, branch geofence, `photo_required`, `network_constraint` (`ip`|`none`), and `server_time` from `TenantClock`
- [X] T020 [US1] Extend `backend_medjet/app/attendance/check_in.php` — derive origin from the **session**, never the request body; accept `photo_base64`; refuse with `photo_required` when the company requires one and none is usable; ignore any `bssid` or `is_mock_location` sent by a web client
- [X] T021 [US1] Extend `backend_medjet/app/attendance/check_out.php` — same additions, plus **revoke the web session on success** and return `session_ended: true`
- [X] T022 [P] [US1] Create `backend_medjet/app/employees/reset_web_pin.php` — delete the credential, revoke live web sessions immediately, issue a fresh activation code, write an audit entry (FR-002d; without it a locked-out employee has no way back)
- [X] T023 [US1] Apply `RateLimiter::enforceIpLimit()` plus phone-keyed `RateLimiter::checkLimit()` to T016 and T017, and wire the 5-failure lockout, writing `web_pin_locked` to `attendance_security_logs`

### Employee web surface

- [X] T024 [P] [US1] Implement the browser identity cookie in `frontend/web/central/src/features/employee-attendance/device-id.ts` — random UUID, long-lived, sent as `device_id`
- [X] T025 [US1] Build the activation page `frontend/web/central/src/app/(employee)/activate/page.tsx` — phone, activation code, choose and confirm a 6-digit PIN, with client-side Zod mirroring the server rules
- [X] T026 [US1] Build the sign-in page `frontend/web/central/src/app/(employee)/login/page.tsx` — phone (remembered locally) + PIN, with a distinct locked-account state pointing the employee at their administrator
- [X] T027 [US1] Build the attendance page `frontend/web/central/src/app/(employee)/attendance/page.tsx` — render state from `web_status.php`, request geolocation, warm the camera only when `photo_required`, and show one primary button
- [X] T028 [US1] Implement the pre-capture consent notice on the attendance page — the employee must be told the image is being captured and retained **before** it is taken (FR-017c)
- [X] T029 [US1] Implement the failure and permission states — location denied, camera denied, outside the geofence, network refusal, session expired (return to PIN with phone pre-filled), and **connection lost mid-punch: re-read `web_status.php` and state plainly whether the punch landed** (FR-011)
- [X] T030 [P] [US1] Add Arabic and English strings and confirm RTL rendering across all three employee pages
- [X] T031 [P] [US1] Ensure the session cookie is set **httpOnly, Secure, SameSite=Lax** — not `localStorage`, which any injected script can read

### Verification

- [X] T032 [P] [US1] Vitest unit tests in `frontend/web/central/src/features/employee-attendance/__tests__/` — PIN validation, attendance state machine, device-id persistence
- [ ] T033 [US1] Playwright e2e in `frontend/web/central/e2e/employee-attendance.spec.ts` — activate → check in → check out → confirm the session is dead, with geolocation and camera mocked
- [X] T034 [US1] Manually verify on a real device that a **denied** location permission behaves sanely on both Safari iOS and Chrome Android — denial behaviour differs between them and is not faithfully reproduced by Playwright

**Checkpoint**: US1 is independently shippable. A company flipped on in the database gets working browser attendance.

---

## Phase 4: User Story 2 — Company decides whether the channel is allowed (P2)

**Goal**: Administrators can enable, disable and scope the channel, and are told plainly what it cannot verify.

**Independent test**: Toggle the setting on a company and confirm web check-in becomes available then unavailable to its employees, with no effect on any other company or on app check-in.

- [X] T035 [US2] Extend `backend_medjet/app/settings/company.php` — read and write `web_attendance_enabled` and `web_attendance_photo_required` behind `manage_company_settings`, and write an `AuditLogModel` entry on every change (FR-024)
- [X] T036 [US2] Add `web_channel_limitations` and `branches_without_ip_networks` to the `company.php` response — the second requires checking each branch for any `ip_v4`/`ip_cidr` row in `branch_networks`, so the UI can name the branches that have **no** network control on this channel
- [X] T037 [P] [US2] Create `backend_medjet/app/categories/update_web_access.php` — set `web_attendance_allowed` to true/false/null behind `manage_company_settings`
- [X] T038 [US2] Wire `WebAccessPolicy` (T015) into T016, T017, T019, T020 and T021 so a refusal returns `web_not_permitted` **and** writes that reason to `attendance_security_logs`
- [X] T039 [US2] Verify a company that has never touched the settings still refuses every web endpoint while its app attendance is untouched (SC-006) — this is the release-safety property, worth testing explicitly rather than assuming
- [X] T040 [US2] Build the settings UI in `frontend/mobile/central/lib/view/screen/settings/` — the two toggles, per-category access, and the honest disclosure of what the browser cannot verify (WiFi BSSID, mock-location, face) with the branch warning from T036
- [X] T041 [US2] Confirm the frontend menu/tab gate uses **exactly** `manage_company_settings` — a mismatch surfaces to the user as a bare "an error occurred", which is the hardest class of bug to diagnose from a support ticket
- [ ] T042 [US2] Verify an employee whose shift is open when the company disables the channel **can still close it**, while new check-ins are refused
      *Implemented 2026-08-15*: `check_out.php` now permits the close when `AttendanceModel::hasOpenDay()` is true and logs it as `flagged` instead of `blocked`; the comment above it had described this behaviour while the code refused. Still needs the live check.

**Checkpoint**: The channel is governable and safe to release, because it ships off.

---

## Phase 5: User Story 3 — Manager reviews who actually punched (P3)

**Goal**: Evidence and shared-device flags reach the manager reviewing attendance.

**Independent test**: Record web punches for two different employees from the same browser and device, then confirm both the captured images and the shared-device flag are visible to a manager reviewing attendance.

- [X] T043 [US3] Wire `SharedDeviceDetector` (T013) into T020 and T021 — when a second employee punches from the same `device_id` within the tenant working day, set `shared_device_flag` on **this punch and the other employee's punches too**; a flag that marked only the second party would read as an accusation of one side
- [X] T044 [US3] Write `web_shared_device` to `attendance_security_logs` on detection, and confirm it **never** rejects the punch (FR-020) — consistent with how `is_vpn` and the existing flags already behave
- [X] T045 [P] [US3] Expose `check_in_origin`, `check_out_origin`, `check_in_photo`, `check_out_photo` and `shared_device_flag` in the attendance read endpoints consumed by `medjat_central`
- [X] T046 [US3] Serve punch images only to callers permitted to review that employee's attendance — an unauthenticated path under `uploads/` would publish employees' photographs to anyone who guesses a filename
- [X] T047 [US3] Surface the image and the shared-device flag in the `medjat_central` attendance review screen
- [X] T048 [US3] Verify the flag is advisory in the UI — presented as information for a human decision, never as an automatic rejection

**Checkpoint**: All three stories complete.

---

## Phase 6: Polish & Deployment

- [X] T049 [P] Run `flutter analyze lib` in `frontend/mobile/central` (bare `flutter analyze` reports phantom errors from FlutterFire examples under `build/`)
- [X] T050 [P] Run `npm run lint` and `npm test` in `frontend/web/central`
- [X] T051 [P] Lint every changed PHP file with the MAMP binary `/Applications/MAMP/bin/php/php8.4.15/bin/php -l`
- [ ] T052 Work through the manual verification matrix in `quickstart.md` §6 — the cross-channel and clock-skew rows in particular, which no automated test covers
- [ ] T053 Run `backend_medjet/check-drift.sh`, then `deploy.sh --dry-run`, then `deploy.sh`, then `check-drift.sh` again — it must come back clean
- [ ] T054 Build and restart the front end separately — `deploy.sh` does **not** deploy it; it is the systemd unit `medjat-web.service` on Hetzner
- [ ] T055 Enable the channel for **one** willing company and read `attendance_security_logs` for a week before offering it more widely

---

## Dependencies

```
Phase 1 Setup
    ↓
Phase 2 Foundational  ← blocks everything
    ↓
Phase 3 US1 (P1)  ← MVP, independently shippable
    ↓
Phase 4 US2 (P2)  ← needs US1's endpoints to gate
    ↓
Phase 5 US3 (P3)  ← needs US1's punch path to flag
    ↓
Phase 6 Polish
```

**Story independence**: US1 stands alone (enable the flag in the database). US2
and US3 both extend US1's endpoints, so they follow it — but they are independent
of **each other** and can be built in either order or in parallel by two people.

**Within Phase 2**: T006 must land before T009. T007, T008, T010–T013 are
parallel. T014 depends on T006 (it reads the new `expires_at`). T015 depends on
T008.

**Within Phase 3**: T016 and T017 share the credential model, so serialise them.
T018, T019, T022, T024 are parallel. T020 and T021 touch adjacent logic in two
files and are safest serialised. Frontend T025–T027 depend on the endpoints they
call.

---

## Parallel Execution Examples

**Phase 2** — after T006 lands:

```
T007  attendance + security-log migration
T008  settings migration
T010  EmployeeWebCredentialModel
T011  WebSessionService
T012  PunchPhotoService
T013  SharedDeviceDetector
```

**Phase 3** — two people:

```
Person A (backend):  T016 → T017 → T020 → T021 → T023
Person B (frontend): T024 → T025 → T026 → T027 → T030
```

**Phase 6**: T049, T050 and T051 are three separate toolchains — run together.

---

## Implementation Strategy

### MVP — stop here and it is still worth shipping

**Phases 1 + 2 + 3 (T001–T034).** An employee with no app installed can activate
and record attendance from a browser. Enable it for one company by hand and it
delivers real value with no admin surface at all.

### Increment 2 — make it releasable to everyone

**Phase 4 (T035–T042).** Until this lands, enabling the channel means editing the
database, so it cannot be offered to customers. This is what turns the MVP into a
product.

### Increment 3 — make it trustworthy

**Phase 5 (T043–T048).** Without it the channel records attendance but produces no
reviewable evidence — acceptable for an office pilot, not for a company that
cares about attendance fraud.

### Two things to hold onto while building

1. **T014 is load-bearing and easy to skip.** The 16-hour limit is a column
   nobody reads until `findActiveByPlain()` is changed. Skip it and every session
   is immortal, which is precisely the shared-device hole the design exists to
   close — and nothing will fail visibly to tell you.
2. **Ship with the channel off.** The default in T008 is what makes SC-006 true.
   A deploy must change nothing for any existing company until someone opts in.
