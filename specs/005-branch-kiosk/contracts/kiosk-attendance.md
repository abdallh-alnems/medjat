# Contract — Identification and Attendance at the Kiosk

**Feature**: `005-branch-kiosk`

The punch itself is a two-step exchange, and the split is deliberate. The tablet
never learns who someone is until the server has decided, and the server never
records a punch that a person did not confirm.

```
  challenge  →  identify  →  [server decides]  →  punch
              (embedding)     (1:N + margin)    (idempotent)
```

The tablet sends an **embedding**, never a verdict. `matched: true` from a device
is meaningless here — a patched APK could forge it, and unlike the employee app
the kiosk can forge it *for anybody in the branch* (FR-008).

---

## POST `app/kiosk/challenge.php` *(new)*

Issue a single-use nonce and a liveness challenge before capture.

**Auth**: `X-Kiosk-Token`

**Request**: `{ "purpose": "punch" }`

**Success `200`**

```json
{
  "status": "success",
  "data": {
    "nonce": "…64 hex…",
    "challenge": "blink",
    "expires_in_seconds": 60
  }
}
```

Reuses `face_challenges`, whose `challenge` enum already holds
`blink · turn_left · turn_right · smile`. The row is written with
`employee_id = NULL` — unlike the selfie flow, at challenge time **nobody knows
who this is yet**. That nullability is the one change `face_challenges` needs.

`expires_at` is computed **in SQL** (`DATE_ADD(NOW(), INTERVAL 60 SECOND)`). PHP
runs UTC on this server and MySQL runs the tenant zone; a PHP-computed expiry
arrives already expired. This bit `face_selfie` once already.

---

## POST `app/kiosk/identify.php` *(new)*

The core of the feature. Resolve an unknown face against the branch roster.

**Auth**: `X-Kiosk-Token`

**Request**

```json
{
  "nonce": "…",
  "embedding": [0.0123, -0.4567, "… 192 floats …"],
  "model_version": "mobilefacenet_v1",
  "liveness_passed": true,
  "image": "data:image/jpeg;base64,…",
  "latitude": 30.0501,
  "longitude": 31.2299
}
```

**Success — identified `200`**

```json
{
  "status": "success",
  "data": {
    "outcome": "matched",
    "employee": { "id": 88, "name": "أحمد محمود", "photo_url": "…" },
    "next_action": "check_out",
    "current_state": { "checked_in_at": "2026-08-03T08:02:00+03:00" },
    "punch_ticket": "…64 hex…",
    "ticket_expires_in_seconds": 30
  }
}
```

**Success — not identified `200`**

```json
{
  "status": "success",
  "data": {
    "outcome": "ambiguous",
    "message_key": "kiosk.ambiguous",
    "code_fallback_available": true
  }
}
```

A failed identification is **`200`, not `4xx`**. It is a normal outcome of a
normal interaction, and the tablet must render it as guidance rather than as an
error. `message_key` resolves through the existing `I18n` layer so the kiosk
speaks the tenant's language.

### Server-side decision

1. Resolve and consume the nonce; reject a reused or expired one.
2. Reject when `model_version` ≠ `FaceMatchService::MODEL_VERSION`.
3. Load `face_embedding` for every **active, enrolled** employee whose branch is
   the station's branch. Roughly 200 × 192 floats — a linear scan, no index
   needed ([R-001](../research.md)).
4. Score all candidates with `FaceMatchService::similarity()`; keep the best and
   the runner-up.
5. Accept only when **both** hold (FR-044):
   - `best_score ≥ threshold` — `branches.station_match_threshold`, falling back
     to a system default. Starting point **0.55**, stricter than the 0.450 used
     for 1:1 selfie verification, because false-accept risk compounds across the
     roster.
   - `best_score − runner_up_score ≥ margin` — `branches.station_match_margin`,
     starting point **0.08**.
6. Check that the resolved employee's method resolution includes `kiosk`
   (FR-030); otherwise `wrong_method`.
7. Check `station_gps_radius_meters` when coordinates are supplied (FR-028).
8. Write `station_recognition_logs` **in every case**, including
   `runner_up_score` and `candidates_searched`.

