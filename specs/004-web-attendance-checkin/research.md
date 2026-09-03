# Phase 0 Research — Web Attendance Check-In / Check-Out

**Feature**: `004-web-attendance-checkin` · **Date**: 2026-08-02

Each decision below resolves an unknown in the plan's Technical Context. Facts
about the existing system were verified against the code and the live database,
not recalled; file references are given so they can be re-checked.

---

## R-001 — Where the employee web surface lives

**Decision**: A new route group `src/app/(employee)/` inside the existing
`permedjat_central_web` Next.js application, deployed to the same origin
(`app.permedjatapp.com`), with its own auth context and **no imports from the admin
route tree**.

**Rationale**: `permedjat_central_web` is already deployed and operated (systemd
`permedjat-web.service`, nginx, Cloudflare TLS), and already carries the exact
platform pieces this surface needs: RTL, Arabic/English locales, the fonts, the
Tailwind/shadcn design system, and an axios layer. A separate application would
duplicate all of it to serve a single page.

**Critical correction found during research**: `permedjat_central_web` is an
**administrator** application. Its login (`src/lib/api/auth.ts`) posts a Firebase
ID token to `app/auth/login.php` — the admin path. Employees authenticate through
an entirely different endpoint (`app/auth/employee_login.php`, phone + activation
code). This surface is therefore **a new authenticated area, not a new route on
an existing one**; nothing in the current app can be reused for identity.

**Alternatives considered**:
- *Separate Next.js app on its own subdomain* — cleanest isolation, rejected on
  operational cost for the current scale. Recorded as a deviation in the plan's
  Complexity Tracking with the conditions for revisiting.
- *Static page served by the PHP backend* — avoids the origin-sharing risk
  entirely, but forfeits the design system, i18n and RTL work, and would be a
  fourth front-end technology to maintain.

---

## R-002 — The repeatable credential (resolves the spec's central contradiction)

**Decision**: At activation the employee sets a **6-digit PIN**. Thereafter, web
sign-in is **phone + PIN**. The activation code is consumed exactly once, to
establish the PIN.

**Why this was forced**: `app/auth/employee_login.php` documents its own
constraint in a comment — *"A normal activation code is single-use and lapses
after 24h"*. Two accepted clarifications then collide:

- Q1 answer: the browser is a **first door**, using phone + activation code
- Q4 answer: the session **ends at check-out**

Together they strand the employee on day two: the session is gone and the code
that opened it is burnt and expired. A repeatable secret is the only way to hold
both answers without HR re-issuing a code daily.

**Why 6 digits and not 4**: 4 digits is 10,000 possibilities. The web login page
is publicly reachable, which the app's login never really was, so the guessing
surface is genuinely new (FR-002b). 6 digits raises it to 1,000,000 while staying
numeric — which matters for a workforce that is not uniformly literate in Latin
script. Guessing is further bounded by per-phone lockout and per-IP rate limits
(R-007).

**Why not a password**: this is what ZenHR, Bayzat and Jisr use, and it is the
market's ESS pattern. Rejected because those products identify employees by
**company email**; Permedjat identifies by **phone**, and its target workforce
includes site and shift staff who have no work email and for whom a numeric
secret on a phone keypad is materially easier. The security difference is
recovered through lockout rather than entropy.

**Recovery**: an administrator with `manage_employees` resets the PIN, which
issues a fresh activation code. No SMS gateway is introduced. This doubles as an
immediate lockout control for a departing employee.

---

## R-003 — Why not WebAuthn / passkeys

**Decision**: Not in this release. Revisit as an optional hardening.

**Rationale**: WebAuthn is technically the better answer — the private key lives
in the device's secure element, the server verifies a signature rather than
trusting a client-reported boolean, and `userVerification: "required"` forces a
biometric at each punch. It is strictly stronger than the app's own
`local_auth` gate, which `2026_07_31_local_biometric_gate.sql` itself documents
as *"client-reported… A patched APK can send 1 without ever prompting."*

It was rejected for now because a survey of the attendance market found **no
product using passkeys for clock-in**. The market's controls are photo capture
plus IP restriction. Being the only vendor doing something in a mature category
is more often a signal of impracticality than of advantage — here, the likely
reason is enrolment friction and device-loss recovery for non-technical users.
The PIN reaches an adequate bar with a fraction of the support burden.

---

## R-004 — Session lifetime and one-session-per-employee

**Decision**: A web session token is issued on PIN sign-in and ends at whichever
comes first: **the employee's check-out**, or **16 hours**. Issuing a new web
session **revokes the employee's previous web session only** — mobile app tokens
are untouched.

**Rationale**: 16 hours covers a 12-hour shift plus overtime, so FR-003 holds;
ending at check-out means a shared computer is left safe without the departing
employee having to do anything (FR-004a). Scoping the single-session rule to the
web channel is deliberate: FR-005 speaks of a *browser* identity, and revoking
the app token would log an employee out of their phone every time they used a
browser.

**Existing-state note**: `employee_auth_tokens` has **no `expires_at` column** —
app tokens live until revoked. Rather than add expiry to a column shared with the
app (which would change app behaviour), expiry is stored on the new web session
row. See [data-model.md](./data-model.md).

**Lapse handling (FR-004b)**: hitting 16 hours while still checked in must never
strand an open shift. The employee signs in again with their PIN and the open
shift is still there — nothing about the attendance row depends on the session
that created it.

---

## R-005 — Network verification degrades to IP only

**Decision**: On the web channel `NetworkVerifier` is used in **IP mode only**.
When a branch's approved networks contain no `ip_v4`/`ip_cidr` entry, the network
constraint is reported as *unavailable* for that branch and the administrator is
told so in the settings screen (FR-014).

