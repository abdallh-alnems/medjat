# Implementation Plan: Branch Kiosk — Shared Tablet Attendance

**Branch**: `005-branch-kiosk` | **Date**: 2026-08-03 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-branch-kiosk/spec.md`

## Summary

Put a shared tablet at the branch door so workers without smartphones can record
their own attendance. It is the largest functional gap against every competitor,
and Permedjat built it once already — the tables were dropped in 2026-06 but the
`branches.station_*` and `attendance.station_id` columns survive in production,
so this rebuilds on foundations rather than from nothing.

Three decisions from clarification shape the whole plan:

**The kiosk resolves identity from the face alone (1:N).** This is the expensive
one. `FaceMatchService` is built for 1:1 — verify one known person against one
threshold — and that design does not survive contact with a roster: at the 0.450
threshold it ships with, scanning 200 candidates gives roughly a one-in-three
chance of a wrong match somewhere. The plan therefore adds a **margin rule**
(the best candidate must beat the runner-up by a configurable gap) on top of a
stricter threshold, and records both scores on every attempt so the operating
point can be tuned on real data rather than on LFW figures.

**The server decides every identification, with no exceptions.** That closes a
direct contradiction the spec carried, and it costs the offline story entirely: a
kiosk that cannot reach the server records nothing. What it buys is that **no
biometric data exists at rest on a wall-mounted tablet** — no roster, no
embeddings, no captures. The employee app's Hive offline queue is not reused;
there is nothing to queue. What replaces it is a safe retry: an idempotency key
so a lost response cannot become a double punch.

**The tablet is a separate application, activated only by management.** Its own
Flutter project (`frontend/mobile/kiosk/`) with its own `applicationId`,
manifest, and release cadence, so the wakelock, boot receiver, and always-on
camera never reach the app employees install on personal phones.

The one thing it does **not** duplicate is the face pipeline. Both products send
embeddings the server compares against a single stored vector per employee, so
two copies of that code would eventually drift and silently stop matching
anybody. It lives in `frontend/mobile/shared/` and both apps depend on it.

Everything else is additive to code that already exists: enrollment writes the
same `employees.face_*` columns as `enroll_face.php`, punches route through
`AttendanceModel` so lateness and overtime cannot diverge between channels, and
fleet versioning is a third entry in `RemoteConfigService::APPS`.

## Technical Context

**Language/Version**: PHP 8.4 local (MAMP) / 8.5 live · Dart 3.11 / Flutter (GetX, MVVM) · TypeScript 5, React 19, Next.js 16 for the management web surface
**Primary Dependencies**: Existing `core/` services — `Auth`, `FaceMatchService`, `BiometricEnrollment`, `GpsService`, `TenantClock`, `PermissionMiddleware`, `TenantMiddleware`, `RateLimiter`, `RemoteConfigService`, `I18n`, `Response`. Kiosk app: `get`, `http`, `camera`, `google_mlkit_face_detection`, `flutter_secure_storage`, `connectivity_plus`, `device_info_plus`, plus `permedjat_shared` (path dependency) carrying `tflite_flutter` and `mobilefacenet.tflite` (5.2 MB, BSD-3). **No Firebase SDK on the tablet** — the version gate is a server-side heartbeat response
**Storage**: MySQL 8.4 (live) — four additive migrations, no drops or narrowing. Captures to `backend_medjet/uploads/kiosk/`, purged on a schedule
**Testing**: PHP — manual endpoint exercise against MAMP (no PHP test harness in the repo). Flutter — `flutter analyze lib`; kiosk flows verified on a physical Android tablet, since screen pinning and boot behaviour do not reproduce in an emulator
**Target Platform**: Android tablets (Android 10+), screen pinning for lockdown. iOS explicitly out of scope — the face pipeline would work unchanged on iPad, the lockdown would not
**Project Type**: Standalone Android app + a shared Flutter package + existing PHP REST backend + management surfaces in `permedjat_central` and `permedjat_central_web`
**Performance Goals**: SC-001 approach-to-confirmation under 10 s — dominated by camera warm-up and network round trip, not by matching. A 200-candidate 1:N scan is 200 × 192 float operations, microseconds; there is no throughput problem here
**Constraints**:
- No offline operation whatsoever — server-only identification (FR-024)
- No biometric data at rest on the tablet (FR-025)
- 1:N false-accept risk compounds with roster size; the margin rule and a roster ceiling are the mitigations (FR-044, FR-047)
- Captures must be downscaled aggressively — at the 2 MB enrollment cap, ten branches would generate ~34 GB/month
- No app store, so no automatic update path; raising the minimum version takes branches offline (FR-054)
- Fingerprint is impossible on tablet hardware — platform biometric APIs authenticate the device owner and return a boolean, and cannot enroll or identify a third party
**Scale/Scope**: Pre-launch (6 tenants / 16 employees). Design target: a few hundred employees per branch, one to three kiosks per branch. `station_recognition_logs` is the only table expected to grow quickly — every attempt, not only every punch

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is an **unfilled template** — no principles have
been ratified, so there are no constitution gates to evaluate. Rather than treat
that as a pass by default, this plan is gated against the project's real, written
and enforced rules in `CLAUDE.md`, which function as the de-facto constitution.

| Rule (CLAUDE.md) | Applies how | Status |
|---|---|---|
| **Writes require POST** (`Auth::requirePost`) | All 14 new endpoints are POST, including the read-only ones, for consistency with their neighbours | ✅ Planned |
| **Multi-tenant isolation** via `TenantMiddleware` | Every new table carries `tenant_id`; the kiosk token resolves to one tenant and one branch and can reach nothing else | ✅ Planned |
| **Permission gating must match the endpoint** | Three new permissions added to **both** `PERMISSIONS` and `ROLE_DEFAULTS`; frontend gates enumerated in [kiosk-admin.md](./contracts/kiosk-admin.md) | ✅ Planned — and fixes a pre-existing mismatch, [R-006](./research.md) |
| **Time is per tenant** — `TenantClock`, never `date()`/`NOW()`; expiry computed **in SQL** | Punch timestamps via `TenantClock`; all four code/challenge expiries via `DATE_ADD(NOW(), INTERVAL ? SECOND)` | ✅ Planned — [R-010](./research.md) |
| **Migrations**: new dated file, never edit an applied one, MySQL 8 has no `ADD COLUMN IF NOT EXISTS` | Four additive files; the one enum widening is a full `MODIFY COLUMN` re-statement | ✅ Planned — [data-model.md](./data-model.md) |
| **Never trust the client's verdict** | The tablet sends an embedding and a liveness flag; the server scores, applies threshold **and** margin, and issues a ticket naming the resolved employee so the punch cannot be re-attributed | ✅ Planned — [kiosk-attendance.md](./contracts/kiosk-attendance.md) |
| **`migrations/archive/` must never be run** | `2026_06_14_remove_kiosk_system.sql` stays archived; its unapplied half is what this feature builds on | ✅ Respected |
| **Run `check-drift.sh` before and after** | First and last steps of [quickstart.md](./quickstart.md) | ✅ Planned |
| **Arabic-first RTL, IBM Plex Sans Arabic + Geist** | Kiosk locks to RTL and Arabic with its own theme sized for a wall-mounted tablet (72dp targets, 48px name); refusal text returns a `message_key` resolved through `I18n`, never a rendered English string | ✅ Planned |
| **Payroll consistency** | Kiosk punches route through existing `AttendanceModel` methods so `late_minutes` / `worked_minutes` / `overtime_minutes` cannot diverge by channel | ✅ Planned — [R-011](./research.md) |

**No deviations require justification.** Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/005-branch-kiosk/
├── plan.md              # This file
├── research.md          # Phase 0 — 12 findings, all verified against the code
├── data-model.md        # Phase 1 — 4 new tables, 6 new columns, 2 widened enums
├── quickstart.md        # Phase 1 — build, verify, deploy
├── contracts/
│   ├── kiosk-pairing.md     # Device identity: pair, heartbeat, list, revoke
│   ├── kiosk-attendance.md  # challenge → identify → punch
│   └── kiosk-admin.md       # Access codes, enrollment, evidence, gating
├── checklists/
│   └── requirements.md  # Spec quality — 16/16
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created here)
```

