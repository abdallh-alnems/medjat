# Implementation Plan: Rebuild Employee App — Phone + Activation Code Sign-In

**Branch**: `001-rebuild-employee-app` | **Date**: 2026-06-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-rebuild-employee-app/spec.md`

> **Audience note**: This plan is written so a *different* implementer (human or model) can execute it without re-discovering context. It names exact files, marks **[EXISTS]** vs **[NEW]** vs **[EDIT]** vs **[REWRITE]**, and prescribes order. Read [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), and [quickstart.md](./quickstart.md) before writing code. The original prose plan is `front_end/medjat_app/REBUILD_PHONE_CODE_PLAN.md` (Arabic) — this plan supersedes and structures it; where they differ, **follow this plan** because it is grounded in the current code (verified file paths, existing endpoints).

## Summary

Replace the employee app's authentication from **Firebase Auth (Google/Email) + activation** to **phone number + activation code → server-issued, device-bound token** (`X-Employee-Token`), while keeping Firebase Messaging/Crashlytics/Analytics. Add a parallel backend auth path (`Auth::authenticateEmployee`) without touching the management app's `Auth::authenticateUser`. Reconnect the already-present employee features (leave, attendance, payroll, profile/documents, notifications) to the new auth, and add a **Kiosk (shared attendance device) mode** that reuses the existing backend `station` endpoints (`X-Station-Token`, on-device face/fingerprint).

**Golden rule (spec FR-023 / SC-008): do not break the management app.** Every shared backend endpoint gets an employee-specific sibling rather than an in-place behavioral change, unless the change provably serves both paths.

## Technical Context

**Language/Version**: Dart 3 / Flutter (`get: ^4.7.2`) for the app; PHP (no framework, file-per-endpoint, PDO/MySQL) for the backend.
**Primary Dependencies**: App — GetX, `http`, `flutter_secure_storage`, `connectivity_plus`, `hive`, `firebase_messaging/crashlytics/analytics/remote_config/app_check` (kept), `geolocator`, `mobile_scanner`, `package_info_plus`, `open_filex`. Backend — `Database` helper, existing `Auth`/`Response`/`Validator`/`RateLimiter`/`TenantMiddleware`/`GpsService`/`SmartAlertService`, models `EmployeeAuthTokenModel`/`ActivationCodeModel`/`AttendanceStationModel`.
**Storage**: Backend MySQL (all tables already exist: `employee_auth_tokens`, `employee_activation_codes`, `attendance_stations`, `employees`, `branches`, `admins`, `admin_devices`, `notifications`, …). App — `flutter_secure_storage` for `auth_token` + `device_id` + `station_token`; `hive` for offline attendance queue.
**Testing**: `flutter test` (unit for model `fromJson`/`toJson` + controller logic; widget/integration for critical flows per constitution IV). Backend — manual `curl` acceptance per quickstart.md (no PHP test harness in repo).
**Target Platform**: Android + iOS (Arabic RTL). Backend — existing PHP host serving both apps.
**Project Type**: Mobile app + REST API (two real trees: `front_end/medjat_app`, `backend_medjet`).
**Performance Goals**: Sign-in to home < 60s (SC-001); leave submit < 90s (SC-005); kiosk pairing < 2 min and biometric check-in < 10s (SC-011). UI 60fps.
**Constraints**: Arabic RTL only; tokens only in `flutter_secure_storage` (constitution V); all HTTP through the single `CRUD` class (constitution III); no Firebase **Auth** anywhere after this; offline attendance must lose zero records (SC-006).
**Scale/Scope**: ~11 employee endpoints touched/added + 2 new auth endpoints + reuse of ~8 station endpoints; ~12 app files edited + ~5 new app files; 7 user stories.

## Constitution Check

*GATE: must pass before Phase 0 and re-checked after Phase 1.*

> Note: `.specify/memory/constitution.md` is still the **unfilled template** (placeholders only). No ratified principles exist to gate against. The table below applies the de-facto principles evident in `CLAUDE.md` + the existing codebase (GetX layering, CRUD-only HTTP, secure storage, Arabic RTL). **If the project later ratifies a real constitution, re-run this gate.**

| De-facto principle (from CLAUDE.md / codebase) | Plan compliance | Status |
|---|---|---|
| Arabic-First, RTL-Native | All new screens (login, kiosk pairing, kiosk attendance) reuse the existing RTL theme + Cairo font + `PrimaryInput`/`PrimaryButton`; user-facing strings in Arabic. | ✅ PASS |
| GetX architecture consistency | New code follows `core/`/`data/`/`logic/`/`view/` layout; new `StationController`, `AuthController` rewrite, `StationData`, `station_binding`; mirrors existing structure. | ✅ PASS |
| Layered data flow (CRUD-only HTTP) | All HTTP stays in `CRUD`; controllers → `*Data` → `CRUD`. New `X-Employee-Token`/`X-Station-Token` headers added inside `CRUD` only. Models keep `fromJson`/`toJson`. `StatusRequest` used throughout. | ✅ PASS |
| Test coverage for critical paths | Unit tests for `UserModel`, `StationModel`, token/device storage, and auth/leave/attendance controller logic; widget test for login + kiosk check-in. | ✅ PASS (enforced in tasks) |
| Secure credential handling | `auth_token`, `device_id`, `station_token` only in `flutter_secure_storage`; basic-auth + host from `.env`; backend stores only SHA-256 token hash; auth validated on launch (splash). | ✅ PASS |

**Initial gate: PASS. No violations → Complexity Tracking omitted.**

## Project Structure

### Documentation (this feature)

```
specs/001-rebuild-employee-app/
├── plan.md                    # This file
├── research.md                # Phase 0 — decisions & rationale (D1–D10)
├── data-model.md              # Phase 1 — entities → existing tables + app models
├── contracts/                 # Phase 1 — exact request/response contracts
│   ├── auth.md                #   employee_login, employee_logout, authenticateEmployee
│   ├── employee-endpoints.md  #   leave, attendance, payroll, profile, notifications, fcm
│   └── kiosk.md               #   station activate/sync/check_in_out/heartbeat/enroll/verify_pin
├── quickstart.md              # Phase 1 — curl acceptance gate + Flutter run/verify steps
├── checklists/requirements.md # (from /speckit.specify)
└── tasks.md                   # Phase 2 — created by /speckit.tasks, NOT here
```

### Source Code (repository root)

```
backend_medjet/                         # PHP REST API (serves BOTH apps)
├── core/Auth.php                        # [EDIT] add authenticateEmployee(); DO NOT touch authenticateUser()
├── models/
│   ├── EmployeeAuthTokenModel.php       # [EDIT] add issue(), findActiveByPlain(), revokeByPlain()
│   └── ActivationCodeModel.php          # [EDIT] add markUsedByDevice(); keep markUsed()
└── app/
    ├── auth/
    │   ├── employee_login.php           # [NEW] phone+code → token
    │   ├── employee_logout.php          # [NEW] revoke token
    │   ├── update_fcm_token.php         # [EDIT] authenticateEmployee → $auth['admin_id']
    │   └── notification_prefs.php       # [EDIT] authenticateEmployee → $auth['admin_id']
    ├── employees/my_profile.php         # [NEW] employee self profile (+documents)
    ├── leaves/
    │   ├── my_balance.php               # [NEW] employee self balance (sibling of get_balance.php)
    │   └── apply.php                    # [EDIT] authenticateEmployee path
    ├── attendance/{check_in,check_out,get_my_attendance,sync_offline}.php  # [EDIT]
    ├── payroll/get_slip.php             # [EDIT] authenticateEmployee path (+ pdf variant)
    └── notifications/{list,read}.php    # [EDIT] authenticateEmployee → $auth['admin_id']
    # station/* and stations/* endpoints: [EXISTS, REUSE AS-IS] for Kiosk

