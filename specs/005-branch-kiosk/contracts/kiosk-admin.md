# Contract — Kiosk Administration, Enrollment, and Evidence

**Feature**: `005-branch-kiosk`

Everything reachable only through the kiosk's administration area, plus the
management-side surfaces that govern it. The administration area is the highest-
privilege surface on the tablet: it enrolls faces and releases kiosk mode, so it
opens only against a code that an administrator generated seconds earlier
(FR-036, FR-037).

---

## POST `app/kiosk/create_access_code.php` *(new)*

**Auth**: `X-Firebase-Token` · **Permission**: `kiosk_access`

**Request**: `{ "station_id": 12 }`

**Success `200`**

```json
{
  "status": "success",
  "data": { "code": "482913", "expires_at": "2026-08-03T14:36:00+03:00" }
}
```

Six digits, five-minute life, single use. Short because a supervisor reads it off
a phone and types it on a tablet; safe because it is single-use and expires
before it can be written down and reused. Stored as SHA-256 in `kiosk_codes` with
`purpose = 'access'`.

Deliberately a **different permission** from `kiosk_devices`. Generating an access
code is a daily task for a branch manager; pairing and unpairing hardware is not
(FR-060, [R-006](../research.md)).

---

## POST `app/kiosk/open_admin.php` *(new)*

The tablet redeems the code to open its administration area.

**Auth**: `X-Kiosk-Token`

**Request**: `{ "code": "482913" }`

**Success `200`**

```json
{
  "status": "success",
  "data": {
    "admin_session": "…64 hex…",
    "expires_in_seconds": 600,
    "authorised_by": { "id": 5, "name": "منى سعيد" }
  }
}
```

`admin_session` is a separate short-lived token required by every endpoint below.
Ten minutes, refreshed by activity, so a supervisor enrolling thirty people is not
interrupted — but an administration area abandoned mid-session closes itself
(FR-038, User Story 2 scenario 8). An enrollment screen left open on a wall is a
self-enrollment machine.

`authorised_by` is carried through to `kiosk_codes.created_by` and lands on every
enrollment performed in the session (FR-041) — the audit trail names the
administrator who authorised it, not the tablet.

Consumption is the same atomic guarded `UPDATE` used for pairing codes. Unknown,
expired, and spent all return `410` with one message.

---

## POST `app/kiosk/admin/roster.php` *(new)*

Who can be enrolled at this tablet.

**Auth**: `X-Kiosk-Token` + `X-Kiosk-Admin-Session`

**Success `200`**

```json
{
  "status": "success",
  "data": {
    "employees": [
      { "id": 88, "name": "أحمد محمود", "job_title": "فني", "face_enrolled": true,  "enrolled_at": "2026-08-03T09:14:00+03:00" },
      { "id": 91, "name": "سعاد علي",   "job_title": "مشرفة", "face_enrolled": false, "enrolled_at": null }
    ]
  }
}
```

Scoped to the station's branch and to **active** employees only. An employee of
another branch is not returned, so they cannot be selected (User Story 2
scenario 6) — enforced server-side, not by hiding a row in the UI.

`face_enrolled` lets the tablet sort unenrolled people first, which is the whole
job on a first morning with forty workers in a queue.

---

## POST `app/kiosk/admin/enroll.php` *(new)*

**Auth**: `X-Kiosk-Token` + `X-Kiosk-Admin-Session`

**Request**

```json
{
  "employee_id": 91,
  "nonce": "…",
  "embedding": ["… 192 floats …"],
  "model_version": "mobilefacenet_v1",
  "quality_score": 0.81,
  "liveness_passed": true,
  "image": "data:image/jpeg;base64,…",
  "confirm_replace": false
}
```

**Success `200`**

```json
{
  "status": "success",
  "data": { "employee_id": 91, "enrolled_at": "2026-08-03T09:41:00+03:00", "replaced_previous": false }
}
```

**Server-side**, writing the same `employees` columns as
`app/biometric/enroll_face.php` so a kiosk enrollment *is* the enrollment a
selfie punch would match against — not a parallel one:

