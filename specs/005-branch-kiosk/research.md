# Phase 0 Research: Branch Kiosk

**Feature**: [spec.md](./spec.md) · **Date**: 2026-08-03

Every finding below was verified against the code and the generated `schema.sql`
in this repository, not recalled. Line references are to files as they stand on
2026-08-03.

---

## R-001 — One-to-many identification is cheap to compute and expensive to get right

**Decision**: Implement 1:N as a linear cosine scan over the branch's enrolled
embeddings, in PHP, on the server. Accept a match only when it clears **both** an
absolute threshold and a **margin** over the runner-up.

**Rationale**: The cost objection does not exist. `employees.face_embedding` is a
`blob` (schema.sql:966) holding 192 float32 values
(`FaceMatchService::ALLOWED_DIMS = [128, 192, 512]`, `MODEL_VERSION =
'mobilefacenet_v1'`). A 200-employee branch is 200 × 192 multiply-adds per
identification — microseconds. There is no need for a vector index, an extension,
or a separate service.

The real cost is statistical. `FaceMatchService::similarity()` already computes
cosine similarity and `verify()` compares it to one threshold. That is sufficient
for 1:1 and **insufficient for 1:N**: at a per-comparison false-accept rate of
*p*, scanning *N* candidates gives roughly `1 − (1 − p)^N`. The measured figures
in `frontend/mobile/shared/assets/models/README.md` (800 LFW pairs) give:

| Threshold | FAR (per comparison) | FRR | Implied FAR across 40 | across 200 |
|---|---|---|---|---|
| 0.30 | 4.2% | 6.5% | 82% | ~100% |
| 0.40 | 0.8% | 16% | 27% | 80% |
| 0.45 | 0.2% | 19% | 7.7% | 33% |

`FaceMatchService::DEFAULT_THRESHOLD` is **0.450** — chosen for 1:1 and unsafe
for 1:N at any realistic branch size. Raising the threshold alone trades the
problem for an unusable rejection rate.

**The margin rule is what makes 1:N viable.** Requiring `best − second_best ≥
margin` filters exactly the failure mode that matters: a capture that resembles
several enrolled people. A capture that is genuinely one person scores far from
everyone else and passes; an ambiguous capture is refused and falls through to the
personal code rather than being silently assigned to the wrong employee.

**Starting operating point**: threshold **0.55**, margin **0.08**, `log_only`
mode. These are starting points for tuning, not answers — SC-013 (fewer than 1 in
1,000 mis-attributions) can only be confirmed against a tenant's own data through
`station_recognition_logs`, exactly as `face_selfie` was tuned through
`face_verification_logs`.

**Alternatives considered**: a vector database or FAISS-style index (rejected —
solves a performance problem this feature does not have); top-1 with threshold
only (rejected — this is the design that produces the 33% figure above);
re-ranking with a second model (rejected — no second model exists in the repo).

**Open for measurement, not for design**: the supported roster ceiling (FR-047).
LFW is harsher than a deliberate, well-lit kiosk capture, so the real numbers will
be better than the table — but the shape of the curve does not change.

---

## R-002 — Enrollment data already exists in the right shape

**Decision**: Reuse `employees.face_embedding` and the surrounding columns
unchanged. Kiosk enrollment writes the same columns as
`app/biometric/enroll_face.php`.

**Rationale**: `employees` already carries `face_embedding` (blob),
`face_photo_url`, `face_model_version`, `face_embedding_dim`, `face_enrolled_at`,
`face_quality_score` (schema.sql:966–975). `BiometricEnrollment::MIN_QUALITY_SCORE
= 0.5` and `storeReferencePhoto()` already handle the photo side with a 2 MB cap.
An enrollment captured at a kiosk is therefore **the same enrollment** a selfie
punch would use — satisfying the spec assumption without a parallel store.

The only additions needed are provenance (FR-041): which kiosk performed the
enrollment, which administrator authorised it, and — because re-enrollment must be
an auditable replacement rather than a silent overwrite — a record of what was
replaced.

---

## R-003 — The kiosk needs a third authentication principal

**Decision**: Mirror the employee token pattern. A `kiosk_auth_tokens` table
holding `token_hash`, presented by the tablet in an `X-Kiosk-Token` header and
resolved by a new `Auth::authenticateKiosk()`.

**Rationale**: `core/Auth.php` currently knows two principals — an administrator
via Firebase ID token (`X-Firebase-Token`, `authenticateUser`, Auth.php:25) and an
employee via opaque token (`X-Employee-Token`, `authenticateEmployee`,
Auth.php:87, resolved through `EmployeeAuthTokenModel::findActiveByPlain`). A
kiosk is neither: it acts for a **branch**, not a person.