| `outcome` | Meaning |
|---|---|
| `matched` | Threshold and margin both cleared |
| `ambiguous` | Threshold cleared, margin did not — two people scored too close |
| `no_match` | Nobody cleared the threshold |
| `liveness_failed` | Challenge not satisfied and `station_anti_spoofing_enabled = 1` |
| `out_of_branch` | Best match belongs to another branch |
| `wrong_method` | Identified, but `kiosk` is not among their resolved methods |
| `too_soon` | Within `min_seconds_between_punches` of their last punch |
| `out_of_range` | Tablet reported coordinates outside the branch radius |

**`log_only` mode** (`tenants.face_enforce_mode`) scores and records everything
but never refuses — the same tuning ramp `face_selfie` uses. In `log_only` a
below-threshold result still returns `matched` with `accepted = 0` recorded, so a
company can watch its own distribution before switching to `enforce`.

**`punch_ticket`** is a short-lived server-issued token naming the resolved
employee. It exists so the punch step does not have to trust a client-supplied
`employee_id` — the tablet could otherwise identify as one person and punch as
another.

---

## POST `app/kiosk/identify_by_code.php` *(new)*

The fallback path (User Story 4). Returns the same envelope as `identify.php`.

**Auth**: `X-Kiosk-Token`

**Request**: `{ "code": "4821" }`

Refused with `422` when `branches.station_code_fallback_enabled = 0` (FR-020).
Rate-limited per station through `RateLimiter`; crossing the threshold writes
`kiosk_pin_bruteforce` to `attendance_security_logs` and returns `429` (FR-019).

Compares against `employees.kiosk_pin_hash` scoped to the station's branch. On
success the resulting log row carries `method = 'code'`, which is what makes a
code-identified punch distinguishable in reporting (FR-011, User Story 4
scenario 4).

---

## POST `app/kiosk/punch.php` *(new)*

Record the attendance the employee just confirmed.

**Auth**: `X-Kiosk-Token`

**Request**

```json
{
  "punch_ticket": "…",
  "direction": "check_out",
  "idempotency_key": "3f2a…uuid…"
}
```

**Success `200`**

```json
{
  "status": "success",
  "data": {
    "attendance_id": 90210,
    "direction": "check_out",
    "recorded_at": "2026-08-03T17:04:00+03:00",
    "employee": { "id": 88, "name": "أحمد محمود" },
    "worked_minutes": 542
  }
}
```

**Writes**, through the existing `AttendanceModel` methods rather than a parallel
insert — otherwise `late_minutes`, `worked_minutes`, `overtime_minutes`, and
`status` would diverge between the kiosk and every other channel:

| Column | Value |
|---|---|
| `check_in_method` / `check_out_method` | `kiosk` |
| `recognition_method` | `station_face` — a surviving enum value, no schema change |
| `recognition_confidence` | The winning `match_score` |
| `station_id` | The station — a surviving column |
| `kiosk_idempotency_key` | From the request |

`recorded_at` is stamped through `TenantClock` in the tenant's zone, never from
the tablet's clock and never bare `NOW()`.

**Idempotency** (FR-027): `attendance.kiosk_idempotency_key` carries a unique
index. A retry after a lost response collides, and the handler returns the
**original** result with `200` rather than an error — from the employee's side a
retry is indistinguishable from a success, which is the point. This is the whole
of the offline story: there is no queue, only a safe retry ([R-012](../research.md)).

**Failure**

| Code | When |
|---|---|
| `410` | Ticket expired or already spent — the employee re-identifies, a 5-second cost |
| `409` | A punch of that direction already exists for the day through any channel |

---

## What is deliberately absent

- **No offline queue endpoint.** Identification requires the server, so nothing
  can be queued. The tablet blocks and says so (FR-024).
- **No employee-authenticated endpoint.** Nothing here accepts
  `X-Employee-Token`. An employee cannot reach the kiosk surface at all.
- **No client verdict field.** The request carries an embedding and a liveness
  boolean the server re-evaluates against its own challenge; it never carries a
  match decision.
