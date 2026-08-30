# Feature Specification: Medjat Central — Web Edition

**Feature Branch**: `003-medjat-central-web`
**Created**: 2026-06-19
**Status**: Draft
**Input**: User description: "عايز احول التطبيق دة frontend/mobile/central الي موقع ويب اريد كل التفاصيل الذي فية واريد ان تستخدم نفس الطريقة هذة frontend/farkha_web"

## Summary

Deliver a full-featured **web edition** of the existing Medjat Central HR & payroll
admin application. Today Medjat Central exists only as a mobile app (the
`medjat_central` Flutter project). HR administrators and company managers want to
do the same work from a desktop or laptop browser without installing anything.

The web edition must reproduce **every administrator-facing capability** present in
the mobile app — multi-tenant company management, employee records, attendance,
payroll, leave, shifts/schedules, branches, reports/exports, settings,
permissions, support, and more — backed by the **same backend API and Firebase
authentication** the mobile app already uses, so a manager sees identical data
whether they log in on the phone or the web.

The web edition follows the **same architectural approach already proven in the
`farkha_web` project** (a modern App-Router web stack with a server-side API proxy
that injects backend credentials, the same Firebase auth and tenant-header
conventions, server data caching, a component-based design system, RTL Arabic-first
UI with English support, and PWA installability). Reusing that approach is an
explicit requirement so the two web properties stay consistent and maintainable.

## Clarifications

### Session 2026-06-20

- Q: On the web edition, who performs attendance check-in? → A: Admin-only. `medjat_central` is the manager app and has **no employee self check-in**. Web attendance = (a) manual recording of check-in/out by an admin, (b) viewing the live/today board (25s polling) and history, and (c) saving the company attendance-method setting (`qr_gps` / `gps_only` / `manual`) that the *separate employee app* consumes. Employee self check-in (QR/GPS/face capture) is NOT part of this product on web or mobile admin.
- Q: Is `geolocator` / camera in the admin app used for check-in? → A: No. Geolocation is used only to capture a branch/company geofence location when defining a branch (admin convenience); web equivalent = browser geolocation "use my location" plus manual coordinate/map entry. Biometric/face is review-only here — the controller receives a precomputed face embedding and supports viewing enrollment status and deleting it; new face capture happens in the employee app, so on web biometric = view status + delete (no webcam capture).
- Q: Does v1 ship full feature-parity at once, or in phases? → A: Full parity in a single release — all 10 user stories ship together for v1. Story priorities (P1–P3) remain useful for build ordering but are not a phased release boundary.
- Q: Does web need push notifications, or is the in-app list enough? → A: In-app notifications list + preferences only (fetched by polling the backend). No browser/Web Push, no service-worker push, no web FCM token registration in v1. Web Push may be added later.
- Q: Which export formats for web v1 (mobile produces PDF + Word/.docx + CSV)? → A: PDF + Excel + CSV, following the farkha_web toolkit. Word (.docx) is replaced by Excel (.xlsx) on web; the payroll bank-file CSV export is preserved. No .docx generation in v1.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sign in and reach the right starting place (Priority: P1)

An HR administrator opens the website, signs in with the same credentials they use
on the mobile app (email + password, Google, or Apple), and lands on the dashboard
for their company. If they belong to no company yet, they are guided to create a
company or join one with an invite code. If their email is unverified, they are
guided to verify it first.

**Why this priority**: Without authenticated, tenant-scoped access nothing else in
the product is reachable. This is the minimum viable slice — a manager who can only
sign in and see their company dashboard already has value (a real-time at-a-glance
view of attendance), and every other story builds on this session.

**Independent Test**: Log in with a known account; confirm the session is
established, the correct company (tenant) context is selected, and the dashboard
loads its data. Log in with an account that has no company and confirm the
onboarding choice (create / join) appears. Log out and confirm the session ends.

**Acceptance Scenarios**:

1. **Given** a registered, email-verified user who belongs to a company, **When**
   they sign in, **Then** they reach their company dashboard with today's summary
   populated.
2. **Given** a user whose email is not yet verified, **When** they sign in, **Then**
   they are shown the verify-email step and cannot reach company data until verified.
