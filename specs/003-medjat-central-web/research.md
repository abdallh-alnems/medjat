# Phase 0 — Research: Medjat Central Web Edition

All spec-level ambiguities were resolved during `/speckit.clarify` (Session 2026-06-20).
This document records the technical decisions, each with rationale and rejected
alternatives, and resolves the planning-level open items so design can proceed with no
`NEEDS CLARIFICATION` remaining.

## D1. Application framework & rendering

- **Decision**: Next.js 16 App Router (React 19, TypeScript), mostly client components
  for the authenticated, data-interactive admin surface; server components for static
  shells/SEO-irrelevant routes.
- **Rationale**: Exact reuse of the `farkha_web` approach (explicit requirement); App
  Router gives the `/api` route-handler BFF in the same project; React Query handles
  client data. The admin app is gated/auth-only so SSR/SEO is not a priority.
- **Alternatives rejected**: Flutter Web (heavy bundle, poor SEO/DOM, diverges from the
  farkha approach); Vite SPA (loses the co-located server proxy that hides credentials).

## D2. Backend access via server-side proxy (BFF)

- **Decision**: All browser calls go to `/api/<path>` (a `[...path]/route.ts` handler)
  which forwards to `${API_HOST}/<path>` injecting `Authorization: Basic base64(SECURITY_USER:SECURITY_KEY)`.
  The browser axios client uses `baseURL: "/api"`; the server client uses `API_HOST`.
- **Rationale**: Keeps `SECURITY_USER`/`SECURITY_KEY` server-only (SC-006). Identical to
  `farkha_web/src/app/api/[...path]/route.ts` and `src/lib/api/client.ts`.
- **Medjat-specific extension (important)**: The Medjat backend authenticates the user
  and tenant via custom headers, not the Basic auth slot. The proxy MUST forward, when
  present on the incoming request:
  - `X-Firebase-Token` — the user's Firebase ID token (the farkha proxy only forwards
    `Authorization`; we add explicit pass-through for these),
  - `X-Tenant-Id` — selected company id,
  - `X-Device-Id` — stable per-browser id (generated once, stored in localStorage),
  and preserve the backend Basic auth in `Authorization`. GET query params and POST
  bodies are passed through unchanged. (Some endpoints also accept `?token=<idToken>`;
  header is preferred.)
- **Alternatives rejected**: Direct browser→PHP calls (would leak Basic credentials and
  hit CORS); Next.js rewrites (can't compute the per-request Firebase token/headers).

## D3. Authentication & session

- **Decision**: Firebase Web SDK. Providers: **email/password**, **Google** (popup),
  **Apple** (OAuthProvider popup) — matching mobile. After Firebase sign-in, call
  `app/auth/login.php` with the ID token to establish the backend user/session and fetch
  the user + tenant context. Session/UI state in a persisted Zustand `auth-store`
  (mirrors farkha). Sign out on explicit logout, on `onAuthStateChanged(null)`, on token
  expiry, and on backend "session superseded" responses.
- **Rationale**: Same Firebase project and accounts as mobile (FR-001/005); reuses the
  farkha `use-auth`/`auth-store` pattern.
- **Email verification & password reset**: use Firebase `sendEmailVerification` /
  `sendPasswordResetEmail` plus the backend `send_verification.php` /
  `send_password_reset.php` endpoints to match mobile behavior.
- **Alternatives rejected**: Custom JWT/session cookies (diverges from Firebase identity
  reuse; duplicates user store).

## D4. Tenant (multi-company) model

- **Decision**: One tenant per user (confirmed: no company-switcher exists in the mobile
  app). Persist `tenant_id` from the login response in a `tenant-store`; attach as
  `X-Tenant-Id` on every proxied request via an axios request interceptor. Users with no
  tenant are routed to `/onboarding` (create or join via invite code).
- **Rationale**: Matches `crud.dart` header logic and onboarding flow.
- **Alternatives rejected**: Multi-tenant switcher UI (no backend/UX support; would be
  speculative scope).

## D5. Server-state data fetching

- **Decision**: TanStack Query (`staleTime: 60s`, `retry: 2`, `refetchOnWindowFocus:
  false` — same defaults as farkha). One typed API module + query/mutation hooks per
  backend domain. Live attendance board uses `refetchInterval: 25_000` to mirror the
  mobile 25s polling.
- **Rationale**: Caching, loading/empty/error states (FR-034), background refresh.
- **Alternatives rejected**: Raw fetch in components (no cache/retry/状态); SWR (farkha
  standardizes on React Query).

## D6. UI system, theming, RTL, i18n

- **Decision**: shadcn + Tailwind v4 + `tw-animate-css`, `next-themes` for light/dark.
  Port Medjat's color tokens into CSS variables (brand `#2563EB`/dark `#60A5FA`, warm
  accent `#B8860B`, teal-tinted canvas/surface, error/warning/success). Self-host
  IBM Plex Sans Arabic (primary) + Geist. Root `<html dir="rtl" lang="ar">` with an
  English LTR toggle. Port the `ar.dart`/`en.dart` dictionaries to a lightweight i18n
  dictionary + `useT()` hook; EGP currency + Arabic-Indic/Latin number formatting via a
  shared `utils` formatter.