`employee_auth_tokens` (schema.sql:685) is the right template — `token_hash`
unique, `device_id`, `platform`, `app_version`, `last_used_at`, `revoked_at`,
`revoke_reason`. Revocation is already modelled as a nullable timestamp rather
than a delete, which is exactly what FR-005 needs.

`attendance_devices` (schema.sql:267) is the second precedent, and the closer one
conceptually: `status enum('unclaimed','active','disabled')`, `last_seen_at`,
`last_ip`, `claimed_by`, `claimed_at`, `branch_id`. The new `attendance_stations`
table should look like `attendance_devices` with a token instead of a serial
number.

**Alternatives considered**: reusing an employee token for the tablet (rejected —
the spec's central trust argument); Firebase anonymous auth per device (rejected —
adds a dependency and an offline failure mode for no gain); a static per-branch
secret in the app (rejected — unrevocable).

---

## R-004 — Only three of the six surviving `station_*` columns are usable

**Decision**: Reuse `station_enabled`, `station_gps_radius_meters`, and
`station_anti_spoofing_enabled`. Add two new columns. Leave the other three in
place, unused, per the additive-only rule.

**Rationale**: Verified against `branches` in schema.sql:

| Column | Verdict |
|---|---|
| `station_enabled tinyint(1)` | **Reuse** — exactly FR-029 |
| `station_gps_radius_meters int DEFAULT 30` | **Reuse** — exactly FR-028 |
| `station_anti_spoofing_enabled tinyint(1) DEFAULT 1` | **Reuse** — R-010 |
| `station_confidence_threshold decimal(3,2)` | **Cannot reuse** — two decimal places. Every other threshold in the system is `decimal(4,3)` (`tenants.face_match_threshold`, `branches.face_match_threshold`, `face_verification_logs.threshold`). A 1:N operating point needs the third digit |
| `station_methods enum('face_only','fingerprint_only','both_available')` | **Cannot reuse** — the fingerprint values assume hardware a tablet does not have. Platform biometric APIs (Android `BiometricPrompt`, iOS `LocalAuthentication`) authenticate the *device owner* and return a boolean; they cannot enroll or identify a third party. Fingerprint at a kiosk would require an external reader with a vendor SDK, which is out of scope. The archived migration flagged this in 2026-06 and it is still true |
| `station_admin_pin_hash varchar(255)` | **Cannot reuse** — built for a static per-branch PIN. FR-036/FR-037 chose a single-use code generated in the management app, which is strictly stronger. Left in place and unused |

**New columns**: `station_match_threshold decimal(4,3)` and
`station_match_margin decimal(4,3)`, both nullable so they fall back to a system
default. Note that `tenants.face_match_threshold` still carries a column default
of **0.650** while `FaceMatchService::DEFAULT_THRESHOLD` is **0.450** — existing
tenant rows hold 0.650. Do not assume the constant reflects stored data.

---

## R-005 — `face_verification_logs` cannot absorb kiosk attempts

**Decision**: Rebuild `station_recognition_logs` as a separate table rather than
extending `face_verification_logs`.

**Rationale**: Two structural blockers, both verified in schema.sql:1021.

1. `employee_id int unsigned NOT NULL`. A 1:N attempt that matches nobody — the
   single most important row this feature must record (FR-013) — has no employee.
2. `result enum('matched','below_threshold','liveness_failed','not_enrolled',
   'invalid_challenge','bad_embedding','model_mismatch')` has no value for the 1:N
   outcomes: *ambiguous* (margin rule failed), *no_match*, or *out_of_branch*.

Widening the enum and making `employee_id` nullable would degrade a table that
`app/attendance/face_logs.php` already reads for threshold tuning. A separate
table also matches the spec's distinct **Identification Attempt** entity and
restores a name the removed system already used, which keeps
`attendance.recognition_method`'s surviving `station_*` values coherent.

`attendance_security_logs` (schema.sql) has the same `employee_id NOT NULL`
constraint plus a `reason` enum that stops at
`'no_local_biometric'` — it needs new values for kiosk refusals (FR-034), and
those must be added by re-stating the full enum, since MySQL 8 has no additive
enum syntax.

---

## R-006 — The permission constant is already incomplete; do not copy the bug

**Decision**: Add `kiosk_devices`, `kiosk_access`, and `kiosk_evidence` to
`PermissionMiddleware::PERMISSIONS` **and** to the relevant `ROLE_DEFAULTS`, and
fix the pre-existing omission while there.