3. **Given** an authenticated user who belongs to no company, **When** they reach
   onboarding, **Then** they can either create a new company or join an existing one
   with a valid invite code, and are routed to the dashboard on success.
4. **Given** a signed-in user, **When** they choose Log out, **Then** the session is
   cleared and they return to the login screen.
5. **Given** a user who forgot their password, **When** they request a reset, **Then**
   they receive a reset link/code and can set a new password.

---

### User Story 2 - Monitor the company at a glance from the dashboard (Priority: P1)

A manager views the dashboard to understand the company's day right now: how many
employees are present / absent / late / on leave, the attendance rate, branch
performance comparison, pending leave and permission requests awaiting approval, a
payroll summary for the month, distribution by category, and items needing attention
(e.g., expiring compliance documents, current status of each employee).

**Why this priority**: The dashboard is the daily landing experience and the primary
reason a manager opens the product each morning. It delivers standalone value even
before any record is edited.

**Independent Test**: Load the dashboard for a company with seeded data and verify
each summary card, the branch comparison, the pending-approvals counts, and the
drill-down lists (status employees, expiring compliance) render correct values and
link to their detail screens.

**Acceptance Scenarios**:

1. **Given** a company with active employees, **When** the dashboard loads, **Then**
   present/absent/late/on-leave counts and the attendance rate reflect today's data.
2. **Given** multiple branches, **When** the manager opens branch comparison, **Then**
   branches are ranked across attendance rate, total payroll, late rate, and head
   count with highest/lowest highlighted.
3. **Given** pending leave or permission (break) requests, **When** the dashboard
   loads, **Then** the pending counts are shown and selecting one opens the relevant
   approval list.
4. **Given** documents nearing expiry, **When** the manager opens expiring
   compliance, **Then** the affected employees/documents are listed.

---

### User Story 3 - Manage employees end to end (Priority: P1)

A manager searches, filters (by branch, shift, category, status), and sorts the
employee list; opens an employee to view and edit their full profile; adds new
employees; manages their documents; enrolls/reviews biometric (face) data where
applicable; processes end-of-service settlement; and reviews terminated employees
separately.

**Why this priority**: Employees are the core entity of an HR system; most other
features (attendance, payroll, leave, documents) are scoped to an employee. A
complete employee management slice is essential to MVP.

**Independent Test**: Add an employee, find them via search and filters, open and
edit their detail, attach/replace a document, and move them through termination so
they appear in the terminated list — all reflected consistently on reload.

**Acceptance Scenarios**:

1. **Given** the employees list, **When** the manager searches and applies
   branch/shift/category/status filters and a sort option, **Then** the list updates
   to match and can be cleared back to default.
2. **Given** an employee record, **When** the manager edits profile fields and saves,
   **Then** the changes persist and are visible to other admins.
3. **Given** the add-employee form, **When** a manager submits valid data, **Then** a
   new employee is created and appears in the list.
4. **Given** an employee, **When** the manager runs end-of-service settlement, **Then**
   the settlement is computed and recorded and the employee can be terminated.
5. **Given** a terminated employee, **When** the manager opens the terminated list,
   **Then** that employee appears there and not in the active list.

---

### User Story 4 - Record and review attendance (Priority: P1)

A manager views live/today attendance, records manual attendance (check-in/out) for
employees, adds notes to attendance records (e.g., reason for lateness), reviews late
and overtime, and exports attendance records.

**Why this priority**: Attendance is the highest-frequency operational task and the
data source that feeds payroll and the dashboard. Core to MVP.

**Independent Test**: Record manual attendance for an employee, add a note, confirm
the record and note persist, and export the day's records to a file.

**Acceptance Scenarios**:

1. **Given** the attendance screen, **When** a manager records manual check-in/out for
   one or more selected employees, **Then** the records are saved and reflected in
   status counts.
2. **Given** an attendance record, **When** the manager adds/edits/deletes a note,
   **Then** the note state persists and is visible on the record.
3. **Given** a set of attendance records, **When** the manager exports, **Then** a
   downloadable document is produced; if there are no records, the manager is told
   there is nothing to export.

