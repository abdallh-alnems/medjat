# Implementation Plan: Web Attendance Check-In / Check-Out

**Branch**: `004-web-attendance-checkin` | **Date**: 2026-08-02 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-web-attendance-checkin/spec.md`

## Summary

Give employees a browser surface that does one thing: record a check-in and a
check-out. It reuses the existing PHP attendance endpoints, the existing branch
geofence, and the existing employee identity — but it cannot reuse the existing
*session model*, and that is the crux of the work.

The mobile app logs in once with a **single-use** activation code and then holds
a token that never expires. On a browser that model is unusable in both
directions: a never-expiring token on a shared office computer lets the next
person punch as the previous one, and a session that ends leaves the employee
with nothing to log back in with, because the activation code was consumed on
first use and lapses after 24 hours.

The plan therefore introduces the one thing the employee identity has never
had — **a repeatable secret** (a PIN the employee sets when they activate) —
and uses it to make short sessions affordable: the session ends at check-out,
and getting back in costs four digits rather than a call to HR.

Everything else is additive to code that already exists: `check_in.php` /
`check_out.php` gain a browser origin and a photo, `NetworkVerifier` is used in
its IP mode only (a browser cannot see a BSSID), and every refusal continues to
land in `attendance_security_logs`.

## Technical Context

**Language/Version**: PHP 8.4 local (MAMP) / 8.5 live · TypeScript 5, React 19, Next.js 16 (App Router)
**Primary Dependencies**: Existing `core/` services — `Auth`, `GpsService`, `NetworkVerifier`, `TenantClock`, `RateLimiter`, `Validator`, `Response`, `BiometricEnrollment` (photo-storage pattern). Web: TanStack Query, Zustand, React Hook Form + Zod, Tailwind, shadcn/Base UI, axios.
**Storage**: MySQL 8.4 (live) — additive migrations only; images to `backend_medjet/uploads/`
**Testing**: PHP — manual endpoint exercise against MAMP (no PHP test harness in repo). Web — vitest (unit) + playwright (e2e), both already configured in `permedjat_central_web`.
**Target Platform**: Mobile and desktop browsers, Safari iOS 16+ / Chrome Android — device geolocation and camera required
**Project Type**: Web application (Next.js front end + existing PHP REST backend)
**Performance Goals**: SC-001 first-ever check-in ≤ 60 s end-to-end; SC-002 returning check-out ≤ 15 s. Neither is server-bound — both are dominated by geolocation acquisition and camera warm-up, so the budget is a UX budget, not a latency budget.
**Constraints**:
- Browser cannot read WiFi BSSID → network verification degrades to IP/CIDR only
- Browser reports no mock-location signal → that control simply does not exist here
- Browser cannot run the `.tflite` face model → no face verification on this surface (FR-028)
- No offline queue (the app has one; the browser will refuse clearly instead)
- HTTPS mandatory — geolocation and camera are secure-context-only APIs
**Scale/Scope**: 6 tenants / 16 employees today (pre-launch). Design for hundreds per tenant; nothing here is throughput-sensitive.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is an **unfilled template** — no principles have
been ratified, so there are no constitution gates to evaluate. Rather than treat
that as a pass by default, this plan is gated against the project's real,
written and enforced rules in `CLAUDE.md`, which function as the de-facto
constitution.

| Rule (CLAUDE.md) | Applies how | Status |
|---|---|---|
| **Writes require POST** (`Auth::requirePost`) | Every new endpoint is POST, including logout | ✅ Planned |
| **Multi-tenant isolation** via `TenantMiddleware` | Web tokens carry `tenant_id`; every query is tenant-scoped | ✅ Planned |
| **Permission gating must match the endpoint** | New admin settings sit behind `manage_company_settings`; the frontend gate must match or a viewer gets a bare "an error occurred" | ✅ Planned |
| **Time is per tenant** — `TenantClock`, never `date()`/`NOW()`; expiry computed **in SQL** | Session expiry and the shared-device window are computed with `DATE_ADD(NOW(), INTERVAL ? SECOND)` | ✅ Planned — [R-006](./research.md) |
| **Migrations**: new dated file, never edit an applied one, MySQL 8 has no `ADD COLUMN IF NOT EXISTS` | Three additive migrations, plain `ADD COLUMN`; `platform` enum extended with full re-statement | ✅ Planned |
| **Never trust the client's verdict** | The browser asserts nothing the server acts on; location, IP and time are all judged server-side | ✅ Planned |
| **Run `check-drift.sh` before and after** | Part of the deployment step in [quickstart.md](./quickstart.md) | ✅ Planned |
| **Arabic-first RTL, IBM Plex Sans Arabic + Geist** | Employee surface inherits `permedjat_central_web` locale + theme setup | ✅ Planned |

**One deviation is recorded in Complexity Tracking**: the employee web surface
lives inside the admin web application rather than in its own deployment.

## Project Structure

### Documentation (this feature)

```text
specs/004-web-attendance-checkin/
├── plan.md              # This file
├── research.md          # Phase 0 — decisions and rejected alternatives
├── data-model.md        # Phase 1 — schema deltas and entities
├── quickstart.md        # Phase 1 — run, test and deploy this feature
├── contracts/           # Phase 1 — endpoint contracts
│   ├── employee-web-auth.md
│   ├── attendance-web.md
│   └── admin-settings.md
├── checklists/
│   └── requirements.md  # Written by /speckit.specify, updated by /speckit.clarify
└── tasks.md             # NOT created by /speckit.plan
```

### Source Code (repository root)

```text
backend_medjet/
├── app/
│   ├── auth/
│   │   ├── employee_web_activate.php      # NEW — consume activation code, set PIN, issue web session
│   │   ├── employee_web_login.php         # NEW — phone + PIN, issue web session
│   │   └── employee_web_logout.php        # NEW — end the current web session
│   ├── attendance/
│   │   ├── check_in.php                   # EXTEND — accept web origin + punch photo
│   │   ├── check_out.php                  # EXTEND — same, plus end session on check-out
│   │   └── web_status.php                 # NEW — today's state for the browser landing page
│   ├── employees/
│   │   └── reset_web_pin.php              # NEW — admin clears a forgotten PIN
│   ├── categories/
│   │   └── update_web_access.php          # NEW — per-category permission
│   └── settings/
│       └── company.php                    # EXTEND — web enable + photo toggle
├── core/
│   ├── WebSessionService.php              # NEW — issue / verify / revoke web sessions, one-per-employee
│   ├── PunchPhotoService.php              # NEW — validate and store punch images
│   └── SharedDeviceDetector.php           # NEW — flag one device serving several employees
├── models/
│   └── EmployeeWebCredentialModel.php     # NEW — hashed PIN, lockout counters
└── migrations/
    ├── 2026_08_03_employee_web_sessions.sql
    ├── 2026_08_03_attendance_punch_photo.sql
    └── 2026_08_03_web_attendance_settings.sql

