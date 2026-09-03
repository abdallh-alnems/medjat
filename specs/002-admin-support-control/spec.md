# Feature Specification: Admin Support & App Control Center

**Feature Branch**: `002-admin-support-control`
**Created**: 2026-06-10
**Status**: Draft
**Input**: User description: "Build the permedjat_admin app — the support-team app. Read permedjat_app and permedjat_central. Enable replying to user communications from administration. There is a minimum app version in Remote Config and the ability to stop any of the apps; do this through the admin app. I want it to control everything."

## Overview

The platform consists of three products: an **Employee app** (used by end employees), an **HR Management app** (used by company administrators/HR managers, the platform's paying tenants), and the **Admin app** (used by the platform's own support and operations team). The Admin app is the control plane for the whole platform.

This feature extends the Admin app so the support team can (1) **read and reply to communications raised by platform users** (company administrators) through a built-in support conversation channel, and (2) **remotely govern each app in the portfolio** — setting the minimum required version that forces an update and toggling a stop/maintenance switch that takes an app offline — without redeploying or touching external consoles by hand. Together these make the Admin app a single place from which the support team controls the platform.

## Clarifications

### Session 2026-06-10

- Q: How do app-control changes (minimum version / stop switch) reach the live apps? → A: The backend writes to the same Firebase Remote Config keys the apps already read (`permedjat_*_min_version`, `permedjat_*_maintenance_enabled`), using the already-vendored Firebase Admin SDK; the apps' existing update/maintenance logic is unchanged.
- Q: Which operator role is required for each capability? → A: App control (version + stop switch) requires the `superadmin` role; support reply/inbox requires the `admin` role (matching the existing endpoints).
- Q: What granularity should the minimum-version setting have? → A: A single minimum version per app — no separate iOS/Android values — matching the current `permedjat_central_min_version` key.
- Q: Which apps can be put into the stop/maintenance state? → A: The Employee app and the HR Management app can be stopped; the Admin app supports minimum-version control only (no kill switch) so the support team cannot lock itself out of the control plane.
- Q: Is the forced-update/maintenance screen message operator-customizable or fixed in-app? → A: Fixed in-app text (as the apps already display); operators only toggle the state, no custom message. (FR-020 removed.)
- Q: Do support replies support attachments, or text only? → A: Text only for v1; the message store keeps the attachment columns for future use but the reply experience is text-only.
- Q: Are tickets assigned to a specific support member or a shared queue? → A: Shared queue — any support member can view and reply to any ticket; the `assigned_super_admin_id` column is left unused in v1.
- Q: How is the support team alerted of a new user message/ticket? → A: Push notifications to support-team devices (requires registering Admin-app device tokens and sending push on new user messages/tickets), in addition to in-app unread indicators.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reply to user communications (Priority: P1)

A support-team member opens the Admin app and sees the list of support conversations raised by platform users (company administrators). They open a conversation, read the full message history, type a reply, and send it. The user who raised the conversation receives the reply and a notification. The support member can change the conversation's status (e.g. mark it resolved or closed) and filter conversations by status or by the company (tenant) that raised them.

**Why this priority**: Direct two-way communication with users is the core reason the support team needs this app. Without it the team has no way to respond to incoming requests, which is the primary stated need. It delivers standalone value even if no other story ships.

**Independent Test**: Sign in as a support member, open an existing conversation that has an unread user message, send a reply, and confirm the reply appears in the thread, the conversation status/ordering updates, and the originating user is notified.

**Acceptance Scenarios**:

1. **Given** a support member is signed in, **When** they open the support inbox, **Then** they see all conversations ordered by most recent activity, each showing the company name, subject, status, priority, and an unread indicator for conversations awaiting a support response.
2. **Given** a conversation with prior messages, **When** the support member opens it, **Then** the full message history (user and support messages) is shown in chronological order and the conversation is marked as read for support.
3. **Given** an open conversation, **When** the support member sends a reply, **Then** the reply is appended to the thread, the originating user receives a notification, and the conversation moves to a "waiting on user" state.
4. **Given** the inbox, **When** the support member filters by status or by company, **Then** only matching conversations are shown.
5. **Given** an open conversation, **When** the support member marks it resolved or closed, **Then** its status updates and it is reflected in the inbox and filters.
6. **Given** a conversation thread, **When** a new user message arrives while it is open, **Then** the new message appears without the support member having to leave and re-open the conversation.