---

### User Story 5 - Run payroll and adjustments (Priority: P2)

A manager views payroll by month/year, reviews per-employee net salary (base,
bonuses, deductions), applies bulk adjustments across selected employees, manages
loans, and exports payroll (and payslips) to PDF/Excel (and the bank file to CSV).

**Why this priority**: Payroll is a defining capability of the product but typically
a periodic (monthly) task that depends on employee and attendance data being in
place first, so it ranks just below the daily-use P1 stories.

**Independent Test**: Open a payroll period, create a bulk adjustment for selected
employees, confirm net salaries update, generate a payslip export, and create/track
a loan against an employee.

**Acceptance Scenarios**:

1. **Given** a payroll period, **When** the manager opens it, **Then** each employee's
   base/bonuses/deductions/net are shown and totals roll up.
2. **Given** selected employees, **When** the manager creates a bulk adjustment,
   **Then** it is recorded and reflected in their payroll, and its detail is viewable.
3. **Given** a payroll period, **When** the manager exports payroll or a payslip,
   **Then** a correctly formatted PDF/Excel document is produced.
4. **Given** an employee, **When** the manager records a loan, **Then** the loan is
   tracked and its repayments affect payroll deductions.

---

### User Story 6 - Approve leave and permission requests (Priority: P2)

A manager reviews pending leave requests and permission/break requests, approves or
rejects them, and creates leave on an employee's behalf.

**Why this priority**: Approvals are important and time-sensitive but are a focused
flow that depends on the employee/dashboard foundation.

**Acceptance Scenarios**:

1. **Given** pending leave requests, **When** the manager approves or rejects one,
   **Then** its status updates and the dashboard pending count adjusts.
2. **Given** the leave management screen, **When** the manager creates a leave entry
   for an employee, **Then** it is recorded against that employee's balance.
3. **Given** pending permission (break) requests, **When** the manager acts on one,
   **Then** its status updates accordingly.

---

### User Story 7 - Configure branches, shifts and schedules (Priority: P2)

A manager manages branches (including location and a printable QR check-in poster),
defines shifts and their members, assigns shifts to employees, and edits the weekly
schedule.

**Acceptance Scenarios**:

1. **Given** branch management, **When** the manager creates/edits a branch and its
   location, **Then** it is saved and available as a filter and assignment target.
2. **Given** a branch, **When** the manager opens its QR poster, **Then** a printable
   check-in poster is produced.
3. **Given** shifts, **When** the manager assigns a shift to employees or edits the
   weekly schedule, **Then** assignments persist and drive attendance expectations.

---

### User Story 8 - Reports and exports (Priority: P2)

A manager generates attendance, payroll, employees, leaves, and documents reports for
a selected period and exports them (PDF/Excel, CSV where applicable) for sharing or filing.

**Acceptance Scenarios**:

1. **Given** the reports hub, **When** the manager selects a report type and period,
   **Then** the report is produced for that range.
2. **Given** a generated report, **When** the manager exports it, **Then** a
   correctly formatted downloadable file is produced.

---

### User Story 9 - Company settings, team and permissions (Priority: P2)

