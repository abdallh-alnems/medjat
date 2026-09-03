# Implementation Plan: Admin Support & App Control Center

**Branch**: `002-admin-support-control` | **Date**: 2026-06-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-admin-support-control/spec.md`

## Summary

Extend the **permedjat_admin** Flutter app (the platform's super-admin / support-team panel) with two capabilities over the existing PHP/MySQL backend:

1. **Support inbox & chat** — list all tenant support tickets, open a ticket, view the full message thread, reply (text only), change status, filter by status/company, with live refresh of new messages and push alerts to support devices.
2. **App control center** — a `superadmin`-only screen that reads and writes the per-app **minimum required version** and **stop/maintenance switch** by updating the shared **Firebase Remote Config** keys the apps already consume. The backend performs the Remote Config writes via the already-vendored `kreait/firebase-php` Admin SDK.

Most of the support backend already exists (`app/admin_support/{list,reply,messages}.php`, `SupportModel`); this feature mainly adds the **Flutter operator experience**, a few **missing backend endpoints** (ticket status change, app-control read/write, super-admin device registration + push), and **app-side wiring** so the Employee and Admin apps read their Remote Config keys (the HR app already does).

## Technical Context

**Language/Version**: PHP 8.x (backend), Dart 3.11 / Flutter (permedjat_admin app), GetX state management
**Primary Dependencies**: Backend — `kreait/firebase-php` (Remote Config + FCM, already vendored), existing `AdminAuth`/`AdminBaseApi`/`Database`/`NotificationService`. Frontend — `get`, `http`, `flutter_secure_storage`, `flutter_dotenv`; **NEW**: `firebase_core` + `firebase_messaging` in permedjat_admin (currently absent) for support push only
**Storage**: MySQL 8 via MAMP (`permedjat`, host 127.0.0.1 port 8889, root/root). Tables `support_tickets`, `support_messages` already exist (migration `2026_06_support.sql`). Firebase Remote Config holds the app-control values. **NEW** table for super-admin device tokens
**Testing**: `flutter_test` for the admin app; backend follows existing manual/endpoint conventions (no formal PHP test suite in repo)
**Target Platform**: Android + iOS (permedjat_admin); PHP web API behind `config/bootstrap.php`
**Project Type**: Mobile app + API (Option 3)
**Performance Goals**: First reply to a waiting ticket < 60s (SC-001); new message visible in an open thread < 10s via polling (SC-003); maintenance/version change effective within one app launch/foreground (SC-004/005)
**Constraints**: Reuse existing apps' Remote Config read logic unchanged (HR app `UpdateService` + `MaintenanceGate`); Admin app is version-only (no kill switch); replies text-only; shared ticket queue (no assignment) in v1
**Scale/Scope**: Small operator audience (platform support team). New scope ≈ 1 DB migration, ~6 backend endpoints, ~3 Flutter screens + controllers/data layers, app-side RC wiring for 2 apps

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution (`.specify/memory/constitution.md`) is the **unmodified template** (placeholder tokens, not ratified). There are therefore **no project-specific gates** to enforce. General principles applied by default:

- **Simplicity / YAGNI**: reuse existing `SupportModel`, `AdminAuth`, Remote Config keys; no new frameworks; v1 deliberately excludes attachments, ticket assignment, custom maintenance messages, per-platform versions.
- **Reuse over rebuild**: extend existing `admin_support` endpoints and admin-app GetX feature pattern rather than introduce new patterns.
- **No unjustified complexity**: the only genuinely new infrastructure is super-admin push (an explicit user decision), tracked as a risk below.

**Result**: PASS (no violations; nothing to record in Complexity Tracking).

## Project Structure

### Documentation (this feature)

```text
specs/002-admin-support-control/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (endpoint contracts)
│   ├── admin_support.md
│   ├── app_control.md
│   └── support_push.md
├── checklists/
│   └── requirements.md  # from /speckit.specify
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created here)
```

### Source Code (repository root)

```text
backend_medjet/
├── app/
│   ├── admin_support/
│   │   ├── list.php            # EXISTS — all-tenant ticket list (admin)
│   │   ├── messages.php        # EXISTS — thread + mark-read (admin)
│   │   ├── reply.php           # EXISTS — support reply (admin)
│   │   └── status.php          # NEW — change ticket status (resolved/closed/reopen)
│   ├── admin_app_control/
│   │   ├── get.php             # NEW — read current min-version + maintenance per app (superadmin)
│   │   └── set.php             # NEW — write Remote Config min-version / maintenance (superadmin)
│   └── support/                # EXISTS (tenant side) — add push-to-support on create/reply
├── core/
│   ├── RemoteConfigService.php # NEW — wraps kreait Remote Config template read/update
│   └── NotificationService.php # EXTEND — sendToSupportTeam() via super-admin device tokens
├── models/
│   └── SupportModel.php        # EXISTS — has setTicketStatus/assign already
└── migrations/
    └── 2026_06_admin_support_control.sql   # NEW — super_admin_devices table (+ optional app_control mirror)

