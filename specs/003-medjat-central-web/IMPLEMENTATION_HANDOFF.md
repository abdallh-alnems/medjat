# Implementation Handoff — Medjat Central Web Edition

> **مذكرة تسليم لنموذج/مطوّر آخر يبدأ من سياق بارد.**
> اقرأ هذا الملف **بالكامل أولاً**، ثم نفّذ `tasks.md` بالترتيب. هذا الملف موجِّه
> (imperative): يقول لك ماذا تبني، من أين تأخذ الحقيقة، وما المحاذير التي ستكسر العمل لو
> تجاهلتها. لا تبدأ الكود قبل إكمال قسم "Before you write any code".

---

## 0. TL;DR (one paragraph)

Build a **Next.js (App Router) web app** that is a feature-for-feature port of the
existing **Flutter admin app** `frontend/mobile/central`, talking to the **same PHP
backend and same Firebase project**. Copy the architecture of the already-working
reference app `frontend/farkha_web` (../../../farkha/frontend/farkha_web). It is an
**admin-only** HR/payroll tool (no employee self check-in). Ship **all features in one
release**. The single hardest correctness requirement: **all browser→backend traffic
goes through a server-side proxy `/api/[...path]` that injects backend credentials and
forwards `X-Firebase-Token` + `X-Tenant-Id` + `X-Device-Id`** — credentials must never
reach the browser.

---

## 1. Sources of truth (read in this order)

| # | File | What it gives you |
|---|------|-------------------|
| 1 | `specs/003-medjat-central-web/spec.md` | WHAT to build + WHY (10 user stories, 35 FRs, 9 success criteria, clarifications). The `## Clarifications` section settles 5 decisions — **do not re-litigate them**. |
| 2 | `specs/003-medjat-central-web/plan.md` | The stack, project structure, and the target app folder. |
| 3 | `specs/003-medjat-central-web/research.md` | 14 technical decisions (D1–D14) with rationale. When in doubt about "how", this answers it. |
| 4 | `specs/003-medjat-central-web/data-model.md` | Every entity → becomes a TS type in `src/lib/types/`. |
| 5 | `specs/003-medjat-central-web/contracts/api-catalog.md` | **The full backend endpoint list** (every PHP path), grouped by domain. This is your API module map + MSW mock list. |
| 6 | `specs/003-medjat-central-web/quickstart.md` | Scaffold, env vars, run, and the 13 verification steps. |
| 7 | `specs/003-medjat-central-web/tasks.md` | **113 ordered, checklisted tasks.** This is your execution plan. Work top to bottom; respect phase checkpoints. |

**Two reference codebases you will read constantly:**

- **Port FROM (the spec):** `frontend/mobile/central/` — the Flutter app. Its
  `lib/data/data_source/remote/*` (API calls), `lib/data/model/*` (entities),
  `lib/logic/controller/*` (business logic per screen), `lib/view/screen/*` (UI/UX), and
  `lib/core/constant/id/app_links.dart` (every endpoint), `lib/core/constant/locale/{ar,en}.dart`
  (all UI strings → i18n), `lib/core/constant/theme/app_colors.dart` (theme tokens).
- **Copy the HOW (the pattern):** `../farkha/frontend/farkha_web/` — a finished Next.js
  app with the **exact** patterns to mirror: `src/app/api/[...path]/route.ts` (proxy),
  `src/lib/api/client.ts`, `src/lib/firebase/*`, `src/lib/stores/auth-store.ts`,
  `src/lib/providers/*`, `src/app/layout.tsx`, `src/components/ui/*`, `globals.css`.

---

## 2. Target location & stack (non-negotiable)

- **Build the new app at:** `frontend/web/central/` (sibling of the Flutter app).
- **Stack (mirror farkha_web):** Next.js 16 App Router · React 19 · TypeScript ·
  TanStack Query (server state) · Zustand (session/UI) · axios · Firebase Web SDK
  (auth + remote-config + analytics — **NOT messaging**) · shadcn + Tailwind v4 ·
  react-hook-form + zod · recharts · sonner · next-themes · jsPDF + html2canvas + xlsx
  (exports) · qrcode · react-markdown.
- **Do not** introduce state libs, UI kits, or data-fetching libs outside this set —
  consistency with farkha_web is an explicit requirement.

---