A general manager configures company settings (company data, deduction rules, leave
settings incl. carryover policies and encashments, statutory payroll settings,
attendance method, required documents and submissions, employee categories, assets),
manages the team of admins (invite admins via code, set each admin's role and branch),
and customizes per-admin permissions that override role defaults.

**Acceptance Scenarios**:

1. **Given** a general manager, **When** they edit any company setting, **Then** the
   change is saved and enforced across the product.
2. **Given** team management, **When** a general manager invites an admin and assigns
   a role (General Manager / HR / Branch Manager / Attendance / Viewer) and branch,
   **Then** an invite code is issued and the admin appears pending until activated.
3. **Given** an admin, **When** the general manager customizes that admin's
   permissions, **Then** those overrides take effect and can be reset to role defaults;
   general-manager permissions cannot be modified.
4. **Given** an admin without a given permission, **When** they attempt the
   corresponding action, **Then** they are blocked and shown a no-permission message.

---

### User Story 10 - Support, notifications, audit and account (Priority: P3)

A manager opens support tickets and chats on them, reviews and configures
notifications, reviews the activity/audit log, and manages their own account
(app/appearance settings, language, delete account).

**Acceptance Scenarios**:

1. **Given** support, **When** the manager creates a ticket and sends messages,
   **Then** the conversation is recorded and replies appear.
2. **Given** notifications, **When** the manager opens them or edits preferences,
   **Then** the list and preferences reflect their choices.
3. **Given** the activity log, **When** the manager opens it, **Then** recorded admin
   actions are listed.
4. **Given** account settings, **When** the manager changes language/appearance or
   deletes their account, **Then** the change takes effect (with the last-general-
   manager deletion warning shown where relevant).

---

### Edge Cases

- **No company / pending activation**: A signed-in user with no tenant is routed to
  onboarding; an invited admin who hasn't activated is shown as pending and limited.
- **Insufficient permission**: Any action the admin's role/permissions disallow is
  hidden or blocked with a clear message; navigating directly to a restricted URL
  must not expose data.
- **Tenant isolation**: A user must only ever see data for their selected company;
  possessing multiple tenants must not leak data across them.
- **Session superseded / expired**: If the backend reports the session was superseded
  (e.g., login elsewhere) or the auth token expires, the user is signed out gracefully.
- **Empty states**: Lists with no data (no employees, no records to export, not enough
  branches to compare) show purposeful empty/guidance states rather than errors.
- **Offline / network failure**: A failed request shows a non-destructive error and a
  retry path; partial bulk operations report which items succeeded and which failed.
- **RTL & localization**: All screens render correctly in Arabic (RTL) and English
  (LTR), including numbers, dates, and currency (EGP).
- **Large data sets**: Employee/attendance/payroll lists with hundreds of rows remain
  usable (search, filter, sort, paginate) without freezing.
- **Branch geolocation in the browser**: Capturing a branch geofence relies on browser
  geolocation permission; if denied/unavailable, the admin can enter coordinates
  manually so branch setup is never blocked.

## Requirements *(mandatory)*

### Functional Requirements

**Authentication & onboarding**

- **FR-001**: System MUST let users sign in with email + password, Google, and Apple,
  using the same identity provider and accounts as the existing mobile app.
- **FR-002**: System MUST support account creation, email verification, and password
  reset (forgot password) flows.
- **FR-003**: System MUST route an authenticated user with no company to onboarding
  where they can create a company or join one via invite code.
- **FR-004**: System MUST scope every request and view to the user's selected company
  (tenant) and never expose another company's data.
- **FR-005**: System MUST sign the user out on explicit logout, on session-superseded
  notification from the backend, and on token expiry.
- **FR-006**: System MUST let a user delete their own account, surfacing the
  last-general-manager warning where applicable.

**Authorization**

- **FR-007**: System MUST enforce the role model (General Manager, HR, Branch Manager,
  Attendance, Viewer) and per-admin permission overrides, both in the UI (hiding
  disallowed actions) and on every action attempt.
- **FR-008**: System MUST allow a general manager to invite admins, assign role and
  branch, customize permissions, and reset to role defaults; General Manager
  permissions MUST NOT be editable.

**Dashboard**

- **FR-009**: System MUST present a company dashboard with today's attendance summary
  (present/absent/late/on-leave, attendance rate), branch performance comparison,
  pending leave and permission counts, payroll summary, category distribution, current
  employee status, and expiring-compliance items, each linking to its detail view.

**Employees**

- **FR-010**: Users MUST be able to list, search, filter (branch/shift/category/
  status), sort, and customize the employee view.
- **FR-011**: Users MUST be able to add employees and view/edit full employee detail,
  including recording disciplinary warnings and performance reviews for an employee.
- **FR-012**: Users MUST be able to manage an employee's documents and required-document
  submissions.
- **FR-013**: Users MUST be able to review an employee's biometric (face) enrollment
  status and delete it where the role permits. New face capture is performed in the
  employee app, not on web (no webcam capture in this product).
- **FR-014**: Users MUST be able to compute and record end-of-service settlement and
  terminate an employee, and review terminated employees separately.

**Attendance**

- **FR-015**: Users MUST be able to view the live/today attendance board (auto-
  refreshing) and history, and record manual attendance (check-in and/or check-out
  times) for one or more employees. There is no employee self check-in on web.
- **FR-016**: Users MUST be able to add, edit, and delete notes on attendance records.
- **FR-017**: Users MUST be able to export attendance records, with a clear message
  when there is nothing to export.

**Payroll, loans, adjustments**

- **FR-018**: Users MUST be able to view payroll by month/year with per-employee
  base/bonuses/deductions/net and rolled-up totals.
- **FR-019**: Users MUST be able to create and view bulk adjustments across selected
  employees.
- **FR-020**: Users MUST be able to manage loans and have repayments reflected in
  payroll.
- **FR-021**: Users MUST be able to export payroll and individual payslips to PDF and
  Excel formats, and export the payroll bank file as CSV. (Web replaces the mobile
  app's Word/.docx export with Excel.)

**Leave & permissions**

- **FR-022**: Users MUST be able to review and approve/reject leave requests and create
  leave for an employee.
- **FR-023**: Users MUST be able to review and act on permission/break requests.

**Branches, shifts, schedules**

- **FR-024**: Users MUST be able to manage branches and their geofence locations
  (capturing coordinates via browser geolocation "use my location" and/or manual
  coordinate/map entry), and generate a printable branch QR check-in poster (the QR
  is consumed by the separate employee app).
- **FR-025**: Users MUST be able to define shifts, manage shift members, assign shifts,
  and edit the weekly schedule.

**Reports & exports**

- **FR-026**: Users MUST be able to generate attendance, payroll, employees, leaves, and
  documents reports for a selected period and export them as downloadable PDF or Excel
  files (CSV where a tabular bank/data export applies).

**Company settings**

- **FR-027**: General managers MUST be able to configure company data, deduction rules,
  leave settings (incl. carryover policies and encashments), statutory payroll
  settings, attendance method, required documents and submissions, employee
  categories, and assets.

**Support, notifications, audit**

- **FR-028**: Users MUST be able to create support tickets and exchange messages on them.
- **FR-029**: Users MUST be able to view the in-app notifications list and edit
  notification preferences (fetched from the backend). Browser/Web Push is out of scope
  for v1 (no service-worker push, no web FCM token registration).
- **FR-030**: Users MUST be able to view the activity/audit log of admin actions.

**Cross-cutting**

- **FR-031**: System MUST present the full UI in Arabic (RTL) by default and English
  (LTR), with correct number, date, and EGP currency formatting, and let the user
  switch language and appearance (light/dark/system) from a control in the app shell
  topbar (and from the account settings page); the choice persists across sessions.
- **FR-032**: System MUST be usable on desktop and tablet browser widths and remain
  functional on mobile browser widths, and MUST be installable as a PWA.
- **FR-033**: System MUST communicate with the existing backend API through a
  server-side proxy that attaches the backend security credentials, the
  authenticated user's identity token, the device identifier, and the tenant
  identifier, so backend credentials are never exposed to the browser.
- **FR-034**: System MUST show purposeful loading, empty, and error states for every
  data view, with retry on failure.
- **FR-035**: System MUST surface a maintenance/forced-update gate equivalent so the
  product can be paused or version-gated centrally (matching the mobile app's
  maintenance/update behavior) where applicable to web.

### Key Entities *(include if feature involves data)*

- **Company (Tenant)**: An isolated organization; owns all other records; identified by
  a tenant id carried on every request.
- **Admin / User**: An authenticated person with a role and optional per-admin
  permission overrides, scoped to a company and optionally a branch.
- **Employee**: A worker record with profile, branch, shift, category, status,
  documents, and compensation; can be active or terminated.
- **Attendance Record**: A per-employee, per-day check-in/out with status (present/
  absent/late), overtime/late minutes, and optional note.
- **Payroll / Payslip**: Per-employee, per-period computation of base, bonuses,
  deductions, loans, and net pay.
- **Bulk Adjustment**: A bonus/deduction applied across a set of employees for a period.
- **Loan**: An amount advanced to an employee, repaid via payroll deductions.
- **Leave Request / Permission (Break) Request**: Time-off or short-permission requests
  with an approval status.
- **Branch**: A physical location with geo coordinates and a QR check-in poster.
- **Shift / Schedule**: Working-time definitions, membership, assignments, and a weekly
  schedule.
- **Category**: A grouping of employees used for distribution and filtering.
- **Document / Required Document / Submission**: Files attached to employees and the
  required-document policy and submissions against it.
- **Compliance Item**: A document/record with an expiry that needs attention.
- **Asset (Custody)**: Company assets assigned to employees.
- **Warning**: A disciplinary warning recorded against an employee.
- **Performance Review**: A periodic rating (1–5) and notes for an employee.
- **Settlement**: End-of-service computation for a terminated employee.
- **Support Ticket / Message**: A support conversation thread.
- **Notification**: An in-app message with user-configurable preferences.
- **Audit Log Entry**: A recorded admin action.
- **Company Settings**: Deduction rules, leave settings, statutory payroll settings,
  attendance method, required-documents policy, categories.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the administrator-facing capabilities available in the mobile
  `medjat_central` app are available in the web edition (feature-parity checklist
  fully covered), excluding only capabilities explicitly scoped out for being
  device-hardware-dependent.
- **SC-002**: An administrator can sign in and reach their company dashboard in under
  30 seconds on a normal broadband connection on first visit.
- **SC-003**: Data shown on the web for a given company exactly matches the data shown
  in the mobile app for the same company and account (no divergence in counts,
  balances, or records).
- **SC-004**: A manager can complete each core daily task — record manual attendance,
  approve a leave request, and view payroll for an employee — in under 1 minute each.
- **SC-005**: 95% of primary list/detail views render their data within 2 seconds on a
  normal broadband connection for a company with up to 500 employees.
- **SC-006**: Backend security credentials are never present in any browser-delivered
  asset or network call observable from the client (verified by inspection).
- **SC-007**: Every screen passes a right-to-left (Arabic) and left-to-right (English)
  layout review with correct date/number/currency formatting.
- **SC-008**: Permission enforcement is correct in 100% of tested cases: no restricted
  action or restricted data is reachable by an admin lacking the permission, including
  via direct URL.
- **SC-009**: The site is installable as a PWA and usable on desktop, tablet, and mobile
  browser widths.

## Assumptions

- **Same approach as `farkha_web`**: The web edition reuses the architectural pattern of
  the existing `frontend/farkha_web` project — App-Router web framework, a server-side
  `/api` proxy route that injects backend Basic-auth credentials and forwards the
  user's auth token, the same Firebase authentication and tenant-header conventions,
  server-state caching, a shared component/design system, RTL Arabic-first theming with
  light/dark support, and PWA installability. This is a stated requirement, not just a
  default.
- **Backend unchanged**: The existing Medjat backend API and database are reused as-is;
  this feature delivers a new web client only and does not change backend contracts.
  Any endpoint the mobile app calls is assumed callable by the web client through the
  proxy.
- **Identity reuse**: The same Firebase project / user accounts power web auth; no
  separate user store is created. Google and Apple sign-in are configured for web
  origins.
- **Scope is administrator-facing**: This product targets HR admins and managers (the
  audience of `medjat_central`), not the employee self-service experience.
- **Single-release delivery**: v1 ships full feature-parity (all 10 user stories) in one
  release. Priorities P1–P3 guide build order, not separate shippable phases.
- **Notifications**: In-app notifications list and preferences only; no browser/Web Push
  in v1.
- **Localization**: Arabic (RTL) is the default language with English supported, mirroring
  the mobile app's two locales.
- **Export & print**: PDF, Excel (.xlsx), and CSV export plus printing are in scope via
  browser-based generation, following the farkha_web toolkit. The mobile app's Word
  (.docx) export is intentionally replaced by Excel on web.
- **No self check-in**: `medjat_central` (and therefore this web edition) is the
  admin/manager surface only. It records manual attendance and reviews it; employee
  self check-in (QR/GPS/face) lives in the separate employee app and is out of scope
  here. See Clarifications (Session 2026-06-20).