---

### User Story 2 - Control minimum version and stop/start apps (Priority: P2)

A `superadmin` operator opens an "App Control" area in the Admin app that lists each app in the portfolio (Employee app, HR Management app, and the Admin app itself). For a selected app they can set the **minimum required version**: any installed app older than this is forced to update before it can be used. For the Employee app and the HR Management app they can also toggle a **stop switch** that puts the app into a maintenance/offline state so its users see a "temporarily unavailable" screen instead of the app (the Admin app has no stop switch, to avoid the team locking itself out). Changes take effect on running and newly launched apps without a code release.

**Why this priority**: This is the platform's lever to push critical updates and to take a misbehaving or compromised app offline quickly. It is operationally essential but secondary to being able to answer users.

**Independent Test**: Set a minimum version higher than a test device's installed version and confirm that device is forced to update; toggle the stop switch for that app and confirm the device shows the maintenance screen; toggle it back and confirm normal access resumes.

**Acceptance Scenarios**:

1. **Given** the App Control area, **When** the member views it, **Then** each app is listed with its current minimum required version, and the Employee and HR Management apps additionally show their current stop/maintenance state.
2. **Given** an app, **When** the member sets a minimum required version and saves, **Then** apps running a lower version are required to update before continuing, and apps at or above the version are unaffected.
3. **Given** an app, **When** the member enables the stop switch, **Then** users of that app see a maintenance/offline screen and cannot use the app until the switch is disabled.
4. **Given** an app in maintenance, **When** the member disables the stop switch, **Then** users regain normal access on next launch or when the app re-checks, without a new release.
5. **Given** an invalid version value (e.g. empty or malformed), **When** the member tries to save, **Then** the change is rejected with a clear validation message and no apps are affected.
6. **Given** a stop or version change, **When** it is saved, **Then** the action is recorded in the audit log with who made it, which app, and the new values.

---

### User Story 3 - Confirm changes before they affect live apps (Priority: P3)

Because stopping an app or forcing an update affects real users immediately, the support member is asked to confirm high-impact actions (enabling a stop switch, or raising a minimum version) before they take effect, and can see the consequences (which app, what audience is affected) in the confirmation.

**Why this priority**: A safeguard that reduces the risk of accidental outages. Valuable but not required for the core capability to function.

**Independent Test**: Attempt to enable a stop switch and verify a confirmation step naming the affected app appears; cancel and verify nothing changes; confirm and verify the change applies.

**Acceptance Scenarios**:

1. **Given** the member enables a stop switch, **When** they trigger save, **Then** a confirmation naming the affected app and the impact is shown before the change is applied.
2. **Given** the confirmation, **When** the member cancels, **Then** no change is made and the previous state is preserved.

---

### Edge Cases

- A support member sends a reply at the same moment the user sends a new message — both messages must be preserved and ordered correctly with no lost content.
- The originating user's account or company has been deactivated — the support member can still read the conversation history but is informed the user may not receive notifications.
- An app cannot reach the configuration source on launch (offline or service unavailable) — the app must fall back to its last known safe state rather than locking the user out by mistake.
- A minimum version is set higher than the latest published version of an app — the system should warn that this would lock out all current users.
- Two support members reply to the same conversation concurrently — both replies are recorded in order.
- The stop switch is toggled rapidly — the app honors the most recent value, not an intermediate one.
- A version string uses an unexpected format — comparison must be well-defined or the value rejected at entry.

## Requirements *(mandatory)*

### Functional Requirements

