# Implementation Plan: Permedjat Central — Web Edition

**Branch**: `003-permedjat-central-web` | **Date**: 2026-06-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-permedjat-central-web/spec.md`

## Summary

Build a full-featured web edition of the Permedjat Central HR/payroll **admin** app,
reproducing every administrator-facing capability of the `permedjat_central` Flutter app
against the **same backend API and Firebase project**. The implementation reuses the
proven `farkha_web` architecture: Next.js App Router (React 19 + TypeScript), a
server-side `/api/[...path]` proxy that injects backend Basic-auth credentials and
forwards the user's Firebase ID token + tenant/device headers, TanStack Query for
server state, Zustand for session/UI state, shadcn/Tailwind v4 for the design system,
RTL Arabic-first theming with light/dark, and PWA installability. Exports use
jsPDF + xlsx + CSV (replacing the mobile Word/.docx). v1 ships full feature-parity in
a single release; no employee self check-in (admin-only attendance).

## Technical Context

**Language/Version**: TypeScript 5.x, React 19, Next.js 16 (App Router), Node 20+
**Primary Dependencies**: next, react/react-dom, @tanstack/react-query, zustand,
axios, firebase (auth + remote-config + analytics), react-hook-form + zod,
shadcn + @base-ui/react, tailwindcss v4 + tw-animate-css, lucide-react, sonner,
recharts (dashboard/branch comparison), date-fns/dayjs, jspdf + html2canvas (PDF),
xlsx (Excel/CSV), react-day-picker (month/period pickers), qrcode (branch QR poster),
react-markdown + remark-gfm (support/markdown), next-themes (light/dark)
**Storage**: None local-authoritative. Server state via TanStack Query cache;
session/UI via Zustand (persisted to localStorage); tokens via Firebase SDK +
httpOnly-less browser context (ID token fetched per request). Backend MySQL is
unchanged and reached only through the existing PHP API.
**Testing**: Vitest + React Testing Library (unit/component), Playwright (critical
e2e flows: login→dashboard, manual attendance, leave approval, payroll view), MSW for
API mocking against the contract catalog
**Target Platform**: Modern evergreen browsers (desktop, tablet, mobile widths);
installable PWA
**Project Type**: Web application (frontend-only client; backend already exists)
**Performance Goals**: Dashboard reachable < 30s first visit; 95% of list/detail
views render data < 2s for companies up to 500 employees (SC-002, SC-005); live
attendance board polls every 25s (matches mobile)
**Constraints**: Backend security credentials never exposed to the browser (all calls
via `/api` proxy); strict tenant isolation (X-Tenant-Id on every call); Arabic RTL
default + English LTR; EGP currency; no Web Push in v1; no .docx export
**Scale/Scope**: ~60 screens / 10 user stories / ~16 backend domains
(auth, tenant, dashboard, employees, documents, branches, attendance, payroll,
leaves, breaks, shifts/schedule, settings, managers/permissions, biometric,
categories, assets, loans, bulk-adjustments, settlements, reports, support,
notifications, audit)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution (`.specify/memory/constitution.md`) is an unratified template
with placeholder principles — no concrete, enforceable gates are defined. Therefore no
constitution gate blocks this plan. We adopt sensible defaults in lieu of a ratified
constitution:

- **Parity-first**: Web behavior must match the mobile app's data and rules (backend is
  the single source of truth; the client adds no business logic the backend doesn't own).
- **Approach reuse**: Mirror `farkha_web` structure/conventions to keep the two web
  properties consistent (explicit spec requirement).
- **Security**: No backend credentials in client bundles; all API traffic via the proxy.
- **Testability**: Each user story is independently testable per the spec.

**Result**: PASS (no violations; Complexity Tracking not required).

## Project Structure

### Documentation (this feature)

```text
specs/003-permedjat-central-web/
├── plan.md              # This file
├── research.md          # Phase 0 — decisions & rationale
├── data-model.md        # Phase 1 — entities & relationships
├── quickstart.md        # Phase 1 — setup & run
├── contracts/           # Phase 1 — backend API contract catalog
│   └── api-catalog.md
├── checklists/
│   └── requirements.md  # Spec quality checklist (from /speckit.specify)
└── tasks.md             # Phase 2 — created by /speckit.tasks (NOT here)
```

### Source Code (repository root)

A new sibling web app under `frontend/`, mirroring `farkha_web` conventions:

```text
frontend/web/manager/
├── public/
│   ├── manifest.json
│   ├── icons/                     # PWA + Permedjat papyrus icon set
│   ├── fonts/                     # IBM Plex Sans Arabic, Geist (self-hosted)
│   └── sw.js                      # PWA shell SW (no push in v1)
├── src/
│   ├── app/
│   │   ├── (auth)/                # login, signup, verify-email, forgot-password
│   │   │   ├── login/page.tsx
│   │   │   ├── signup/page.tsx
│   │   │   ├── verify-email/page.tsx
│   │   │   ├── forgot-password/page.tsx
│   │   │   └── layout.tsx
│   │   ├── (app)/                 # authenticated, tenant-scoped shell
│   │   │   ├── onboarding/page.tsx           # create / join company
│   │   │   ├── dashboard/page.tsx
│   │   │   ├── employees/page.tsx
│   │   │   ├── employees/[id]/page.tsx
│   │   │   ├── employees/new/page.tsx
│   │   │   ├── employees/[id]/documents/page.tsx
│   │   │   ├── employees/[id]/settlement/page.tsx
│   │   │   ├── terminated/page.tsx
│   │   │   ├── attendance/page.tsx
│   │   │   ├── payroll/page.tsx
│   │   │   ├── payroll/bulk-adjustments/…
│   │   │   ├── loans/page.tsx
│   │   │   ├── leaves/page.tsx
│   │   │   ├── breaks/page.tsx
│   │   │   ├── branches/page.tsx
│   │   │   ├── branches/[id]/qr/page.tsx
│   │   │   ├── shifts/…  schedule/page.tsx
│   │   │   ├── reports/(attendance|payroll|employees|leaves|documents)/page.tsx
│   │   │   ├── settings/(company|deductions|leave|statutory|attendance-method|
│   │   │   │            required-documents|categories|assets)/page.tsx
│   │   │   ├── team/page.tsx                 # admins, invites, permissions
│   │   │   ├── support/(page|[id])/page.tsx
│   │   │   ├── notifications/page.tsx
│   │   │   ├── activity-log/page.tsx
│   │   │   ├── account/page.tsx
│   │   │   └── layout.tsx                    # AppShell + auth/tenant guard
│   │   ├── api/[...path]/route.ts            # BFF proxy (creds + token + tenant)
│   │   ├── layout.tsx                        # root: providers, RTL, theme, fonts
│   │   └── globals.css                       # Permedjat theme tokens (teal/blue brand)
│   ├── components/
│   │   ├── layout/  (app-shell, sidebar/nav, topbar, mobile bottom-nav, guards)
│   │   ├── ui/      (shadcn primitives)
│   │   └── <domain>/ (employee-card, stat-card, attendance-table, payslip, …)
│   ├── lib/
│   │   ├── api/        client.ts + one module per backend domain
│   │   ├── firebase/   config.ts, auth.ts (email/pw + Google + Apple), remote-config.ts
│   │   ├── hooks/      use-auth, use-auth-token, use-tenant, use-permissions, per-domain query hooks
│   │   ├── stores/     auth-store, tenant-store, ui-store (Zustand)
│   │   ├── providers/  query-provider, theme-provider, pwa-provider, maintenance-gate
│   │   ├── i18n/       ar/en dictionaries (ported from locale/*.dart), useT()
│   │   ├── permissions/ role + override model (ported from roles)
│   │   ├── export/     pdf.ts, excel.ts, csv.ts
│   │   ├── types/      one file per entity (ported from data/model/*.dart)
│   │   └── utils.ts    currency (EGP), dates, formatting
│   └── …
├── .env.local.example
├── next.config.ts, tailwind/postcss, tsconfig.json, package.json
└── README.md
```

**Structure Decision**: Web application (Option 2, frontend only). The backend
(`backend_permedjat`) and Firebase project are reused unchanged; this plan delivers a new
Next.js client at `frontend/web/manager/`, a direct sibling of the existing
`frontend/mobile/manager` Flutter app, following `farkha_web`'s `src/app` + `src/lib`
+ `src/components` layout. Route groups `(auth)` and `(app)` separate the public auth
surface from the authenticated, tenant-guarded shell.

## Phase 0 — Research

See [research.md](./research.md). All spec clarifications are resolved; the remaining
open decisions (hosting, Apple web setup, maintenance-gate behavior, observability,
concurrency) are recorded there with chosen defaults so no `NEEDS CLARIFICATION`
blocks design.

## Phase 1 — Design & Contracts

- [data-model.md](./data-model.md) — entities ported from `lib/data/model/*.dart`.
- [contracts/api-catalog.md](./contracts/api-catalog.md) — the backend endpoint catalog
  (ported from `lib/core/constant/id/app_links.dart`) the web client consumes via the
  proxy, grouped by domain with method, purpose, and key params.
- [quickstart.md](./quickstart.md) — env, install, run, and verification steps.

## Complexity Tracking

No constitution violations. No entries required.