**Rationale**: `core/PermissionMiddleware.php:4` defines `PERMISSIONS` as a
20-entry list that does **not** include `biometric_enroll` or `biometric_delete` —
yet `ROLE_DEFAULTS` (line 29–31) grants both to `hr`, `branch_manager`, and
`attendance`. The canonical list and the role defaults already disagree. Adding
three kiosk permissions to only one of the two would repeat exactly the mismatch
that surfaces to users as a generic "an error occurred".

**Proposed role defaults**:

| Role | `kiosk_devices` | `kiosk_access` | `kiosk_evidence` |
|---|---|---|---|
| `general_manager` | ✅ (`*`) | ✅ | ✅ |
| `hr` | ✅ | ✅ | ✅ |
| `branch_manager` | — | ✅ | ✅ |
| `attendance` | — | ✅ | — |
| `viewer` | — | — | — |

A branch manager runs the kiosk daily but does not pair or unpair hardware; an
attendance clerk enrolls faces but does not browse colleagues' stored captures.

---

## R-007 — Fleet versioning rides the existing Remote Config mechanism

**Decision**: Register the kiosk as a third app in
`RemoteConfigService::APPS` with `medjat_kiosk_min_version` and
`medjat_kiosk_maintenance_enabled`.

**Rationale**: `core/RemoteConfigService.php:10` hardcodes a two-app list
(`permedjat_app`, `permedjat_central`), each with `min_version_key`, `maintenance_key`,
and `supports_maintenance`. Adding a third entry plus the two Remote Config
parameters is the whole change; `app/admin_app_control/{get,set}.php` then covers
the kiosk without new endpoints.

**The gap this does not close**: on the store-distributed apps, "update required"
sends the user to a store. A directly-installed kiosk has no store, so raising the
minimum version **takes those branches offline** until someone installs the new
build. This is why FR-054 requires the blast radius to be visible before the
minimum takes effect — the kiosk list must show each device's version, and the
management app must be able to answer "which tablets would this break" first.

---

## R-008 — Capture retention needs a purge job, and the volume is real

**Decision**: Store captures under `uploads/attendance/kiosk/`, record the path on
the punch, and purge with a new `app/cron/purge_kiosk_captures.php` added to
`/etc/cron.d/permedjat`.

**Rationale**: `uploads/` already contains `attendance`, `documents`, `letters`,
`payslips`, `signatures`, and `FaceMatchService::storeAuditSelfie()` (line 277)
plus `BiometricEnrollment::storeReferencePhoto()` establish the write pattern and
the 2 MB cap. `app/cron/` holds `catchup_absences.php` and `run_alerts.php`, so a
third scheduled job is a known shape.

Volume: a 40-person branch punching twice daily produces roughly 1,700 images a
month; ten branches, 17,000. At the enrollment cap of 2 MB that is 34 GB/month —
untenable. Kiosk captures are evidence, not enrollment references, and must be
downscaled aggressively (long edge ≈ 640 px, JPEG quality ≈ 70, target < 80 KB).
FR-056 requires deletion to remove the file, not only the row, so the purge must
unlink before deleting.

---

## R-009 — A standalone project, with exactly one shared package

**Decision**: Ship the kiosk as its own Flutter project,
`frontend/mobile/kiosk/`, with its own `applicationId`
(`com.khawarizmie.medjat.kiosk`), manifest, signing key, and release cadence.
Share **only** the face pipeline, through a new `frontend/mobile/shared/`
package that both apps depend on by path.

**Rationale**: Two products, two release trains, two permission sets — that is a
separate application, and a build flavor of the employee app would have coupled
their versions and their store presence for no benefit the kiosk actually needs.

But copying the face pipeline into the second project would have been the wrong
kind of independence. `face_embedder.dart` loads `mobilefacenet.tflite`, crops
with a 20% margin, resizes to 112×112, normalises to [-1, 1], and L2-normalises
the 192-float result. Every one of those steps has to match on both products,
because the server compares whatever arrives against **one** stored vector per
employee (`employees.face_embedding`). If a model swap or a changed crop reached
one app and not the other, the server would keep comparing and simply stop
recognising people — no exception, no log line, no obvious cause. Extracting the
pipeline into a package makes that impossible rather than merely unlikely.

**What moved**: `face_embedder.dart`, `face_liveness.dart`, and
`assets/models/mobilefacenet.tflite` left `permedjat_app` for `permedjat_shared`, and
`permedjat_app` now depends on the package. The one code change the move required
is the asset key — a package's assets are addressed as
`packages/permedjat_shared/assets/models/mobilefacenet.tflite`, and dropping the
prefix loads nothing. `permedjat_app` was re-analysed clean after the migration.

**What is deliberately not shared**: the `CRUD` layer (the kiosk sends
`X-Kiosk-Token`, the employee app sends `X-Employee-Token`, and the employee
app's session-expiry handling is meaningless on a shared tablet), the theme (a
kiosk is read from one to three metres away with 72dp touch targets), routing,
and the employee app's Hive offline queue, which the kiosk has no use for.