#### Authentication & access
- **FR-001**: Access MUST be role-gated: the support inbox and reply features require the `admin` operator role, while the app-control features (minimum version and stop switch) require the higher `superadmin` role. Unauthenticated or under-privileged requests MUST be rejected.
- **FR-002**: The system MUST record every reply, status change, version change, and stop/start action in an audit trail attributing the actor, the target, the values, and the time.

#### Support communication
- **FR-003**: The system MUST present a list of all support conversations across companies, ordered by most recent activity, showing for each: originating company, subject, category, priority, status, and whether it is awaiting a support response.
- **FR-004**: Support members MUST be able to filter the conversation list by status and by company.
- **FR-005**: Support members MUST be able to open a conversation and view its complete message history in chronological order, distinguishing user messages from support messages.
- **FR-006**: Opening a conversation MUST mark its pending user messages as read for the support side.
- **FR-007**: Support members MUST be able to send a text reply to a conversation; replies MUST be appended to the thread and limited to a reasonable maximum length. Replies are text-only in this version (no attachments).
- **FR-008**: When a reply is sent, the originating user MUST be notified and the conversation status MUST reflect that it is awaiting the user.
- **FR-009**: Support members MUST be able to change a conversation's status (at least: in-progress/pending, resolved, closed).
- **FR-010**: An open conversation MUST surface newly arrived user messages without requiring the member to reload the whole inbox.
- **FR-010a**: Tickets MUST be handled as a shared queue — any authorized support member can view and reply to any ticket; no per-member assignment is required in this version.
- **FR-010b**: When a new user message or new ticket arrives, the system MUST send a push notification to the support team's registered devices (in addition to in-app unread indicators). This requires registering Admin-app device tokens for support members.
- **FR-011**: The system MUST handle conversations whose originating user/company is deactivated by still showing history and indicating that delivery of notifications may not occur.

#### App control (minimum version & stop switch)
- **FR-012**: The system MUST let an operator view, per app in the portfolio, the current minimum required version and (where applicable) the current stop/maintenance state. The Employee app and HR Management app expose both controls; the Admin app exposes minimum-version control only and has no stop switch.
- **FR-013**: Operators MUST be able to set a single minimum required version per app (one value per app, not split by platform); apps running a version below it MUST be required to update before continued use, and apps at or above it MUST be unaffected.
- **FR-014**: Operators MUST be able to enable or disable a stop/maintenance switch for the Employee app and the HR Management app; while enabled, that app's users MUST be presented a maintenance/offline state and prevented from normal use. The Admin app MUST NOT be stoppable.
- **FR-015**: Configuration changes (version and stop switch) MUST propagate to running and newly launched apps without requiring a new app release, by updating the runtime configuration the apps already read (the shared Firebase Remote Config keys), written from the backend.
- **FR-016**: Apps MUST re-evaluate the configuration at least on launch and on returning to the foreground, and MUST apply the latest value.
- **FR-017**: The system MUST validate version inputs and reject empty or malformed values with a clear message, applying no change on rejection.
- **FR-018**: The system MUST require an explicit confirmation before applying high-impact actions (enabling a stop switch or raising the minimum version), and the confirmation MUST name the affected app.
- **FR-019**: When an app cannot retrieve configuration, it MUST default to a safe non-locking state rather than blocking access on missing data.
- **FR-020**: The forced-update and maintenance screens MUST display the apps' existing built-in text; operators only toggle the state and set the minimum version, and MUST NOT author a custom per-change message in this version.

#### Centralized oversight
- **FR-021**: The Admin app MUST present these capabilities alongside its existing control areas (companies, subscriptions, plans, users, audit, notifications) so the support team has a single control plane; this feature does not remove or replace those existing areas.

### Key Entities *(include if feature involves data)*