front_end/medjat_app/                    # Flutter (employee app) — the rebuild target
├── pubspec.yaml                         # [EDIT] remove firebase_auth + google_sign_in; keep messaging etc.
├── lib/
│   ├── main.dart                        # [EDIT] keep Firebase.init (messaging); drop any Auth-only calls
│   ├── core/
│   │   ├── class/crud.dart              # [EDIT] swap Firebase header → X-Employee-Token + X-Tenant-Id; central 401
│   │   ├── middleware/auth_middleware.dart       # [EDIT] token-based gate (no FirebaseAuth)
│   │   ├── services/
│   │   │   ├── token_storage_service.dart        # [EDIT, EXISTS] add getOrCreateDeviceId(), station_token, clearSession()
│   │   │   └── push_notification_service.dart    # [EDIT, EXISTS] register FCM after login via X-Employee-Token
│   │   └── constant/
│   │       ├── id/app_links.dart        # [EDIT] new endpoint set — dir is constant/id (NOT api)
│   │       └── routes/
│   │           ├── app_routes.dart      # [EDIT] add kioskPair, kioskHome
│   │           └── app_pages.dart       # [EDIT] GetX DI lives here (no app_bindings.dart); drop Firebase-auth wiring; add StationData/Controller
│   ├── data/
│   │   ├── data_source/remote/
│   │   │   ├── auth_data/auth_data.dart           # [REWRITE, EXISTS] login/logout/getProfile (no Firebase)
│   │   │   └── station_data/station_data.dart     # [NEW] kiosk endpoints
│   │   └── model/                                  # NOTE: singular "model"
│   │       ├── user_model.dart          # [EDIT, EXISTS] read profile_image; email optional
│   │       └── station_model.dart       # [NEW] station + branch-employee + sync payload
│   ├── logic/
│   │   ├── bindings/                     # [EXISTS] attendance_binding, home_binding (+ add station_binding.dart [NEW])
│   │   └── controller/
│   │       ├── auth/auth_controller.dart          # [REWRITE, EXISTS] phone+code login, isLoggedIn, logout
│   │       └── station/station_controller.dart    # [NEW] kiosk pairing + check-in flow
│   └── view/screen/
│       ├── auth/login_screen.dart       # [REWRITE, EXISTS] phone + code fields + "Kiosk mode" entry
│       ├── splash/splash_screen.dart    # [EDIT, EXISTS] token-based routing (already uses TokenStorageService directly)
│       └── kiosk/                        # [NEW] kiosk_pair_screen.dart, kiosk_home_screen.dart
└── test/                               # [NEW/EDIT] unit + widget tests for the above
```

> **Path reality notes (verified against the tree — the original REBUILD plan's paths are slightly off):** `app_links.dart` is under `lib/core/constant/id/` (not `api/`). Data sources live in per-feature folders (`auth_data/auth_data.dart`, etc.). Models are under `lib/data/model/` (singular). GetX DI is wired in `lib/core/constant/routes/app_pages.dart` (there is **no** `app_bindings.dart`). `token_storage_service.dart` and `push_notification_service.dart` **already exist** — extend, don't recreate. The splash is a screen that already reads `TokenStorageService` directly (no separate controller).
>
> **Backend reality note (verified):** `app/employees/activation_code.php` (admin) ALREADY satisfies FR-009 — on regenerate it calls `EmployeeAuthTokenModel::revokeForEmployee(... 'admin_regenerated_code')` and sets `employees.status='pending_activation'`. So code re-issue invalidates the session with **no backend change**. Consequently `employee_login.php` MUST set `status='active'` again on success.

**Structure Decision**: Mobile-app + API. Two existing trees, both modified in place on this branch. **Order is mandatory: backend first, then Flutter** (the app cannot be verified until the endpoints answer). Within the app, build the auth core (`token_storage_service` → `crud` → `auth_data`/`auth_controller` → `splash`/`login`) before reconnecting features; build Kiosk (US7) last.

## Phase 0 — Research

See [research.md](./research.md). All Technical Context items are resolved (no remaining NEEDS CLARIFICATION); the spec's two clarify sessions already fixed the open product questions. Research records the *technical* decisions: token issuance/hashing, the parallel-auth strategy, `device_id` stability, the central 401 handler, offline de-dup, FCM-without-Firebase-Auth, and Kiosk endpoint reuse.

## Phase 1 — Design & Contracts

- [data-model.md](./data-model.md) — entities mapped to existing DB tables + app models with `fromJson`/`toJson` and state transitions (code lifecycle, session lifecycle, attendance state, station lock).
- [contracts/](./contracts/) — exact request/response for every new and edited endpoint, plus the reused station endpoints. The implementer must match field names exactly (app and backend are co-designed here).
- [quickstart.md](./quickstart.md) — the backend `curl` acceptance gate (run BEFORE any Flutter work) and the Flutter build/verify steps mapped to acceptance criteria.

## Post-Design Constitution Re-Check

Re-evaluated after Phase 1 design: no new violations. Kiosk mode adds screens/controllers but stays within GetX layering and reuses existing backend contracts; biometric matching is on-device but introduces no Firebase-Auth dependency and no insecure storage. **Gate: PASS.**

## Complexity Tracking

No constitutional violations — table intentionally empty.

## Phases beyond this command

- **Phase 2** (`/speckit.tasks`): turn this into an ordered, dependency-aware `tasks.md` (backend models → backend endpoints → curl gate → app auth core → feature reconnection → kiosk → tests).
- **Phase 3+**: implementation + verification against quickstart.md.