### Source Code (repository root)

```text
backend_medjet/
├── app/kiosk/                          # NEW module — 14 endpoints
│   ├── create_pairing_code.php         # kiosk_devices
│   ├── pair.php                        # unauthenticated; the code is the credential
│   ├── heartbeat.php                   # X-Kiosk-Token; revocation + version gate
│   ├── list.php  revoke.php            # kiosk_devices
│   ├── create_access_code.php          # kiosk_access
│   ├── open_admin.php                  # X-Kiosk-Token + code
│   ├── challenge.php                   # nonce + liveness challenge
│   ├── identify.php                    # 1:N — the core
│   ├── identify_by_code.php            # fallback
│   ├── punch.php                       # idempotent write
│   ├── set_pin.php                     # manage_employees
│   ├── recognition_logs.php            # manage_attendance; tuning distribution
│   ├── capture.php                     # kiosk_evidence; audited
│   └── admin/roster.php  admin/enroll.php  admin/close.php
├── core/
│   ├── Auth.php                        # + authenticateKiosk()
│   ├── KioskIdentifier.php             # NEW — 1:N scan, threshold + margin
│   ├── KioskPairing.php                # NEW — code issue/redeem, atomic consume
│   ├── FaceMatchService.php            # reused unchanged (similarity, parseEmbedding)
│   ├── BiometricEnrollment.php         # reused for enrollment photos
│   ├── PermissionMiddleware.php        # + 3 kiosk permissions (+ fix biometric_*)
│   ├── AttendanceMethodResolver.php    # + 'kiosk' in ALLOWED
│   └── RemoteConfigService.php         # + permedjat_kiosk app entry
├── models/
│   ├── KioskStationModel.php           # NEW
│   ├── KioskTokenModel.php             # NEW
│   └── StationRecognitionLogModel.php  # NEW
├── app/cron/purge_kiosk_captures.php   # NEW — enforces FR-056
├── migrations/2026_08_03_kiosk_*.sql   # 4 additive files
├── lang/{ar,en}.php                    # kiosk message keys
└── uploads/kiosk/                      # captures, purged on schedule

frontend/mobile/shared/                # NEW package — the one shared thing
├── pubspec.yaml                        # publish_to: none, path-depended
├── lib/permedjat_shared.dart              # barrel
├── lib/src/face/face_embedder.dart     # MOVED out of permedjat_app
├── lib/src/face/face_liveness.dart     # MOVED out of permedjat_app
└── assets/models/mobilefacenet.tflite  # MOVED — one copy, 5.2 MB

frontend/mobile/kiosk/                 # NEW standalone Flutter app (Android)
├── lib/main.dart                       # portrait, RTL, immersive
├── lib/core/api/kiosk_api.dart         # the only endpoints a kiosk may call
├── lib/core/network/{kiosk_crud,kiosk_result}.dart   # X-Kiosk-Token, POST-only
├── lib/core/storage/kiosk_token_store.dart           # the ONLY thing persisted
├── lib/core/theme/kiosk_theme.dart     # read at 1–3 m, 72dp targets
├── lib/view/       identify · confirm · admin · offline · update_required
├── lib/logic/      kiosk_controller · enrollment_controller
└── android/app/src/main/
    ├── AndroidManifest.xml             # WAKE_LOCK, BOOT_COMPLETED, camera, HOME
    └── kotlin/.../KioskBootReceiver.kt # returns after a power cut

frontend/mobile/employee/                   # employee app — now depends on permedjat_shared
frontend/mobile/manager/               # management: kiosk tab on a branch
frontend/web/manager/           # same surfaces on the web port
```

