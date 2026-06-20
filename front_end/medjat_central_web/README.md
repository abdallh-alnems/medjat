# Medjat Central — Web Edition

The admin web app for **Medjat Central** HR/payroll. A feature-for-feature port of the
Flutter admin app (`front_end/medjat_central`), talking to the **same PHP backend and
same Firebase project** through a server-side `/api/[...path]` proxy that injects
backend Basic-auth credentials and forwards `X-Firebase-Token` / `X-Tenant-Id` /
`X-Device-Id`.

Architecture mirrors `farkha_web`: Next.js 16 App Router · React 19 · TypeScript ·
TanStack Query · Zustand · Firebase Web SDK (auth + remote-config + analytics — **no
messaging / no Web Push**) · shadcn + Tailwind v4 · RTL Arabic-first.

## Setup

1. Copy `.env.local.example` → `.env.local` and fill in:
   - `SECURITY_USER` / `SECURITY_KEY` (server-only, from the Flutter `.env`)
   - `NEXT_PUBLIC_API_HOST` (the backend host, from the Flutter `API_HOST`)
   - `NEXT_PUBLIC_FIREBASE_*` (already prefilled for the `medjat` project)
2. Add `localhost` + your deploy domain to Firebase Auth **authorized domains**, and
   enable the Google + Apple web providers in the Firebase console.
3. `npm install`
4. `npm run dev` → http://localhost:3000

## Scripts

| Script | Purpose |
|--------|---------|
| `npm run dev` | Dev server |
| `npm run build && npm start` | Production build |
| `npm run lint` | ESLint |
| `npm test` | Vitest unit/component/contract |
| `npm run test:e2e` | Playwright e2e |

## Notes

- **Admin-only**: no employee self check-in. Attendance is manual recording + live board.
- **Exports**: PDF (jsPDF), Excel (xlsx), CSV (bank file). No `.docx`.
- **Fonts**: self-hosted IBM Plex Sans Arabic + Geist (see `public/fonts/`).
- **Notifications**: in-app list + preferences only. No Web Push / FCM in v1.

## Deployment (Vercel)

1. Push the repo and import the project into Vercel.
2. Set the env vars from `.env.local.example` in the Vercel project settings:
   - `SECURITY_USER` / `SECURITY_KEY` (server-only — never prefixed with `NEXT_PUBLIC_`)
   - `NEXT_PUBLIC_API_HOST`, `NEXT_PUBLIC_FIREBASE_*`
3. In the Firebase console for the `medjat` project:
   - Auth → **Authorized domains**: add the Vercel domain (and `localhost`).
   - Auth → **Sign-in method**: enable **Google** and **Apple** for web.
     - Apple: create a **Services ID** + return URL `https://<vercel-domain>/__/auth/handler`.
4. `npm run build` runs on Vercel automatically. The `/api/[...path]` proxy runs as
   Edge/Node serverless functions (default).
5. Smoke test against SC-002/SC-003: log in with a known account and confirm web data
   matches the mobile app for the same company.

### Security checklist (SC-006)

- `SECURITY_USER` / `SECURITY_KEY` must **not** appear in any `NEXT_PUBLIC_*` var.
- All browser data calls go to `/api/...`; the backend host is never called directly
  from the client. Verify in browser devtools → Network.
