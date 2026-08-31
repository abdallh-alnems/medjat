# Medjat Central — Web Edition

The admin web app for **Medjat Central** HR/payroll. A feature-for-feature port of the
Flutter admin app (`frontend/mobile/manager`), talking to the **same PHP backend and
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

## Deployment (self-hosted on the Hetzner server)

The app is **not** on Vercel. It runs as a Node service on the same server as the PHP
backend, at **`app.medjatapp.com`**, behind Nginx and Cloudflare. It can't be a static
export — the BFF proxy `src/app/api/[...path]/route.ts` injects the secret
`SECURITY_USER`/`SECURITY_KEY` server-side.

> The repo folder is `frontend/web/manager`, but the **server** directory is still
> `/var/www/medjat-web/central` — it is wired into `medjat-web.service` and the Nginx
> vhost. Do not "fix" the paths below to match the repo folder.

1. Deploy = rsync this folder (excluding `node_modules`, `.next`, `.git`) to
   `/var/www/medjat-web/central` on the server.
2. Then on the server:
   ```bash
   cd /var/www/medjat-web/central
   npm ci && npm run build
   systemctl restart medjat-web        # runs `next start -H 127.0.0.1 -p 3000` as www-data
   ```
3. Env lives in `/var/www/medjat-web/central/.env.local` (not in git): `SECURITY_USER`,
   `SECURITY_KEY`, `NEXT_PUBLIC_API_HOST=https://api.medjatapp.com/backend_medjet`,
   `NEXT_PUBLIC_FIREBASE_*`.
4. Nginx vhost `/etc/nginx/sites-available/medjat-web` terminates TLS (Cloudflare Origin CA)
   and proxies 443 → `127.0.0.1:3000`.
5. In the Firebase console for the `medjat` project (already done for `app.medjatapp.com`):
   - Auth → **Authorized domains**: the deploy domain (and `localhost` for dev).
   - Auth → **Sign-in method**: **Google** and **Apple** enabled for web.
     - Apple: a **Services ID** + return URL `https://<domain>/__/auth/handler`.
6. Smoke test against SC-002/SC-003: log in with a known account and confirm web data
   matches the mobile app for the same company.

### Security checklist (SC-006)

- `SECURITY_USER` / `SECURITY_KEY` must **not** appear in any `NEXT_PUBLIC_*` var.
- All browser data calls go to `/api/...`; the backend host is never called directly
  from the client. Verify in browser devtools → Network.