**Structure Decision**: Three Flutter projects, not two and not one.
`permedjat_kiosk` is a **standalone application** — its own project, package name,
manifest, signing key, and release cadence. It is not a flavor of the employee
app and not a mode inside it.

What it does not do is copy the face pipeline. The employee app and the kiosk
both extract embeddings and send them to a backend that compares them against
one column (`employees.face_embedding`). Two copies of `face_embedder.dart`
would eventually diverge — a model swap applied to one, a changed crop margin,
a different tflite version — and the failure mode is silent: the server keeps
comparing, and simply stops recognising people. `permedjat_shared` makes that class
of bug structurally impossible, and `permedjat_app` was migrated onto it as part of
this work (verified with `flutter analyze lib`).

The kiosk carries **no Firebase SDK**. The version gate and maintenance switch
are enforced server-side — the tablet reports its version on every heartbeat and
the backend answers `426`/`503` after reading Remote Config itself. That removes
a google-services.json step and an FCM dependency from a device that heartbeats
anyway.

> **Revised 2026-08-15.** The gate is still exactly as described — the server
> alone decides, and nothing on the tablet overrides it — but the Firebase SDK
> is now on the kiosk for a reason this section did not weigh: a wall-mounted
> tablet that crashes reports it to nobody. Crashlytics answers that; Analytics
> counts branch-level outcomes; FCM (`maintenance_permedjat_kiosk`) and Remote
> Config's realtime stream only make the tablet re-ask the server at once
> instead of waiting out its two-minute heartbeat. All of it is initialised
> after the first frame and bounded by a timeout, so a tablet with no Play
> services behaves as this plan originally assumed.