frontend/web/manager/src/
├── app/(employee)/                        # NEW route group — employee surface, isolated from (app)
│   ├── layout.tsx                         # Own auth context; imports nothing from the admin tree
│   ├── activate/page.tsx                  # Phone + activation code + choose PIN
│   ├── login/page.tsx                     # Phone + PIN
│   └── attendance/page.tsx                # State, geolocation, camera, the single button
├── features/employee-attendance/          # NEW — hooks, schemas, api client
└── lib/api/employee.ts                    # NEW — axios instance carrying the employee session

frontend/mobile/manager/lib/
└── view/screen/settings/                  # EXTEND — web toggle, photo toggle, category access
```

**Structure Decision**: Web application (Option 2 shape) mapped onto the
repository's real directories. The backend keeps its one-endpoint-per-file
convention under `app/<module>/` with shared logic in `core/`. The employee
surface is a **new route group inside the existing `permedjat_central_web`
deployment** rather than a fourth front-end project — see Complexity Tracking
for why, and [R-001](./research.md) for what was rejected.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Employee surface shares an origin with the admin web app | `app.permedjat.com` is already deployed, TLS-terminated, systemd-managed, RTL- and locale-configured, with the axios/Tailwind/shadcn stack in place. A separate deployment doubles the ops surface (second systemd unit, second nginx vhost, second build) for a feature serving 16 employees today. | A separate Next.js app was rejected on operational cost at this scale. The accepted risk is same-origin: a script injection in the admin tree could reach employee session state. Mitigated by (a) route-group isolation with no shared imports, (b) the employee session being an httpOnly cookie unreadable to script, (c) the surface exposing attendance only (FR-027), so the blast radius is a forged punch, not payroll data. **Revisit if the surface ever grows past attendance.** |
| A third credential type (PIN) alongside activation codes and app tokens | The browser needs a *repeatable* secret; the activation code is single-use and 24-hour-lived by design, and the app token is a bearer credential that cannot be re-derived by the employee. Without a repeatable secret, either sessions never end (unsafe on shared devices) or HR re-issues a code daily (unworkable). | Extending the activation code to be reusable was rejected: it is deliberately single-use, and making it durable would weaken the *app's* onboarding too. An SMS one-time code was rejected on cost and latency (no gateway exists). WebAuthn was rejected for this release — see [R-003](./research.md). |