## 3. The 6 decisions already made — DO NOT change them

These are settled in `spec.md` → `## Clarifications`. Treat as law:

1. **Admin-only attendance.** No employee self check-in (no GPS/QR/face capture). Web
   does: manual record, notes, live board (25s poll), and saving the attendance-method
   *setting* for the separate employee app.
2. **Geolocation** is used **only** to capture a branch geofence (with a manual lat/lng
   fallback). **Biometric = view status + delete only** (no webcam capture).
3. **Single release, full parity** — build all 10 user stories. Priorities P1–P3 are
   build-order hints, not separate releases.
4. **Notifications = in-app list + preferences only.** **No Web Push, no FCM token, no
   `firebase/messaging`, no push service worker.**
5. **Exports = PDF + Excel + CSV.** The Flutter app's Word/.docx is **replaced by Excel**.
   Keep the payroll bank-file CSV.
6. **One company per user.** No company switcher. No tenant → route to `/onboarding`.

---

## 4. Before you write any code (gather these)

1. **Backend host + Basic-auth creds** — read from `frontend/mobile/central/.env`:
   `API_HOST`, `SECURITY_USER`, `SECURITY_KEY`. Put `API_HOST` →
   `NEXT_PUBLIC_API_HOST`; put `SECURITY_USER`/`SECURITY_KEY` → **server-only** env (no
   `NEXT_PUBLIC_` prefix). They live only in the proxy.
2. **Firebase web config** — from the Firebase console (same project the mobile app
   uses; see `frontend/mobile/central/lib/core/constant/firebase_options.dart` for the
   project id). Fill `NEXT_PUBLIC_FIREBASE_*` per `quickstart.md`. Add `localhost` + the
   deploy domain to Firebase Auth **authorized domains**, and enable **Google + Apple**
   providers for web.
3. **Confirm with the user** (these are deploy-time, do not block coding): final hosting
   target/domain (research D13 defaults to Vercel) and Apple Service ID for web.

---

## 5. The single most important file: the proxy (`/api/[...path]/route.ts`)

Mirror `farkha_web/src/app/api/[...path]/route.ts` **but extend it**. The farkha proxy
only forwards `Authorization`. Medjat's backend authenticates via custom headers, so the
Medjat proxy MUST also forward, when present on the incoming request:

- `X-Firebase-Token` — the user's Firebase ID token
- `X-Tenant-Id` — the selected company id
- `X-Device-Id` — a stable per-browser id (generate once, store in localStorage)

…while still injecting `Authorization: Basic base64(SECURITY_USER:SECURITY_KEY)` server-
side. The browser axios client (`src/lib/api/client.ts`, `baseURL: "/api"`) has a request
interceptor that attaches those three headers on every call (token via
`auth.currentUser.getIdToken()`, tenant from the tenant store, device id from localStorage).

**Verification gate (SC-006):** open browser devtools → Network. You must NOT see
`SECURITY_USER`/`SECURITY_KEY` anywhere, and every data call must go to `/api/...`, never
directly to `API_HOST`.

---

## 6. How to map a Flutter screen → a web feature (the repeatable recipe)

For each user story / screen, repeat this loop (the tasks.md `[P]` tasks already split it):

1. **Find the endpoints**: open the matching `lib/data/data_source/remote/<x>_data/<x>_data.dart`
   and `lib/core/constant/id/app_links.dart`. Cross-check with `contracts/api-catalog.md`.
2. **Type it**: port the matching `lib/data/model/<x>_model.dart` → `src/lib/types/<x>.ts`
   (see `data-model.md` for the field list).
3. **API module**: `src/lib/api/<domain>.ts` — one function per endpoint using
   `apiGet`/`apiPost`. Keep PHP paths exactly as in the catalog.
4. **Query hooks**: `src/lib/hooks/use-<domain>.ts` — `useQuery`/`useMutation`. For the
   live board use `refetchInterval: 25_000`.
5. **Business rules**: read the matching `lib/logic/controller/<x>/<x>_controller.dart`
   to copy validation, sorting, filtering, status transitions, permission checks. The
   backend is the source of truth; don't invent rules it doesn't enforce.
6. **UI**: read `lib/view/screen/<x>/*` for layout/UX intent, then build with shadcn +
   Tailwind, RTL-first. Reuse strings from the i18n dictionaries (step in §7).
