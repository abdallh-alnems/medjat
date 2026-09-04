# Phase 1 — Quickstart: Permedjat Central Web Edition

How to scaffold, configure, run, and verify the web app. Mirrors the `farkha_web` setup.

## 1. Scaffold

```bash
cd frontend
# New Next.js app (App Router, TS, Tailwind v4)
npx create-next-app@latest permedjat_central_web --ts --eslint --app --src-dir --use-npm
cd permedjat_central_web
# Core deps (parity with farkha_web)
npm i @tanstack/react-query zustand axios firebase react-hook-form @hookform/resolvers zod \
      class-variance-authority clsx tailwind-merge tw-animate-css lucide-react sonner \
      next-themes recharts date-fns dayjs jspdf html2canvas xlsx react-day-picker \
      react-markdown remark-gfm qrcode input-otp @base-ui/react
# shadcn + dev
npx shadcn@latest init
npm i -D vitest @testing-library/react @testing-library/jest-dom jsdom msw @playwright/test \
        prettier prettier-plugin-tailwindcss
```

## 2. Environment

Create `.env.local` (see `.env.local.example`):

```bash
# Server-only (NEVER prefixed NEXT_PUBLIC — stays in the proxy)
SECURITY_USER=...            # backend Basic-auth user (same as Flutter .env SECURITY_USER)
SECURITY_KEY=...             # backend Basic-auth key
NEXT_PUBLIC_API_HOST=...     # e.g. https://<host>/backend_permedjat  (same as Flutter API_HOST)

# Firebase web config (same project as mobile)
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=...
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
NEXT_PUBLIC_FIREBASE_APP_ID=...
NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID=...
```

> The backend host + credentials come from the Flutter app's `.env`
> (`frontend/mobile/manager/.env`: `API_HOST`, `SECURITY_USER`, `SECURITY_KEY`).
> The Firebase web config comes from the Firebase console (Web app) for the same project
> the mobile app uses. Add the deploy domain + `localhost` to Firebase Auth authorized
> domains, and configure Google + Apple providers for web origins.

## 3. Proxy & client (the security boundary)

- `src/app/api/[...path]/route.ts` — forwards to `NEXT_PUBLIC_API_HOST`, injects
  `Authorization: Basic …`, and passes through `X-Firebase-Token`, `X-Tenant-Id`,
  `X-Device-Id` from the incoming request (Permedjat-specific vs farkha).
- `src/lib/api/client.ts` — browser axios `baseURL: "/api"`; a request interceptor adds
  the current Firebase ID token + tenant id + device id headers.

## 4. Run

```bash
npm run dev          # http://localhost:3000
npm run build && npm start
npm run lint
npx vitest           # unit/component
npx playwright test  # e2e (after dev server running or via webServer config)
```

## 5. Verification (maps to spec Success Criteria & user stories)

1. **US1 / SC-002** — Sign in (email/pw, Google, Apple) → reach company dashboard < 30s;
   no-tenant account → onboarding (create/join); logout clears session.
2. **US2** — Dashboard cards (present/absent/late/on-leave, attendance rate), branch
   comparison ranking, pending leave/break counts, payroll summary, expiring compliance.
3. **US3** — Add employee, search/filter (branch/shift/category/status)+sort, edit detail,
   document attach/verify, settlement → terminate → appears in terminated list.
4. **US4** — Record manual attendance (single + batch), add/edit/delete note, live board
   refreshes ~25s, export attendance (PDF/Excel) + empty-export message.
5. **US5** — Payroll period totals, bulk adjustment on selected employees, payslip PDF +
   Excel export, bank file CSV, loan creation affecting deductions.
6. **US6** — Approve/reject leave; create leave; act on break/permission requests.
7. **US7** — Branch create/edit + geolocation capture (with manual fallback), QR poster;
   shift assign + weekly schedule edit/publish.
8. **US8** — Generate + export attendance/payroll/employees/leaves/documents reports.
9. **US9 / SC-008** — Edit company settings; invite admin (role+branch) → pending/code;
   customize/reset per-admin permissions (GM locked); a restricted admin is blocked from
   actions and from restricted URLs directly.
10. **US10** — Support ticket + chat (poll new replies); notifications list + prefs;
    activity log; account language/appearance; delete account (last-GM warning).
11. **SC-006** — Inspect network: no `SECURITY_USER`/`SECURITY_KEY` in any browser asset
    or request; all data calls go through `/api`.
12. **SC-007** — Arabic RTL default + English LTR review; EGP + date/number formatting.
13. **SC-009** — Installable PWA; usable at desktop/tablet/mobile widths.

## 6. Notes / gotchas

- **Fonts**: re-acquire real IBM Plex Sans Arabic + Geist web fonts — the Flutter
  project's Geist `.ttf` are corrupted LFS/HTML pointers (do not copy them).
- **No Web Push in v1**: omit `firebase/messaging` + `firebase-messaging-sw.js`; the
  service worker is shell/offline only.
- **Maintenance gate**: read the same Firebase Remote Config maintenance flag as mobile;
  there is no forced-update on web.
- **Tenant isolation**: never call the backend without `X-Tenant-Id` once a tenant is
  selected; treat a missing tenant as "route to onboarding".
