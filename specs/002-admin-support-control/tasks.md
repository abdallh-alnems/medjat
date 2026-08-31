# Tasks: Admin Support & App Control Center

**Input**: Design documents from `/specs/002-admin-support-control/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not requested in the spec → no dedicated TDD phase. Verification is done per-story against `quickstart.md` success criteria.

**Organization**: Tasks are grouped by user story (priority order) so each is independently implementable and testable.

## Path Conventions

- Backend (PHP/MySQL): `backend_medjet/`
- Admin app (Flutter): `frontend/mobile/superadmin/lib/`
- Other apps: `frontend/mobile/employee/` (Employee), `frontend/mobile/manager/` (HR — no change)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the environment and existing assets the feature builds on.

- [x] T001 Verify MAMP MySQL is reachable (`medjat` @ 127.0.0.1:8889, root/root) and that `support_tickets` + `support_messages` exist (from `backend_medjet/migrations/2026_06_support.sql`)
- [x] T002 Confirm a Firebase service-account credential is available to the backend (same one used by `backend_medjet/core/NotificationService.php`) — required for Remote Config writes and FCM
- [x] T003 [P] Run `flutter pub get` in `frontend/mobile/superadmin` and confirm the app builds on the current branch

**Checkpoint**: Environment verified — story work can begin.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared plumbing used by more than one story. Keep minimal so stories stay independent.

- [x] T004 Add support + app-control endpoint URLs to `frontend/mobile/superadmin/lib/core/constant/id/app_links.dart` (support: list/messages/reply/status; app control: get/set; device register) and mark the deprecated `forceUpdateTrigger` getter for removal
- [x] T005 Add new route names to `frontend/mobile/superadmin/lib/core/constant/routes/app_routes.dart` (`supportInbox`, `supportThread`, `appControl`) and remove the obsolete `forceUpdate` route

**Checkpoint**: Routing + endpoint constants ready for all stories.

---

## Phase 3: User Story 1 - Reply to user communications (Priority: P1) 🎯 MVP

**Goal**: Support members list all tenant tickets, open a thread, view history, reply (text only), change status, filter by status/company, with live refresh of new messages. No Firebase required.

**Independent Test**: Sign in, open a ticket with an unread user message → it marks read; send a reply → reply appears in thread, tenant is notified, status becomes `pending_user`; with the thread open, a new user message appears within ~10s.

### Backend (reuse existing list/messages/reply; add status)

- [x] T006 [US1] Create `backend_medjet/app/admin_support/status.php` (role `admin`): accept `{ticket_id, status∈resolved|closed|reopen}`, validate via `SupportModel::findTicketByIdGlobal` + enum, map `reopen→pending_support`, call `SupportModel::setTicketStatus`, audit `support.status` with `{from,to}` per `contracts/admin_support.md`

### Flutter — data layer

- [x] T007 [P] [US1] Create `frontend/mobile/superadmin/lib/data/model/support_ticket_model.dart` (id, tenantId, tenantName, subject, category, priority, status, lastMessageAt, lastMessagePreview, unreadForSupport) per data-model.md
- [x] T008 [P] [US1] Create `frontend/mobile/superadmin/lib/data/model/support_message_model.dart` (id, ticketId, senderType, body, createdAt)
- [x] T009 [US1] Create `frontend/mobile/superadmin/lib/data/data_source/remote/support_data/support_data.dart` with `list({page,status,tenantId})`, `messages(ticketId,{afterId})`, `reply(ticketId,body)`, `setStatus(ticketId,status)` using `Get.find<CRUD>()`

### Flutter — controller

- [x] T010 [US1] Create `frontend/mobile/superadmin/lib/logic/controller/support/support_controller.dart`: inbox load + status/tenant filters, thread load (mark-read on open), send reply, change status, and a ~5s polling timer using `after_id` while a thread is open (stop on close/background) — meets SC-003

### Flutter — UI

- [x] T011 [P] [US1] Create `frontend/mobile/superadmin/lib/view/screen/support/support_inbox_screen.dart` (ticket list ordered by last activity, unread badge from `unreadForSupport`, status + company filters, empty/loading states)
- [x] T012 [P] [US1] Create `frontend/mobile/superadmin/lib/view/screen/support/support_thread_screen.dart` (chat bubbles user vs support, reply input ≤5000 chars text-only, status action menu, deactivated-tenant notice per FR-011)

### Flutter — wiring

- [x] T013 [US1] Register `SupportBinding` (SupportData + SupportController) and `GetPage`s for `supportInbox`/`supportThread` in `frontend/mobile/superadmin/lib/core/constant/routes/app_pages.dart`
- [x] T014 [US1] Add a "Support / الدعم" entry to the dashboard navigation in `frontend/mobile/superadmin/lib/view/screen/dashboard/dashboard_screen.dart` linking to `supportInbox`

**Checkpoint**: US1 fully functional and independently testable (the MVP).

---

## Phase 4: User Story 2 - Control minimum version & stop/start apps (Priority: P2)

**Goal**: A `superadmin` views and sets per-app minimum version and (Employee/HR only) a maintenance kill switch, written to Firebase Remote Config by the backend; the Admin app is version-only.

**Independent Test**: Set Employee `min_version` above a test device → forced update on next launch/foreground; enable Employee maintenance → device shows maintenance screen; disable → access returns; malformed version rejected (422); RC fetch failure never locks users out.

### Backend — Remote Config service + endpoints

- [x] T015 [US2] Create `backend_medjet/core/RemoteConfigService.php` wrapping `kreait/firebase-php` Remote Config: `getAll()` (read template params for all apps), `setVersion(app, value)`, `setMaintenance(app, bool)` (fetch → set `defaultValue` → publish)
- [x] T016 [US2] Create `backend_medjet/app/admin_app_control/get.php` (role `superadmin`): return the `apps[]` shape from `contracts/app_control.md` (medjat_app, medjat_central, medjat_admin; `supports_maintenance` flags); 503 on RC fetch failure
- [x] T017 [US2] Create `backend_medjet/app/admin_app_control/set.php` (role `superadmin`): validate `app` enum + `min_version` regex `^\d+(\.\d+){0,3}$` + reject `maintenance` when `app=medjat_admin`; write via RemoteConfigService + publish; audit `app_control.set_version`/`app_control.set_maintenance` with `{from,to}`; 422 invalid, 503 write failure

### App-side Remote Config wiring (other apps)

- [x] T018 [P] [US2] Ensure the Employee app reads `medjat_app_min_version` + `medjat_app_maintenance_enabled` — mirror the HR app's `UpdateService`/`MaintenanceGate` in `frontend/mobile/employee/lib/core/` (add gate/service if missing); fall back to a safe non-locking state on RC failure (FR-019/SC-008)
- [x] T019 [P] [US2] Add a `medjat_admin_min_version` force-update check to `frontend/mobile/superadmin` (version-only, no maintenance gate)

### Flutter (admin) — app control screen

- [x] T020 [P] [US2] Create `frontend/mobile/superadmin/lib/data/model/app_control_model.dart` (key, name, minVersion, maintenance nullable, supportsMaintenance)
- [x] T021 [US2] Create `frontend/mobile/superadmin/lib/data/data_source/remote/app_control_data/app_control_data.dart` with `get()` and `set({app, minVersion?, maintenance?})`
- [x] T022 [US2] Create `frontend/mobile/superadmin/lib/logic/controller/app_control/app_control_controller.dart` (load apps, edit version, toggle maintenance for Employee/HR only, client-side version validation per FR-017)
- [x] T023 [US2] Create `frontend/mobile/superadmin/lib/view/screen/app_control/app_control_screen.dart` (per-app card: min-version field + save; maintenance toggle shown only when `supportsMaintenance`; current-state display)
- [x] T024 [US2] Register `AppControlBinding` + `GetPage` for `appControl` and remove the deprecated `ForceUpdateBinding`/route in `frontend/mobile/superadmin/lib/core/constant/routes/app_pages.dart`; delete `force_update_*` data/controller/screen
- [x] T025 [US2] Add an "App Control / التحكم بالتطبيقات" nav entry in `dashboard_screen.dart`, shown only when the signed-in operator's role is `superadmin`

**Checkpoint**: US1 and US2 both work independently.

---

## Phase 5: User Story 3 - Confirm changes before they affect live apps (Priority: P3)

**Goal**: High-impact app-control actions (enabling maintenance, raising min version) require an explicit confirmation naming the affected app before applying.

**Independent Test**: Try to enable a stop switch → confirmation dialog names the app; cancel → no change; confirm → change applies.

- [x] T026 [US3] Add a reusable confirmation dialog in `frontend/mobile/superadmin/lib/core/shared/dialogs/` (or extend existing) that names the affected app and the impact
- [x] T027 [US3] Wire the confirmation into `app_control_screen.dart`/`app_control_controller.dart` so enabling maintenance or raising `min_version` requires confirm before calling `set()` (FR-018/SC-007); cancel restores previous UI state

**Checkpoint**: App-control mutations are guarded.

---

## Phase 6: User Story (Push) - Alert the support team of new messages (FR-010b / SC-009)

**Goal**: Support-team devices receive a push when a new user message/ticket arrives. Isolated slice — adds Firebase to medjat_admin; does NOT block US1/US2 (in-app `unread_for_support` badges already cover awareness).

**Independent Test**: As a tenant, create a ticket / send a message → support devices receive a push; tapping opens the ticket thread.

### Backend

- [x] T028 [P] [USPush] Create migration `backend_medjet/migrations/2026_06_admin_support_control.sql` adding `super_admin_devices` (FK→super_admins) per data-model.md; apply to MAMP
- [x] T029 [USPush] Create `backend_medjet/app/admin/devices/register.php` (role `admin`): upsert `{fcm_token, platform?, device_id?, device_model?, app_version?}` into `super_admin_devices` keyed by `(admin_id, device_id)`
- [x] T030 [USPush] Add `sendToSupportTeam(title, body, data)` to `backend_medjet/core/NotificationService.php`: multicast FCM to active `super_admin_devices` tokens; best-effort (log on failure, never block)
- [x] T031 [USPush] Call `NotificationService::sendToSupportTeam(...)` from `backend_medjet/app/support/create.php` and `backend_medjet/app/support/reply.php` (only when `sender_type='user'`) with `{type:'support', ticket_id}`

### Flutter (admin) — Firebase + token registration

- [x] T032 [USPush] Add `firebase_core` + `firebase_messaging` to `frontend/mobile/superadmin/pubspec.yaml`; add platform config (`google-services.json`, `GoogleService-Info.plist`); initialize Firebase in `frontend/mobile/superadmin/lib/main.dart`
- [x] T033 [USPush] Create `frontend/mobile/superadmin/lib/data/data_source/remote/device_data/device_data.dart` + register the FCM token on login/app-start (request notification permission), calling the device-register endpoint
- [x] T034 [USPush] Handle notification tap with `data.type=='support'` → deep-link to `supportThread` for `ticket_id`

**Checkpoint**: Support push delivered end-to-end; badges remain the always-on fallback.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Verification against success criteria and edge cases.

- [x] T035 [P] Verify audit trail (SC-006): rows in `super_admin_audit_log` for `support.reply`, `support.status`, `app_control.set_version`, `app_control.set_maintenance`
- [x] T036 [P] Verify edge cases from spec: concurrent reply + user message ordering; deactivated tenant shows history + delivery notice (FR-011); RC fetch failure → no false lockout (SC-008); min_version above latest → warn
- [x] T037 [P] Run `flutter analyze` on `frontend/mobile/superadmin` (and any touched app) and resolve lints; confirm RTL/Arabic strings render
- [x] T038 Walk through `quickstart.md` slices 1–3 end-to-end and confirm SC-001..SC-009

---

## Dependencies & Execution Order

- **Setup (Phase 1)** → **Foundational (Phase 2)** must finish first (T004/T005 add the shared routes + endpoint constants used by every story).
- **US1 (Phase 3)** = MVP. Depends only on Phase 1–2. Backend T006 is independent of the Flutter tasks; T009 depends on T007/T008; T010 depends on T009; T013 depends on T010–T012.
- **US2 (Phase 4)** depends on Phase 1–2, independent of US1. T016/T017 depend on T015; T021 depends on T020; T022 depends on T021; T024 depends on T023.
- **US3 (Phase 5)** depends on US2 (extends the app-control screen).
- **USPush (Phase 6)** depends on Phase 1–2 and on US1 existing (deep-links to the thread); otherwise independent. T029 depends on T028; T030 depends on T028; T031 depends on T030.
- **Polish (Phase 7)** last.

## Parallel Opportunities

- **Phase 3**: T007 + T008 (models) in parallel; T011 + T012 (screens) in parallel after the controller exists.
- **Phase 4**: T018 + T019 (app-side wiring in different apps) + T020 (model) in parallel.
- **Phase 6**: T028 (migration) parallel to early backend prep.
- **Phase 7**: T035 + T036 + T037 in parallel.
- **Cross-story**: With enough hands, US1 and US2 can be built simultaneously after Phase 2 (different files, no shared mutable code beyond app_links/app_pages already seeded in Phase 2).

## Implementation Strategy

1. **MVP = Phase 1 + 2 + US1** — delivers the core "reply to users" value with zero Firebase work.
2. **+US2** — adds the version/stop-switch control plane (superadmin), backend-only Firebase.
3. **+US3** — guards high-impact app-control actions.
4. **+USPush** — adds proactive support alerts (the heaviest slice; adds Firebase to the admin app).
5. **Polish** — verify all success criteria and edge cases.