- **Note on fonts**: memory flags that the Flutter project's Geist `.ttf` are LFS/HTML
  pointer files (corrupted). Re-acquire real Geist + IBM Plex Sans Arabic web fonts for
  the web app rather than copying from the Flutter assets.
- **Rationale**: Matches farkha (Cairo there → IBM Plex Sans Arabic here to match Medjat
  branding); preserves the app's two locales and visual identity.
- **Alternatives rejected**: MUI/Chakra (diverges from farkha + shadcn); CSS-in-JS
  runtime (Tailwind v4 is the established approach).

## D7. Permissions / roles

- **Decision**: Port the role model (General Manager, HR, Branch Manager, Attendance,
  Viewer) and per-admin permission overrides from `app/roles/list_permissions.php` and
  `managers/*`. A `use-permissions` hook + `<Can permission=…>` guard hides disallowed
  actions; route guards block restricted pages (including direct-URL access). The backend
  remains the authoritative enforcer (client checks are UX, not security).
- **Rationale**: FR-007/008, SC-008.
- **Alternatives rejected**: Client-only enforcement (insufficient; backend already
  enforces and stays the source of truth).

## D8. Exports & printing

- **Decision**: PDF via jsPDF (+ html2canvas for rich layouts), Excel via `xlsx`, CSV
  for the payroll bank file (`export_bank_file.php` already returns `text/csv`). Payslip
  and report PDFs can also use the backend `get_slip_pdf.php` where it returns a ready
  PDF; otherwise generate client-side. **No .docx** (mobile Word export replaced by Excel
  per clarification).
- **Rationale**: Matches the farkha toolkit (jspdf + xlsx) and the clarified format set.
- **Alternatives rejected**: docx generation libs (outside the farkha approach; explicit
  out-of-scope).

## D9. Notifications

- **Decision**: In-app notifications list + preferences only, fetched from
  `notifications/list.php`, `notifications/read.php`, `auth/notification_prefs.php`. **No
  Web Push / FCM token registration / service-worker push** in v1 (the PWA service worker
  is shell/offline only). `firebase_messaging` is omitted from the web bundle.
- **Rationale**: Clarification decision; simplest, no SW push wiring.
- **Alternatives rejected**: Web Push via FCM (deferred to a later version).

## D10. Attendance scope

- **Decision**: Admin-only. Web provides: manual check-in/out recording
  (`attendance/manual_check_in.php`, single + batch), set-day-status, attendance notes
  (`update_note.php`), the live/today board (`dashboard/live_attendance.php`, 25s poll)
  and history. The attendance-method setting screen saves `qr_gps`/`gps_only`/`manual`
  for the separate employee app. **No employee self check-in.** Biometric = view status
  + delete only (`biometric/status.php`, `biometric/delete.php`); no webcam capture.
- **Rationale**: Clarification; `medjat_central` is the manager surface.

## D11. Branch geolocation

- **Decision**: Capture a branch/company geofence via the browser Geolocation API
  ("use my location"); always allow manual lat/lng entry (and an optional map picker) so
  denied/unavailable geolocation never blocks branch setup. Generate the branch QR poster
  client-side (`qrcode`) or via `branches/generate_qr.php`.
- **Rationale**: Mirrors `branch_location_sheet.dart`; resilient default.

## D12. Maintenance / version gate

- **Decision**: A `maintenance-gate` provider reads the Firebase **Remote Config**
  maintenance flag (same project/keys as mobile) and shows a maintenance screen when
  active. "Forced app update" does not apply to web (no installable version to gate); a
  soft "refresh to update" notice may be shown if a new build is detected. (FR-035)
- **Rationale**: Reuses the mobile Remote Config mechanism; web has no app-store version.

## D13. Hosting / deployment (planning-level, was deferred)

- **Decision (default)**: Deploy on Vercel (matches farkha), env split: public
  `NEXT_PUBLIC_*` (Firebase web config, API host) vs server-only `SECURITY_USER` /
  `SECURITY_KEY`. Confirm domain at deploy time. This is a deploy decision, not a spec
  change.
- **Alternatives**: Self-hosted Node/Docker behind the existing infra — viable; pick at
  deploy time. No code impact (standard Next.js output).

## D14. Testing strategy

- **Decision**: Vitest + React Testing Library for hooks/components; MSW to mock the
  contract catalog; Playwright for the spec's independent-test flows (US1 login→dashboard,
  US3 employee CRUD, US4 manual attendance + note, US5 payroll view + bulk adjust, US6
  leave approval, US9 permission enforcement incl. direct-URL block).
- **Rationale**: Each user story is independently testable (spec) and maps to an e2e.

## Open items — resolved as defaults (no blockers)

| Item | Resolution |
|------|-----------|
| Hosting/domain | Vercel default; confirm at deploy (D13) |
| Apple sign-in web setup | Apple Service ID + return URL configured at deploy; providers fixed (D3) |
| Maintenance gate behavior | Remote Config flag; no forced-update on web (D12) |
| Observability | Firebase Analytics (as mobile) + Next.js error boundaries/logging; detailed tracing deferred |
| Concurrent edits | Last-write-wins (backend behavior); surface backend conflict messages if returned |