- **Support Conversation (Ticket)**: A thread opened by a platform user (company administrator) on behalf of a company. Attributes: owning company, who opened it, subject, category, priority, status, last-activity time, last-message preview, and unread indicators for each side.
- **Support Message**: A single entry within a conversation. Attributes: which conversation, sender side (user, support, or system), the author, body text, optional attachment reference, and timestamp.
- **Support Member / Platform Operator**: The Admin-app user acting on behalf of the platform; has a role that governs access to support and app-control features.
- **App Control Setting**: Per app, the governing values: a single minimum required version and a stop/maintenance flag (Employee and HR Management apps only; not the Admin app). No custom message is stored — apps show their built-in text. Persisted as the shared Firebase Remote Config keys the apps already read.
- **Support Device Token**: A registered Admin-app device belonging to a support member, used to deliver push notifications for new user messages and tickets.
- **Audit Entry**: A record of a support reply, status change, version change, or stop/start action — who, what target, old/new values, and when.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A support member can go from opening the app to sending a first reply to a waiting conversation in under 60 seconds.
- **SC-002**: 100% of replies sent are delivered to the conversation thread and trigger a notification to the originating user.
- **SC-003**: A newly sent user message appears in an already-open conversation within 10 seconds without a manual full reload.
- **SC-004**: After an operator enables an app's stop switch, affected apps present the maintenance state within one app launch or foreground return, and in no case continue normal operation after the next configuration check.
- **SC-005**: After an operator sets a minimum version, devices below that version are forced to update on their next launch or foreground return, with zero false lockouts of devices at or above the version.
- **SC-006**: 100% of stop/start, version, status, and reply actions appear in the audit trail with actor, target, and values.
- **SC-007**: No high-impact action (stop switch on, version raise) is applied without an explicit confirmation step.
- **SC-008**: When configuration retrieval fails, 0% of users are incorrectly locked out (the app falls back to a safe state).
- **SC-009**: 100% of new user messages/tickets generate a push notification to the support team's registered devices.

## Assumptions

- The "users" whose communications are answered are **company administrators** (the platform's tenants) who raise support conversations; end employees in the Employee app are out of scope for direct support conversations in this version, consistent with the current support model.
- The support conversation backend (conversations, messages, read tracking, notifications) and the per-app configuration mechanism (minimum version and maintenance/stop flag, already consumed by the HR Management app) **already exist**; this feature is primarily the Admin-app operator experience over them, plus any missing operator-facing endpoints.
- "Stop an app" means putting that app into a full maintenance/offline state for its users (a kill switch), not a partial feature toggle. Arbitrary per-feature flags are out of scope for this version. The Admin app itself is not stoppable.
- Support replies are text-only in v1 (the message store keeps attachment columns for later, but no upload experience is built). Tickets are a shared queue with no per-member assignment in v1. The forced-update/maintenance screens show the apps' built-in text (no operator-authored message).
- Support members are alerted of new user messages/tickets via push to their registered Admin-app devices; this assumes Admin-app device-token registration and a push-send path exist or are added for the support team.
- Each app has a single minimum required version (no per-platform split), matching the existing `permedjat_central_min_version` Remote Config key. Per-platform minimum versions are out of scope for this version.
- App-control changes are applied by the backend writing the shared Firebase Remote Config keys (`permedjat_*_min_version`, `permedjat_*_maintenance_enabled`) via the already-vendored Firebase Admin SDK; the apps' existing on-launch/on-foreground Remote Config checks are reused unchanged.
- "Control everything" is interpreted as making the Admin app the single control plane: this feature adds support replies and app control to the existing admin capabilities (companies, subscriptions, plans, users, audit, notifications) rather than introducing unbounded new control surfaces. Additional control areas can be specified separately.
- The Admin app's existing authentication and operator-role model is reused; no new identity system is introduced.
- Version comparison follows standard dotted numeric version semantics.

## Dependencies

- Existing support conversation/message storage and read-tracking.
- Existing notification delivery to users.
- Firebase Remote Config (the shared keys apps already read on launch and foreground for minimum version and maintenance state) plus the backend's already-vendored Firebase Admin SDK for writing those keys.
- Existing Admin-app authentication, operator roles, and audit logging.