7. **States**: every data view needs loading (skeleton), empty (purposeful message), and
   error (with retry) — FR-034.
8. **Permissions**: wrap actions/nav in `<Can permission=…>`; guard restricted routes so
   even a direct URL is blocked (SC-008).
9. **Test**: MSW contract test (success/empty/4xx/offline) + the story's Playwright e2e.

---

## 7. i18n, theme, fonts (do this in Foundational phase)

- **Strings**: port `lib/core/constant/locale/ar.dart` and `en.dart` (hundreds of keys)
  into `src/lib/i18n/{ar,en}.ts`. Arabic is default + RTL; English is LTR. Add a `useT()`
  hook. Language + appearance toggle lives in the topbar and persists.
- **Theme**: port `lib/core/constant/theme/app_colors.dart` tokens to CSS variables in
  `globals.css`. Brand light `#2563EB` / dark `#60A5FA`, warm accent `#B8860B`, teal-
  tinted canvas/surface, plus error/warning/success. Support light/dark via next-themes.
- **Fonts — GOTCHA**: the Flutter project's **Geist `.ttf` files are corrupted** (they're
  Git-LFS/HTML pointer files, not real fonts). **Do not copy them.** Re-acquire real web
  fonts: **IBM Plex Sans Arabic** (primary) + **Geist**, self-host in `public/fonts/`.
- **Currency/format**: EGP, Arabic-Indic/Latin numerals, dates — one shared formatter in
  `src/lib/utils.ts`.

---

## 8. Execution order (from tasks.md)

1. **Phase 1 Setup** (T001–T008): scaffold, deps, tooling, theme, fonts, PWA assets.
2. **Phase 2 Foundational** (T009–T026): **proxy + client + interceptor first**, then
   firebase, stores, providers, i18n, permissions, types, exports, shell + guards, MSW.
   **No story may start until this is done.**
3. **Phase 3 US1 Auth/onboarding** (T027–T036) = **MVP boundary.** Stop and verify a real
   login → tenant-scoped dashboard route works before going wide.
4. **Phases 4–12** = US2…US10. After US1, they're largely independent; US3 (employees) is
   a soft prerequisite for employee-pickers in US4/US5/US6.
5. **Phase 13 Polish** (T104–T112): PWA, RTL audit, security check, perf (500 employees
   < 2s), a11y, analytics, deploy.

Respect the **Checkpoint** lines in tasks.md — each is a "this story now works
independently" gate. Tick tasks `- [x]` as you finish.

---

## 9. Definition of done (per the spec's Success Criteria)

- All 10 user stories pass their Independent Test (see the story→e2e table in tasks.md).
- Data on web matches the mobile app for the same account/company (SC-003).
- No backend creds in the browser; all calls via `/api` (SC-006).
- Arabic RTL + English LTR both correct, EGP/date/number formatting (SC-007).
- Permission enforcement airtight incl. direct-URL (SC-008).
- Installable PWA; works desktop/tablet/mobile widths (SC-009).
- Lists/details < 2s for a 500-employee company (SC-005).

---

## 10. Common traps (each one will cost you hours)

1. Forgetting to forward `X-Tenant-Id`/`X-Firebase-Token`/`X-Device-Id` in the proxy →
   every authenticated call 401s. (This is the #1 difference from farkha_web.)
2. Calling the backend without a tenant after onboarding → data leaks/empties. Treat
   missing tenant as "go to onboarding".
3. Copying the corrupted Geist fonts → broken text rendering.
4. Adding `firebase/messaging` / a push service worker → out of scope, will fail setup.
5. Building an employee self check-in UI → out of scope; this is admin-only.
6. Generating `.docx` → use Excel/PDF/CSV only.
7. Client-only permission checks treated as security → the backend is the enforcer; client
   checks are UX only.
8. Hardcoding strings instead of using the i18n dictionaries → breaks Arabic/English.

---

## 11. What to ask the user (only if blocked)

You should be able to build everything from the artifacts above. Only interrupt the user
for: (a) the actual secret values in §4 if you can't read them, (b) final hosting/domain
and Apple Service ID at deploy time, (c) any backend endpoint that returns a shape that
contradicts `data-model.md` (report it; don't guess silently).

Start now at **tasks.md → T001**.