**No Firebase on the tablet.** The version gate and maintenance switch are
enforced server-side: the kiosk reports its version on every heartbeat and the
backend answers `426`/`503` after reading Remote Config itself. Putting the SDK
on the device would add a `google-services.json` step and an FCM dependency to
buy nothing the heartbeat does not already deliver.

> **Superseded 2026-08-15** — see plan.md. The reasoning above holds for the
> *gate*, and the gate is unchanged. What it missed is observability: a kiosk
> crashes to a wall. Firebase is now on the tablet for Crashlytics first, with
> Analytics, FCM and Remote Config alongside it, none of which decide anything
> the server has not already answered.

**Lockdown**: Android screen pinning (lock task), plus an optional HOME intent
filter so a supervisor can make the kiosk the device's launcher. Deliberately
**not** `DEVICE_ADMIN`, which attracts Play policy scrutiny for no gain here.
Jibble documents the same screen-pinning approach. Start-on-boot is a
`BOOT_COMPLETED` receiver; screen-awake is a wakelock held while the kiosk screen
is foreground.

**Not in scope**: iOS. The face pipeline itself would work unchanged on iPad —
`camera`, `google_mlkit_face_detection`, and `tflite_flutter` are all
cross-platform and `NSCameraUsageDescription` is already declared — but iOS offers
no equivalent to lock task without Guided Access configured by hand on each device
or an MDM subscription. The blocker is the lockdown, not the biometrics.

---

## R-010 — Liveness matters more here than on a personal phone

**Decision**: Require the existing liveness challenge at the kiosk, gated by
`branches.station_anti_spoofing_enabled` (default 1).

**Rationale**: The `face_challenges` table (schema.sql:1004) already issues a
single-use nonce with a `challenge enum('blink','turn_left','turn_right','smile')`
and a `purpose enum('check_in','check_out','enroll')` — the enrollment purpose is
already there, which kiosk-side enrollment needs.

The threat model is worse than the phone case. On a personal phone the attacker
holds a photo of *themselves* to their own device, which gains nothing. At an
unattended shared tablet, holding up a colleague's photograph is the obvious
attack, and with 1:N there is no declared identity to contradict it. Liveness is
the primary defence and a stored capture (FR-055) is the audit trail.

**One correction to carry forward**: `face_challenges.expires_at` is a `datetime`,
and the project's standing gotcha applies — PHP runs UTC on the server while MySQL
runs Africa/Cairo, so a PHP-computed expiry is born expired. Compute it in SQL
(`DATE_ADD(NOW(), INTERVAL ? SECOND)`), as `face_selfie` had to.

---

## R-011 — Time, tenancy, and the surviving attendance columns

**Decision**: Stamp every kiosk punch through `TenantClock`; write
`attendance.station_id`, `recognition_method`, and `recognition_confidence`
unchanged.

**Rationale**: `attendance.recognition_method` already carries `station_face`,
`station_fingerprint`, `station_both`, and `station_qr` (schema.sql:238), and
`station_id` and `recognition_confidence` sit beside it. Of those enum values only
`station_face` is used by this feature; the rest stay as historical values.
`AttendanceModel` writes `late_minutes`, `status`, `worked_minutes` and the rest,
so kiosk punches should route through the same model methods rather than a
parallel insert — otherwise lateness and overtime silently diverge between
channels.

`AttendanceMethodResolver::ALLOWED` (line 22) currently reads
`['qr_gps','gps_only','face_selfie','wifi_gps','device','manual']`. Adding
`'kiosk'` makes the kiosk assignable per employee, category, branch, or tenant
(FR-030) through machinery that already exists.

---

## R-012 — What the tablet does when it cannot reach the server

**Decision**: A blocking, explicit offline state. No queue, no local roster, no
local decision.

**Rationale**: This falls directly out of the clarification that server evaluation
is absolute. The consequence is that `permedjat_app`'s Hive-backed offline attendance
queue is **not** reused — there is nothing to queue, because identification cannot
happen without the server and a punch cannot exist without an identification.

The one case that still needs care is a request sent whose response was lost
(FR-027). The kiosk must send an idempotency key with each punch and, on
reconnect, resolve the outcome against that key so the punch exists exactly once.
`attendance` has a natural uniqueness per employee per date, which makes the
server side of this straightforward.

Detecting a dark kiosk (FR-048) reuses `last_seen_at` on the station row — the
same signal `attendance_devices.last_seen_at` provides for terminals — evaluated
by the existing alerting cron rather than a new mechanism.
