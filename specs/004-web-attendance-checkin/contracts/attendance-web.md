# Contract — Attendance from the Browser

**Feature**: `004-web-attendance-checkin`

`check_in.php` and `check_out.php` are **extended, not replaced**. A web punch
walks the same path as an app punch — same geofence, same method resolution,
same working-day maths, same payroll treatment (FR-008). Only three things
differ: the origin is recorded, a photo may be required, and BSSID verification
is unavailable.

---

## POST `app/attendance/web_status.php` *(new)*

What the landing page needs to render truthfully (FR-009).

**Auth**: `X-Employee-Token`

**Request**: empty body

**Success `200`**

```json
{
  "status": "success",
  "data": {
    "state": "checked_in",
    "check_in_at": "2026-08-03T08:02:00+03:00",
    "check_in_origin": "app",
    "branch": { "id": 3, "name": "…", "latitude": 30.05, "longitude": 31.23, "gps_radius_meters": 100 },
    "photo_required": true,
    "network_constraint": "ip",
    "server_time": "2026-08-03T14:31:00+03:00"
  }
}
```

| Field | Meaning |
|---|---|
| `state` | `not_checked_in` · `checked_in` · `checked_out` |
| `check_in_origin` | Reflects punches from **any** channel — an app check-in must show here, or the browser would offer a second check-in for the same day |
| `photo_required` | Company setting; the client uses it to decide whether to warm the camera |
| `network_constraint` | `ip` · `none`. `none` means the branch defines no IP/CIDR row, so this channel has no network control ([R-005](../research.md)) |
| `server_time` | Tenant-zone time, so the UI never renders the device clock (FR-010) |

---

## POST `app/attendance/check_in.php` *(extended)*

**Auth**: `X-Employee-Token`

**New request fields**

| Field | Type | Notes |
|---|---|---|
| `photo_base64` | string | Required when the company enables photo capture. Same encoding as face enrolment |

**Fields deliberately NOT accepted from a web session**

| Field | Why |
|---|---|
| `origin` / `platform` | Derived server-side from the session ([R-011](../research.md)). Accepting it would let a punch launder itself past a channel restriction |
| `bssid` | Unreachable from a browser; a value here could only be fabricated |
| `is_mock_location` | Android-only, app-only. Absent, not false — the distinction matters in the security log |

**New failures**

| Code | HTTP | When |
|---|---|---|
| `web_not_permitted` | 403 | Company or category forbids the channel. Logged as `web_not_permitted` |
| `photo_required` | 422 | Company requires a photo and none was usable (FR-017b) |
| `photo_invalid` | 422 | Not decodable, not an image, or over the byte cap |

**Existing failures unchanged**: `gps_out_of_range`, `BRANCH_NOT_FOUND`,
`method_not_allowed`, and the network-verification refusals.

**Server-side behaviour on success**

1. Resolve the attendance method as today (`AttendanceMethodResolver`) — the web
   is a channel, so `check_in_method` still records `qr_gps`/`gps_only`.
2. Validate the geofence (`GpsService`) — unchanged.
3. Validate IP/CIDR if the branch defines one (`NetworkVerifier`, IP mode only).
4. Store the photo via `PunchPhotoService` if required.
5. Stamp the time from `TenantClock`.
6. Write `check_in_origin = 'web'` **from the session**.
7. Run `SharedDeviceDetector`; set `shared_device_flag` on this punch **and on
   the other employee's punches from the same device today** — a flag that
   marked only the second party would read as an accusation of one side.

---

## POST `app/attendance/check_out.php` *(extended)*

Same additions as check-in, plus one:

**On success, the web session is revoked** (FR-004a). The response tells the
client so it can clear its state and return to the PIN screen:

```json
{ "status": "success", "data": { "checked_out_at": "…", "session_ended": true } }
```

**Why the server does it rather than the client**: a shared computer must be left
safe by the *system*, not by the departing employee remembering to press
"log out".

---

## Cross-channel rules

| Situation | Behaviour |
|---|---|
| Checked in on app → checks out on web | Allowed. One attendance day, two origins recorded |
| Checked in on web → checks out on app | Allowed. The web session is revoked too, so it is not left alive by a check-out that happened elsewhere |
| Web session expires mid-shift | Sign in again with the PIN; the open shift is still there (FR-004b) |
| Company disables the channel while checked in | The **open shift can still be closed**; new check-ins are refused (spec edge case) |
| Connection lost mid-punch | No silent queue. The client re-reads `web_status.php` and tells the employee plainly whether the punch landed (FR-011) |