frontend/mobile/superadmin/lib/
├── core/constant/id/app_links.dart        # EXTEND — support + app-control endpoints
├── core/constant/routes/{app_routes,app_pages}.dart  # EXTEND — routes + bindings
├── data/model/
│   ├── support_ticket_model.dart           # NEW
│   ├── support_message_model.dart          # NEW
│   └── app_control_model.dart              # NEW
├── data/data_source/remote/
│   ├── support_data/support_data.dart      # NEW
│   └── app_control_data/app_control_data.dart  # NEW
├── logic/controller/
│   ├── support/support_controller.dart     # NEW — inbox + thread + polling
│   └── app_control/app_control_controller.dart # NEW (replaces force_update flow)
└── view/screen/
    ├── support/support_inbox_screen.dart   # NEW
    ├── support/support_thread_screen.dart  # NEW
    └── app_control/app_control_screen.dart # NEW

frontend/mobile/employee/  (Employee) — verify/add RC read of medjat_app_min_version + medjat_app_maintenance_enabled
frontend/mobile/manager/ (HR) — already reads permedjat_central_* keys (no change)
```

**Structure Decision**: Mobile + API (Option 3). The backend extends the existing `app/admin_*` endpoint convention (thin PHP files using `AdminAuth::require()` + `SupportModel`/new services). The admin app follows its established GetX layering: `data/model` → `data/data_source/remote/*_data` → `logic/controller/*` → `view/screen/*`, registered via `*Binding` classes in `app_pages.dart`. The deprecated `force_update` flow is superseded by `app_control`.

## Complexity Tracking

> No constitution violations. Not applicable.

## Risks & Notes

- **Support push (FR-010b / SC-009) is the largest new surface.** permedjat_admin has **no Firebase** today (username/password auth, no `firebase_*` packages). Delivering push requires adding `firebase_core`+`firebase_messaging`, a `google-services.json`/`GoogleService-Info.plist`, a new `super_admin_devices` table, a device-register endpoint, and `NotificationService::sendToSupportTeam()`. **Mitigation**: ship US1 (inbox+reply+live refresh via polling) and US2 (app control) first; push can land as a follow-up slice without blocking core value. In-app unread indicators (`unread_for_support`) work without Firebase.
- **App-control is backend-only Firebase.** The admin app calls `admin_app_control/{get,set}.php`; the backend uses `kreait/firebase-php` to read/update the Remote Config template. The admin app needs **no** Firebase for this. Confirm a service-account credential is available to the backend (same one used by existing `NotificationService`).
- **Employee + Admin app RC wiring.** The HR app already reads its keys. Confirm the Employee app reads `medjat_app_min_version` / `medjat_app_maintenance_enabled`; add the gate/service if missing. The Admin app needs a `medjat_admin_min_version` force-update check (version-only, no maintenance).
- **Live refresh = polling.** Reuse the existing `after_id` parameter on `admin_support/messages.php`; controller polls every ~5s while a thread is open (meets SC-003's 10s).
- **Roles.** Support endpoints require `admin`; app-control endpoints require `superadmin` (`AdminAuth::require('superadmin')`), matching the existing force-update endpoint.

## Phase 0 / Phase 1 outputs

See `research.md`, `data-model.md`, `contracts/`, and `quickstart.md` in this directory.