| Column | Value |
|---|---|
| `face_embedding` | Packed floats |
| `face_model_version` / `face_embedding_dim` | From the request, validated |
| `face_quality_score` | Rejected below `BiometricEnrollment::MIN_QUALITY_SCORE` (0.5) |
| `face_photo_url` | Via `BiometricEnrollment::storeReferencePhoto()` |
| `face_enrolled_at` | `TenantClock` |
| `face_enrolled_by_station_id` | The station (FR-041) |

**Quality is judged on the server** (FR-040). The tablet computes a score but does
not decide — the same principle as matching, extended to enrollment, because a
patched kiosk that self-reports perfect quality would poison the roster it later
matches against.

**Re-enrollment** requires `confirm_replace: true`; without it an already-enrolled
employee returns `409` naming the existing enrollment date. This turns "a second
person enrolled onto an existing employee" from a silent overwrite into a
deliberate, logged act (FR-041, edge case).

**Failure**

| Code | When |
|---|---|
| `409` | Already enrolled and `confirm_replace` not set |
| `422` | Quality below minimum, wrong model version, or employee not in this branch |

---

## POST `app/kiosk/admin/close.php` *(new)*

Ends the administration session, or releases kiosk mode entirely.

**Auth**: `X-Kiosk-Token` + `X-Kiosk-Admin-Session`

**Request**: `{ "release_kiosk_mode": true }`

`release_kiosk_mode: true` is what lets a supervisor unpin the tablet to change
the WiFi or move it (User Story 5). It is reachable **only** here, which is why
FR-022 requires an access code rather than the static per-branch PIN the old
`branches.station_admin_pin_hash` column was built for.

---

## Management-side surfaces

### POST `app/kiosk/set_pin.php` *(new)*

**Auth**: `X-Firebase-Token` · **Permission**: `manage_employees`

**Request**: `{ "employee_id": 88, "regenerate": true }`

**Response**: `{ "code": "4821" }` — shown once, stored as
`employees.kiosk_pin_hash`. A regenerate invalidates the previous code
immediately (FR-017). The plaintext is never recoverable (FR-018).

Gated by `manage_employees` rather than a kiosk permission: this is an attribute
of an employee record, and whoever maintains employee records maintains it.

### POST `app/kiosk/recognition_logs.php` *(new)*

**Auth**: `X-Firebase-Token` · **Permission**: `manage_attendance`

Reads `station_recognition_logs` with filters on branch, station, result, and date
(User Story 7). Supports `view: "distribution"` returning a score histogram, the
same shape `app/attendance/face_logs.php` already returns for `face_selfie` —
this is how a company tunes `station_match_threshold` and `station_match_margin`
on its own data instead of on the numbers in [R-001](../research.md).

`capture_path` is **omitted** from this response. Scores and outcomes are
attendance data; the image behind them is not, and reaching it costs a different
permission.

### POST `app/kiosk/capture.php` *(new)*

**Auth**: `X-Firebase-Token` · **Permission**: `kiosk_evidence`

**Request**: `{ "recognition_log_id": 55123 }`

Returns a short-lived signed URL for the stored capture (FR-055). Every call
writes an audit row — viewing a colleague's biometric evidence is itself an
auditable act (FR-059).

Returns `410` once `capture_expires_at` has passed and the purge has run: the
evidence window is finite by design, and the endpoint says so rather than
returning a broken image.

---

## Frontend gating

FR-061 requires every control that leads to a kiosk action to be gated by the
same permission the endpoint enforces. In this codebase a mismatch does not
produce a helpful message — it produces a bare "an error occurred", because the
`403` surfaces as a generic failure.

| Surface | Permission |
|---|---|
| Branch → Kiosks tab; add / revoke device | `kiosk_devices` |
| "Open kiosk settings" (generate access code) | `kiosk_access` |
| Employee → kiosk code | `manage_employees` |
| Attendance → kiosk activity / score distribution | `manage_attendance` |
| "View capture" beside an attendance row | `kiosk_evidence` |

`login.php` already returns the caller's effective permissions, so these gates
read from data the client holds rather than inferring from role.
