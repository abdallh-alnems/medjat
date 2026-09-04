# Branch Kiosk — operator notes

A shared tablet at a branch door so employees without smartphones can record
their own attendance. Spec: `specs/005-branch-kiosk/`.

The kiosk is a **third authentication principal**. An administrator authenticates
as a person (Firebase token), an employee as themselves (`X-Employee-Token`), and
a kiosk as a **branch** (`X-Kiosk-Token`). A kiosk credential can produce
attendance for anyone enrolled at its branch — which is why it is bound to one
branch, revocable, hashed at rest, and why `Auth::authenticateKiosk()`
deliberately returns no `employee_id`.

---

## The one thing to get right: the operating point

Everything else here follows a pattern that already exists somewhere in this
codebase. One-to-many identification does not.

`FaceMatchService::verify()` answers *"is this Ahmed?"* — one known person, one
threshold, currently **0.450**. A kiosk answers *"who is this?"* against the whole
branch roster, and that is not the same problem with a loop around it. False
accepts compound: at a per-comparison false-accept rate of *p*, scanning *N*
candidates gives roughly `1 − (1−p)^N`.

Measured on 800 LFW pairs (`frontend/mobile/shared/assets/models/README.md`):

| Threshold | FAR per comparison | FRR | Implied FAR across 40 | across 200 |
|---|---|---|---|---|
| 0.30 | 4.2% | 6.5% | 82% | ~100% |
| 0.40 | 0.8% | 16% | 27% | 80% |
| 0.45 | 0.2% | 19% | 7.7% | **33%** |

At the threshold the 1:1 path ships with, a 200-person branch is about a
one-in-three chance of attributing a punch to the wrong person. Raising the
threshold alone trades that for a rejection rate nobody will tolerate.

### What actually makes it safe: the margin rule

A match is accepted only when the best candidate **clears the threshold** *and*
**beats the runner-up by a margin**. That filters precisely the failure mode that
matters — a capture resembling several enrolled people — and lets an ambiguous
capture fall through to the personal code instead of being assigned to whoever
scored a fraction higher.

Verified with synthetic near-twins; the numbers below are real output:

| Separation between two enrolled people | best | runner-up | gap | outcome |
|---|---|---|---|---|
| 0.10 | 0.999 | 0.998 | 0.001 | `ambiguous` |
| 0.20 | 0.994 | 0.991 | 0.003 | `ambiguous` |
| 0.45 | 0.960 | 0.925 | 0.035 | `ambiguous` |

With the margin disabled, every one of those returns `matched` and the winner is
decided by a difference of 0.001. That is noise, not identification.

### Starting values — hypotheses, not answers

```
KioskIdentifier::DEFAULT_THRESHOLD = 0.550
KioskIdentifier::DEFAULT_MARGIN    = 0.080
KioskIdentifier::ROSTER_WARN_ABOVE = 150
```

These are derived from LFW pairs, **not from anybody's branch**. LFW is harsher
than a deliberate, well-lit kiosk capture, so real numbers should be better — but
the shape of the curve does not change.

---

## Tuning procedure

Ship every tenant in `log_only` (`tenants.face_enforce_mode`, the default).
Scores are recorded and nobody is refused.

1. Let a branch run for a few thousand attempts. Fewer than that and you are
   tuning on noise.

2. Read the distribution:

   ```bash
   curl -s -X POST .../app/kiosk/recognition_logs.php \
     -H "X-Firebase-Token: $TOKEN" \
     -d '{"branch_id":3,"view":"distribution"}'
   ```

3. Genuine matches should cluster high and everything else low. Set
   `branches.station_match_threshold` where they stop overlapping, and
   `station_match_margin` from the observed gap between best and runner-up on
   attempts you know were correct.

4. Only then switch that tenant to `enforce`.

**Do not carry the 1:1 numbers over.** And note that
`tenants.face_match_threshold` still has a column default of **0.650** while
`FaceMatchService::DEFAULT_THRESHOLD` is **0.450** — existing tenant rows hold
0.650 regardless of what the constant says. Read the data, not the constant.

### If the margin rule is not enough

At some roster size no threshold holds the target rate. The answer is the roster
ceiling (`ROSTER_WARN_ABOVE`, surfaced by `list.php` as `over_ceiling`), **not a
looser margin**. A branch past the ceiling should lean on the personal code.

---

## Operational notes

**No offline operation, at all.** Identification requires the server, so a kiosk
that cannot reach it records nothing and says so. The trade is that **no
biometric data exists at rest on the tablet** — a stolen wall-mounted device
carries no face templates for anybody. The two cannot be separated.

**Raising `medjat_kiosk_min_version` takes branches offline.** The store apps can
send a user to a store; a directly-installed kiosk has nowhere to be sent, so
somebody must physically visit each tablet. Check the blast radius first:

```bash
curl -s -X POST .../app/kiosk/list.php -H "X-Firebase-Token: $TOKEN" -d '{}'
# every station with below_min_version:true stops working
```

**The version gate fails open.** `RemoteConfigService::gateFor()` caches for five
minutes and falls back to the last known-good value. A Firebase outage must never
stop every kiosk in every company from recording attendance.

**Captures expire.** `app/cron/purge_kiosk_captures.php` must be in
`/etc/cron.d/permedjat`. Without it, images accumulate indefinitely — roughly 1,700
a month for a 40-person branch — and the retention promise in the spec is unmet.

---

## Surviving columns from the removed 2026-06 station system

Reused as-is: `branches.station_enabled`, `station_gps_radius_meters`,
`station_anti_spoofing_enabled`, `attendance.station_id`,
`attendance.recognition_confidence`, `'kiosk'` in the check-in/check-out method
enums, and `'station_face'` in `recognition_method`.

Present but deliberately unused:

| Column | Why not |
|---|---|
| `station_confidence_threshold` | `decimal(3,2)` — two decimal places; a 1:N operating point needs three |
| `station_methods` | Its fingerprint values assume hardware a tablet does not have. Platform biometric APIs authenticate the *device owner* and return a boolean; they cannot enrol or identify a third party |
| `station_admin_pin_hash` | Built for a static per-branch PIN. Superseded by `kiosk_codes` — a static PIN is shared once and then works forever |
| `attendance.kiosk_idempotency_key` | Replaced by separate check-in / check-out keys; one column let the check-out overwrite the check-in's key |
