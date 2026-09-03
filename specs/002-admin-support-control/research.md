# Phase 0 Research: Admin Support & App Control Center

All spec-level NEEDS CLARIFICATION were resolved in the two `/speckit.clarify` sessions (see `spec.md` → Clarifications). This document records the technical decisions that flow from those answers plus the codebase facts they depend on.

## D1. App-control delivery mechanism

- **Decision**: The PHP backend writes the per-app values to **Firebase Remote Config** using the vendored `kreait/firebase-php` Admin SDK. The apps keep reading Remote Config exactly as today.
- **Rationale**: The HR app (`permedjat_central`) already reads `medjat_central_min_version` (force update, `UpdateService`) and `medjat_central_maintenance_enabled` (kill switch, `MaintenanceGate`). Writing the same keys means zero change to the apps' update/maintenance logic and instant propagation (RC `onConfigUpdated` + on-launch/foreground fetch).
- **Keys**:
  | App | min-version key | maintenance key |
  |-----|-----------------|-----------------|
  | Employee (`permedjat_app`) | `medjat_app_min_version` | `medjat_app_maintenance_enabled` |
  | HR Management (`permedjat_central`) | `medjat_central_min_version` | `medjat_central_maintenance_enabled` |
  | Admin (`permedjat_admin`) | `medjat_admin_min_version` | *(none — Admin not stoppable)* |
- **Alternatives considered**: (a) New MySQL config table polled by apps — rejected: forces rewriting update/maintenance logic in every app and loses RC's live push. (b) Admin app writes RC directly — rejected: embeds privileged Firebase credentials in a mobile client.
- **Implementation note**: Use the Remote Config template API — fetch current template, set parameter `defaultValue`, validate, then publish. Wrap in `core/RemoteConfigService.php`. Reuse the service-account credential already configured for `NotificationService` (FCM).

## D2. Role gating

- **Decision**: `admin_support/*` (inbox, thread, reply, status) require role **`admin`**; `admin_app_control/*` (get/set version + maintenance) require **`superadmin`**.
- **Rationale**: Matches existing code — `admin/force_update/trigger.php` already uses `minRole = 'superadmin'`; `admin_support/*` already uses `AdminAuth::require('admin')`. `AdminAuth::roleSufficient` ranks `readonly(1) < admin(2) < superadmin(3)`.
- **Implementation note**: app-control endpoints call `AdminAuth::require('superadmin')`; the admin app hides/disables the App Control entry for non-superadmin operators (role is returned at login as `role`/`role_key`).

## D3. Minimum-version granularity

- **Decision**: One min-version value per app; no iOS/Android split.
- **Rationale**: Matches the single `medjat_central_min_version` key in use today. Fewer keys, simpler UI.
- **Version comparison**: dotted-numeric, same semantics the HR app's `isVersionLower(current, minRequired)` already implements; min-version of empty or `0.0.0` means "no force update".

## D4. Stoppable apps

- **Decision**: Employee and HR apps expose both min-version and a maintenance kill switch; the Admin app exposes min-version only (no maintenance key).
- **Rationale**: Prevents the support team from locking itself out of the control plane.

## D5. Forced-update / maintenance screen message

- **Decision**: Fixed in-app text (apps already render `UpdateStrings.*`). Operators toggle state + set version only; no operator-authored message.
- **Rationale**: Honors "apps unchanged"; the current `MaintenanceGate` reads only a bool key and shows built-in copy. (FR-020 removed the optional-message idea.)

## D6. Support replies — text only

- **Decision**: Text-only replies in v1. `support_messages.attachment_url/attachment_name` columns remain for future use but no upload UI/endpoint is built.
- **Rationale**: Matches existing `admin_support/reply.php` (body only). Avoids file storage scope.

## D7. Ticket assignment — shared queue

- **Decision**: Shared queue; any `admin` operator sees and replies to any ticket. `support_tickets.assigned_super_admin_id` stays unused in v1 (`SupportModel::assignTicket` exists but is not wired).
- **Rationale**: Simplest; no assignment UI/filter needed.

## D8. Live refresh of an open thread

- **Decision**: Client-side polling using the existing `after_id` parameter on `admin_support/messages.php`. Poll every ~5s while a thread is open; stop when it closes/backgrounds.
- **Rationale**: Backend already supports incremental fetch (`getMessages($ticketId, $afterId)`); meets SC-003 (< 10s) without websockets. The admin app has no realtime channel today.
- **Alternatives considered**: FCM data-message-driven refresh — deferred; depends on D9 push infra and is an optimization, not required for SC-003.

## D9. Support push notifications (new infrastructure)

- **Decision**: Add Firebase Cloud Messaging to permedjat_admin and store super-admin device tokens in a new `super_admin_devices` table. On a new user message/ticket (tenant side `support/create.php` and `support/reply.php` where `sender_type='user'`), the backend sends a push to all active support-team devices via a new `NotificationService::sendToSupportTeam()`.
- **Rationale**: Required by FR-010b / SC-009 (user-selected, beyond the in-app-only recommendation). The existing `admin_devices` table references **`admins`** (tenant admins), not `super_admins`, so a separate token store is needed.
- **Cost / risk**: permedjat_admin currently ships **no Firebase** (`pubspec.yaml` has none; auth is username/password via `admin_token`). This adds `firebase_core`+`firebase_messaging`, platform Firebase config files, init, permission prompt, and a token-register endpoint. Treated as its own user story (US: support push) so US1/US2 are not blocked.
- **Alternatives considered**: In-app unread badge only — simpler and recommended, but the user explicitly chose push; kept badges as the always-on fallback.

## D10. Reuse vs new — backend endpoint inventory

| Need | Status | Action |
|------|--------|--------|
| List all tickets (admin) | EXISTS `admin_support/list.php` | reuse |
| Thread + mark-read (admin) | EXISTS `admin_support/messages.php` | reuse (use `after_id` for polling) |
| Support reply (admin) | EXISTS `admin_support/reply.php` | reuse |
| Change ticket status | MISSING (model has `setTicketStatus`) | NEW `admin_support/status.php` |
| Read app-control values | MISSING | NEW `admin_app_control/get.php` |
| Write app-control values | partial (`admin/force_update/trigger.php` deprecated) | NEW `admin_app_control/set.php` + `RemoteConfigService` |
| Register super-admin device | MISSING | NEW `admin/devices/register.php` (+ table) |
| Push to support team | MISSING | NEW `NotificationService::sendToSupportTeam()` |

## D11. App-side Remote Config wiring

- **Decision**: Confirm/add Remote Config gates in the Employee and Admin apps; HR app unchanged.
- **Details**: Employee app must read `medjat_app_min_version` + `medjat_app_maintenance_enabled` (mirror HR app's `UpdateService`/`MaintenanceGate`). Admin app must read `medjat_admin_min_version` for force-update only (no maintenance gate). HR app already complete.