The backend gets a new `app/kiosk/` module because a kiosk is a third
authentication principal, not a variation on the existing two.

## Phase Status

| Phase | Output | Status |
|---|---|---|
| 0 — Research | [research.md](./research.md) | ✅ Complete — 12 findings, no unresolved NEEDS CLARIFICATION |
| 1 — Data model | [data-model.md](./data-model.md) | ✅ Complete |
| 1 — Contracts | [contracts/](./contracts/) | ✅ Complete — 3 files, 14 endpoints |
| 1 — Quickstart | [quickstart.md](./quickstart.md) | ✅ Complete |
| 1 — Agent context | `CLAUDE.md` | ✅ Updated |
| 2 — Tasks | `tasks.md` | ⬜ Not started — run `/speckit.tasks` |

## Risks carried into implementation

These are not open questions — they are decisions whose cost lands during
implementation, recorded so nobody rediscovers them in week three.

1. **The 1:N operating point is unproven.** Every threshold in this plan (0.55 /
   0.08) is a starting point derived from LFW pairs, not from a branch. SC-013
   asks for fewer than 1 in 1,000 mis-attributions and cannot be confirmed until
   `station_recognition_logs` holds real rows. Ship every tenant in `log_only`
   and tune before enforcing. If the margin rule proves insufficient at realistic
   roster sizes, the honest fallback is a roster ceiling (FR-047) — the design
   supports it, and it is preferable to attributing punches to the wrong person.
2. **No offline means no offline.** A branch with unreliable internet loses
   attendance recording for the duration and falls back to manual entry. This is
   a deliberate trade for keeping biometrics off the tablet, and it should be
   said out loud to a customer before they buy a kiosk as their only method.
3. **Blocking an outdated kiosk is not updating it.** With no store, raising the
   minimum version takes those branches offline until someone physically installs
   the new build. FR-054 makes the blast radius visible first; that is mitigation,
   not a fix. Revisit store distribution once more than a handful of branches are
   live.
4. **`attendance_security_logs.employee_id` is `NOT NULL`.** Kiosk refusals that
   identify nobody cannot be written there. FR-034 is satisfied by
   `station_recognition_logs` plus mirrored rows for refusals that do resolve to
   an employee — do not "fix" this by making the column nullable, which would
   weaken an existing FK for a different channel's convenience.
5. **`PermissionMiddleware::PERMISSIONS` and `ROLE_DEFAULTS` already disagree**
   (`biometric_enroll` / `biometric_delete` are granted but not declared). Adding
   the three kiosk permissions to only one of the two repeats exactly the class of
   bug that surfaces to users as "an error occurred".

## Complexity Tracking

> No Constitution Check violations. This section is intentionally empty.
