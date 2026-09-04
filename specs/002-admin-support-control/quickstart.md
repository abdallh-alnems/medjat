# Quickstart: Admin Support & App Control Center

How to build, wire, and verify this feature. Order follows the user-story priorities so each slice is independently shippable.

## Prerequisites
- MAMP MySQL running: `permedjat` DB on `127.0.0.1:8889` (root/root). Apply migration:
  `mysql -u root -proot -h 127.0.0.1 -P 8889 permedjat < backend_medjet/migrations/2026_06_admin_support_control.sql`
- Backend Firebase service-account credential available (same one `NotificationService` uses) — needed for Remote Config writes and FCM.
- Flutter: `cd frontend/mobile/superadmin && flutter pub get`.

## Slice 1 — Support inbox & reply (US1, P1) — no Firebase needed
Backend: reuse `admin_support/list.php`, `messages.php`, `reply.php`; add `admin_support/status.php`.
Admin app:
1. Models: `support_ticket_model.dart`, `support_message_model.dart`.
2. Data: `support_data/support_data.dart` → `list`, `messages(ticketId, afterId?)`, `reply`, `setStatus`.
3. Controller: `support/support_controller.dart` — inbox load + filters (status/tenant), thread load+mark-read, send reply, status change, and a 5s polling timer (`after_id`) while a thread is open.
4. Screens: `support_inbox_screen.dart` (list, unread badges, filters), `support_thread_screen.dart` (chat bubbles, reply box, status menu).
5. Wire `app_links.dart` (4 endpoints), `app_routes.dart`, `app_pages.dart` (`SupportBinding`), add a Support entry to the dashboard nav.
**Verify (SC-001/002/003)**: open inbox → open a ticket with an unread user message → it marks read → send reply → reply appears, tenant gets notified; with the thread open, a new user message appears within ~10s via polling.

## Slice 2 — App control (US2, P2) — superadmin only
Backend:
1. `core/RemoteConfigService.php` — `getAll()` reads template params; `setVersion(app, v)` / `setMaintenance(app, bool)` update + publish.
2. `admin_app_control/get.php` and `set.php` (role `superadmin`, validation per `contracts/app_control.md`, audit).
App-side RC wiring: ensure Employee app reads `medjat_app_min_version` + `medjat_app_maintenance_enabled` (mirror HR app `UpdateService`/`MaintenanceGate`); add `medjat_admin_min_version` force-update check to the Admin app (version-only).
Admin app:
1. `app_control_model.dart`, `app_control_data/app_control_data.dart` (`get`, `set`).
2. `app_control/app_control_controller.dart`, `app_control/app_control_screen.dart` (per-app card: version field + save, maintenance toggle for Employee/HR only; confirm dialog for high-impact actions).
3. Replace the deprecated `forceUpdate` route/binding with `appControl`; gate the menu entry on `role == superadmin`.
**Verify (SC-004/005/007/008)**: set Employee min_version above a test device → device forced to update on next launch/foreground; enable Employee maintenance (confirm dialog appears) → device shows maintenance screen; disable → access returns; malformed version rejected (422); RC fetch failure → app never locks out.

## Slice 3 — Support push (US push, FR-010b/SC-009) — adds Firebase to permedjat_admin
1. Migration adds `super_admin_devices`.
2. Add `firebase_core` + `firebase_messaging` to `frontend/mobile/superadmin/pubspec.yaml`; add platform Firebase config files; init in `main.dart`.
3. `admin/devices/register.php` (upsert token); register on login/start; request notification permission.
4. `NotificationService::sendToSupportTeam(...)`; call it from tenant-side `support/create.php` and `support/reply.php` (user messages).
5. Notification tap → deep-link to the ticket thread.
**Verify (SC-009)**: as a tenant, create a ticket / send a message → support devices receive a push; tapping opens the thread.

## Audit check (SC-006)
After each action, confirm rows in `super_admin_audit_log` for `support.reply`, `support.status`, `app_control.set_version`, `app_control.set_maintenance`.
