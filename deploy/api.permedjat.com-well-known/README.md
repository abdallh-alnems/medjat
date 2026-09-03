# Universal / App Links — deployment for `api.permedjat.com`

These two files make the team-invitation email link
`https://api.permedjat.com/backend_medjet/join_team.php?code=XXXX`
open the **permedjat_central** app directly (no browser page), so the app then joins
the company automatically. When the app is not installed, the same link falls
back to the existing `join_team.php` landing page (install / web / code).

> **Status (verified 2026-07-31): this is live** — both URLs below return 200. The source of
> truth is now `backend_medjet/.well-known/` in the repo; this folder is the historical
> Hostinger upload copy. There are **two separate sets**, one per app:
>
> | Host | App | Repo file |
> |------|-----|-----------|
> | `api.permedjat.com` | **permedjat_central** (team invite `join_team.php`) | `.well-known/apple-app-site-association-central`, `assetlinks-central.json` |
> | `permedjat.com` | **permedjat_app** (employee `/join`) | `.well-known/apple-app-site-association`, `assetlinks.json` |

## 1) Serve these two files from the **document root of `api.permedjat.com`**

They must resolve at the domain **root** (not under `/backend_medjet/`):

| File | Must be reachable at |
|------|----------------------|
| `apple-app-site-association` | `https://api.permedjat.com/.well-known/apple-app-site-association` |
| `assetlinks.json` | `https://api.permedjat.com/.well-known/assetlinks.json` |

Requirements (both):
- Served over **HTTPS**, **HTTP 200**, **no redirects**.
- `Content-Type: application/json`.
- `apple-app-site-association` has **no file extension**.
- The server is now **nginx on the Hetzner VPS** — there is no `.htaccess`. What the vhost must
  not do: send these paths through the API Basic-auth gate, or rewrite them into PHP.

Verify after upload:
```
curl -i https://api.permedjat.com/.well-known/apple-app-site-association
curl -i https://api.permedjat.com/.well-known/assetlinks.json
```
Both should be `200` + `application/json`.

Android verification helper:
https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://api.permedjat.com&relation=delegate_permission/common.handle_all_urls

## 2) iOS — one-time capability (Apple Developer portal)

For `applinks:api.permedjat.com` (added to `Runner.entitlements`) to work:
- In **Certificates, Identifiers & Profiles → Identifiers →
  `com.khawarizmie.medjat-central`**, enable **Associated Domains**.
- Regenerate the provisioning profile, then build & release the app.

Team ID used: `PN886D65DG` (appID `PN886D65DG.com.khawarizmie.medjat-central`).

## 3) Android — fingerprint

`assetlinks.json` already contains the SHA-256 you provided:
`A0:FD:3A:…:D3`
This must match the key that signs the **installed** app. If you use Google Play
App Signing, this should be the **App signing key certificate** SHA-256 from
*Play Console → App integrity*. (If they differ, add both fingerprints to the
array.) Then build & release the app.

## 4) Build & release the new app

The app code already handles the link and auto-joins. A new store build of
`permedjat_central` is required for all of the above to take effect.

## Notes
- No backend change is needed: `join_team.php` and the invitation email already
  point at this URL.
- These files only cover the management app (`permedjat_central`) on
  `api.permedjat.com`. The employee app's links (if any) are separate.