**Rationale**: verified in `core/NetworkVerifier.php` — `branch_networks.kind` is
`enum('bssid','ip_v4','ip_cidr')` and `ipMatches()` already handles both address
and CIDR forms, so **no backend work is needed for the IP path**. A browser has
no API for the joined access point, so the `bssid` rows are simply unreachable
from this channel.

**Infrastructure check**: `NetworkVerifier::clientIp()` reads `REMOTE_ADDR`, and
the server has `/etc/nginx/conf.d/cloudflare-realip.conf` mapping the real client
address onto it. IP matching therefore works correctly behind Cloudflare without
change.

---

## R-006 — Time handling

**Decision**: All recorded times resolve through `core/TenantClock.php`. Session
expiry and the shared-device window are computed **in SQL**
(`DATE_ADD(NOW(), INTERVAL ? SECOND)`), never in PHP.

**Rationale**: this is a standing project rule and it has already caused a
production bug — PHP runs UTC on the server while MySQL runs the server zone, so
a PHP-computed `expires_at` is born expired. The face-challenge implementation
hit exactly this. FR-010 additionally forbids trusting the browser's clock, which
is a stronger requirement than the app has: a browser's clock is user-editable
with no permission prompt at all.

---

## R-007 — Rate limiting and lockout

**Decision**: Three layers.

1. `RateLimiter::enforceIpLimit()` at the top of every new endpoint, matching
   the existing convention in `employee_login.php` and `check_in.php`.
2. `RateLimiter::checkLimit()` keyed on the **phone number** for the PIN sign-in
   and activation endpoints, so distributing an attack across IPs does not evade
   the limit.
3. A per-credential **lockout counter**: after 5 consecutive wrong PINs the
   credential is locked and only an administrator reset clears it.

**Rationale**: `core/RateLimiter.php` already exposes both `enforceIpLimit()` and
a general `checkLimit($identifier, $limit, $window)`, so layers 1 and 2 need no
new infrastructure. Layer 3 is what actually bounds a 6-digit space; rate limits
alone only slow it down. Every lockout is written to `attendance_security_logs`
so it is visible rather than silent.

---

## R-008 — Punch photo capture and storage

**Decision**: The browser sends the image **base64-encoded in the JSON request
body**, exactly as face enrolment already does. A new `core/PunchPhotoService.php`
mirrors `BiometricEnrollment::storeReferencePhoto()` — decode, enforce a byte
cap, confirm with `getimagesizefromstring()` that it really is an image before
writing under a `.jpg` name — and stores to `uploads/attendance/` with the path
recorded on the attendance row.

**Rationale**: reusing the established pattern avoids introducing multipart
handling to a codebase that has none, and inherits an already-reviewed
validation path. The image is evidence for human review only — it is **never**
scored, matched, or used to accept or reject a punch (FR-028).

**Consent and retention**: FR-017c requires the employee be told before capture.
Retention follows the existing attendance-data policy under Labour Law 14/2025;
this feature invents no new policy.

**Failure mode**: when photo capture is enabled and no usable image is obtained
— no camera, permission denied, decode failure — the punch is **refused**
(FR-017b). Recording attendance without the evidence the company asked for would
quietly downgrade their configured control.

---

## R-009 — Shared-device detection

**Decision**: A random UUID minted on first visit and stored in a long-lived
cookie identifies the browser. It is written to the session row's `device_id`
(already `NOT NULL` on `employee_auth_tokens`). When punches for **two or more
distinct employees** carry the same `device_id` within one tenant working day,
every punch in that group is flagged.

**Rationale**: FR-019 asks for detection, not prevention, and FR-020 forbids
auto-rejection. A cookie UUID is trivially clearable — which is acceptable
precisely because this is advisory: clearing it costs the colluding pair effort
every single day and still leaves the IP correlation.

**Deliberately not doing**: browser fingerprinting. It is more evasion-resistant
but is a privacy escalation that sits badly next to Labour Law 14/2025 consent
obligations, and it is not what the market does — competitors rely on the photo.

---

## R-010 — Extending `employee_auth_tokens.platform`

**Decision**: A migration extends the enum to
`enum('android','ios','web')`, restating all values.

**Verified problem**: the column is `enum('android','ios') NOT NULL`, and
`employee_login.php` silently coerces anything else to `'android'`:

```php
if (!in_array($platform, ['android', 'ios'], true)) { $platform = 'android'; }
```

Without the migration, web sessions would be **mislabelled as Android** rather
than failing loudly — which would corrupt the channel attribution FR-008
requires and make the shared-device report untrustworthy. `MODIFY` replaces an
enum definition wholesale, so omitting a value would invalidate existing rows;
all three are restated.

---

## R-011 — How the browser reports its origin, and why the server does not trust it

**Decision**: The attendance origin is derived **server-side** from the
authenticated session's platform (`web`), never from a field in the request body.

**Rationale**: the standing rule is that no client claim is a source of truth.
An origin taken from the body could be forged by a patched app to make an
app punch look like a web punch or vice versa, which would let an employee
launder a punch past whichever channel a company had restricted. Deriving it
from the session makes the claim unforgeable without stealing the session
itself.

---

## Open items deferred to `/speckit.tasks`

- Exact copy for the administrator-facing disclosure of what the web channel
  cannot verify (FR-014) — wording, both languages.
- Whether the shared-device flag surfaces as a column in the existing attendance
  review screen or as a separate report in `permedjat_central`.
- Playwright coverage boundary: geolocation and camera are mockable in Playwright,
  but a denied-permission path may need manual verification on a real device.
