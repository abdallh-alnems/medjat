# permedjat_central_desktop

Desktop shell for **Permedjat Central** — a real installable app (`.dmg` on macOS, `.exe`
installer on Windows) whose window renders the live web app at `app.permedjatapp.com`.

## Why it is built this way

The app has two halves, and they update differently:

| | Lives in | Updates by |
|---|---|---|
| Every screen, feature and fix | `permedjat_central_web` (the server) | `deploy-web.sh` — installed copies pick it up on next launch |
| Window, menu, icon, native capabilities | this project (the user's machine) | shipping a new installer |

So product work stays in the web app and reaches desktop users with no re-install. Only
the shell — which is a window and a bridge, not a feature surface — needs redistributing,
and only when a *new native capability* is added.

The service worker in the web app is `network-first` for navigations and never caches
`/api`, and Next.js hashes its bundle filenames, so a deployed change is not held back by
a stale cache.

## Running it

```bash
npm install
npm start                 # against production (app.permedjatapp.com)
npm run dev               # against a local `npm run dev` on :3000
PERMEDJAT_URL=… npm start    # against anything else
```

`npm install` alone is not enough on npm 12+: install scripts are blocked by default and
Electron downloads its binary in `postinstall`. If `node_modules/electron/dist` is
missing, run `npm install-scripts approve electron electron-winstaller`.

## Building installers

```bash
npm run icons       # regenerates build/icon.{icns,ico,png} from the shared brand master
npm run build:mac   # dist/Permedjat Central-<version>-arm64.dmg + …-1.0.0.dmg (Intel)
npm run build:win   # dist/Permedjat Central Setup <version>.exe
```

macOS builds **arm64 and x64 as separate DMGs**, not a universal binary: merging two
~250 MB bundles and re-signing the result is the heaviest step in the build and is not
worth the convenience of a single file on an 8 GB machine.

The Windows NSIS installer builds fine **from macOS** — electron-builder carries its own
NSIS and 7-zip, so Wine is not needed. What still requires Windows is *signing* the
`.exe`; see below.

## Code signing

`npm run build:mac` produces an **ad-hoc signed** app: it runs on the machine that built
it, but Gatekeeper refuses it elsewhere (users would have to right-click → *Open*). Fine
for internal testing, not for handing to client companies.

### macOS — the real thing

The keychain currently holds only *Apple Development* certificates, which cannot sign for
distribution outside the App Store. A **Developer ID Application** certificate is included
with the existing Apple Developer account at no extra cost:

1. Create a *Developer ID Application* certificate (Xcode → Settings → Apple Accounts →
   the account row → Manage Certificates… → `+`) so it lands in the login keychain.
2. Create an app-specific password at appleid.apple.com — notarization uploads the build
   to Apple, which needs one.
3. Build:

```bash
# Name and team only — electron-builder rejects the "Developer ID Application:"
# prefix and picks the certificate type itself.
export APPLE_IDENTITY="<name> (<TEAMID>)"
export APPLE_ID="<apple-id-email>"
export APPLE_TEAM_ID="<TEAMID>"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
npm run build:mac:signed
```

That turns on the hardened runtime and notarizes. The ad-hoc `afterPack` step stands aside
automatically when `APPLE_IDENTITY` is set. Notarization takes a few minutes — Apple
processes the upload server-side.

#### The DMG needs signing too

electron-builder handles the `.app` and stops there: `dmg.sign` defaults to false, and its
notarization runs during `afterSign`, before the image is even created. An unsigned
container does not matter over USB, but a download carries a quarantine flag and Gatekeeper
assesses the **image** before anyone reaches the app inside — so a notarized app ends up
behind a "cannot be verified" dialog on the one path clients actually use.

`build:mac:signed` therefore chains `sign:dmg`, which signs, notarizes and staples each
image, then verifies it the way a quarantined download is verified:

```bash
npm run sign:dmg              # skips images that already validate
npm run sign:dmg -- --force   # re-sign regardless
```

It reads credentials from the notarytool keychain profile `permedjat-notarize`
(`NOTARY_PROFILE` overrides). A finished image reports:

```
spctl -a -t open --context context:primary-signature -vvv "dist/….dmg"
  → accepted   source=Notarized Developer ID
```

`xcrun stapler validate` on the DMG is the other half — without a stapled ticket the check
needs a live round-trip to Apple, so a client on a bad connection sees it fail.

Signing prompts once for the login keychain password; answer **Always Allow**, or the
prompt returns for every file in the bundle.

To keep the password out of the environment, `APPLE_KEYCHAIN_PROFILE` reads it from a
stored profile instead — but `xcrun notarytool store-credentials` only completes the write
from a real interactive Terminal. Run it there first, or stay with the env vars above:

```bash
xcrun notarytool store-credentials "permedjat-notarize" \
  --apple-id "<apple-id-email>" --team-id "<TEAMID>"
```

### Windows

SmartScreen shows an "unrecognized app" warning and some antivirus products flag the
installer until the `.exe` is signed. That needs a **paid** code-signing certificate
(yearly, from a CA — OV certificates build reputation over time, EV ones start clean), and
signing has to happen on Windows. Nothing in this repo can shortcut it.

## Adding a native capability

This is the point of having a shell at all — things the browser cannot do. The pattern is
three small pieces:

```js
// src/main.js — the native work, in a full Node.js process
ipcMain.handle('zk:read', async (_event, { ip, port = 4370 }) => {
  // net.Socket / dgram — no browser sandbox here
});
```

```js
// src/preload.js — the only surface the page can see
contextBridge.exposeInMainWorld('permedjat', {
  isDesktop: true,
  readDevice: (options) => ipcRenderer.invoke('zk:read', options),
});
```

```ts
// permedjat_central_web — feature-detected, so browsers are unaffected
if (window.permedjat?.isDesktop) {
  const punches = await window.permedjat.readDevice({ ip });
}
```

The same deploy serves browser and desktop users; the desktop-only UI simply does not
render in a browser. Note that the backend's current ZKTeco integration is **push only**
(the terminal dials `/iclock/…` on port 8090) — talking to a terminal directly
over the LAN on port 4370 is a different protocol, needs the machine to be on the same
network as the device, and varies by firmware.

## Sign-in

Firebase runs Google/Apple sign-in as a popup on `medjat.firebaseapp.com` and falls back
to a full-page redirect. Both leave the app origin, so `AUTH_HOSTS` in `src/main.js` keeps
those hosts inside the app — without that list the navigation guard hands the popup to the
system browser and login can never complete.

Google's OAuth endpoint was checked directly against this Electron build (40.x): it serves
the normal account chooser and does **not** raise `disallowed_useragent`, so no user-agent
spoofing is needed — faking it would only make the origin's Cloudflare bot rules see a
mismatched client.

### Passkeys need the real browser

`PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()` returns **false** in
Electron: there is no bridge to Touch ID or the iCloud keychain. A Google account protected
by a passkey therefore cannot finish signing in in this window — Google offers its
cross-device fallback, which needs integration Electron also lacks, and the flow dead-ends
on "Something went wrong … Make sure Bluetooth is on".

So the login page shows a **"تسجيل الدخول عبر المتصفح"** button when `window.permedjat` is
present:

1. `auth:browser` generates a nonce and opens `${APP_URL}/login?desktop=<nonce>` in the
   system browser.
2. The user signs in there — passkeys work, because it is a real browser.
3. The page calls `v1/auth/desktop/authorize` for a single-use code and redirects to
   `permedjat://auth?code=…&state=<nonce>`.
4. `handleAuthLink` checks the nonce against the one this process generated (anything else
   is ignored) and loads `${APP_URL}/desktop-auth?code=…`.
5. That page calls `v1/auth/desktop/exchange`, which claims the code and mints a Firebase
   custom token; `signInWithCustomToken` turns it into an ordinary session.

The code is single-use, expires after two minutes, and is stored only as a hash.

Email/password sign-in in the window is unaffected and remains the shorter path for anyone
without a passkey.

## Known limits

- **Requires internet.** Without it the window shows `src/offline.html` (Arabic, with a
  retry button) instead of a browser error page.
- **Geolocation** is unreliable in Electron — Chromium's provider needs a Google API key,
  so `getCurrentPosition` may fail even when permission is granted. The web app already
  degrades gracefully ("enter values manually"), but branch-location picking and web
  check-in should be assumed not to work on desktop until this is wired to a native
  provider.
- **The shell does not self-update.** `electron-updater` can be added later; it needs a
  signed build and somewhere to host the update feed.

## Security posture

`contextIsolation` and `sandbox` on, `nodeIntegration` off. Navigation is pinned to the
app origin — any other link is handed to the system browser. Permission requests are
allow-listed (clipboard, fullscreen, geolocation, media, notifications); everything else
is refused.
