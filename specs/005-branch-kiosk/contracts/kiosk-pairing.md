# Contract — Kiosk Pairing and Device Identity

**Feature**: `005-branch-kiosk`

Three actors touch these endpoints and they must never be confused. The
**management app** holds a Firebase admin token and creates codes. The **tablet**
holds no credential until it consumes one, then holds a kiosk token for the rest
of its life. An **employee** touches none of this — no employee-authenticated
endpoint appears in this contract, and that absence is the feature's central
security property (FR-031).

---

## POST `app/kiosk/create_pairing_code.php` *(new)*

Management asks for a code that will bind one tablet to one branch (FR-001).

**Auth**: `X-Firebase-Token` · **Permission**: `kiosk_devices`

**Request**

```json
{ "branch_id": 3, "name": "Main gate" }
```

**Success `200`**

```json
{
  "status": "success",
  "data": {
    "code": "K7F2-9QMX",
    "expires_at": "2026-08-03T14:46:00+03:00",
    "branch": { "id": 3, "name": "فرع المعادي" }
  }
}
```

`code` is the **only** time the plaintext exists — `kiosk_codes` stores its
SHA-256. Re-reading the row cannot recover it, so a database read does not yield
a working credential. `expires_at` is computed as
`DATE_ADD(NOW(), INTERVAL 900 SECOND)` **in SQL**, never in PHP: the server runs
UTC while MySQL runs the tenant zone, so a PHP-computed expiry is born expired.

**Failure**

| Code | When |
|---|---|
| `403` | Caller lacks `kiosk_devices` |
| `404` | Branch is not in the caller's tenant — `TenantMiddleware` handles this before the handler runs |
| `422` | Branch has `station_enabled = 0` |

---

## POST `app/kiosk/pair.php` *(new)*

The tablet redeems the code. This is the only kiosk endpoint that accepts an
unauthenticated request.

**Auth**: none — the code *is* the credential

**Request**

```json
{
  "code": "K7F2-9QMX",
  "device_id": "a3f9…",
  "device_model": "Lenovo Tab M10",
  "app_version": "1.0.0",
  "platform": "android"
}
```

**Success `200`**

```json
{
  "status": "success",
  "data": {
    "kiosk_token": "9f2c…64 chars…",
    "station": { "id": 12, "name": "Main gate" },
    "branch": { "id": 3, "name": "فرع المعادي", "latitude": 30.05, "longitude": 31.23, "station_gps_radius_meters": 30 },
    "tenant": { "id": 4, "name": "شركة …", "timezone": "Africa/Cairo" }
  }
}
```

The response returns the branch name so the tablet can confirm on screen what it
has become (User Story 1, scenario 2) — a supervisor pairing five tablets needs
to see which is which before mounting them.

`kiosk_token` is shown once and stored on the tablet in platform secure storage.
The server keeps only `SHA-256(token)` in `kiosk_auth_tokens`.

**Consumption is atomic.** The lookup, the expiry check, and the `used_at` write
happen in one guarded statement so that two tablets racing the same code cannot
both pair (User Story 1, scenario 3):

```sql
UPDATE kiosk_codes
   SET used_at = NOW(), used_by_station = ?
 WHERE code_hash = ? AND purpose = 'pair'
   AND used_at IS NULL AND expires_at > NOW()
```

Zero affected rows ⇒ `410 Gone`.

**Failure**

| Code | When |
|---|---|
| `410` | Code is unknown, expired, or already consumed — deliberately one message for all three, so the endpoint is not an oracle |
| `429` | Rate limited per IP via `RateLimiter` — this endpoint is unauthenticated |

---

## POST `app/kiosk/heartbeat.php` *(new)*

The tablet reports in. Also the point at which revocation and a stale version take
effect (FR-005, FR-053).

**Auth**: `X-Kiosk-Token`

**Request**

```json
{ "app_version": "1.0.0" }
```

**Success `200`**

```json
{
  "status": "success",
  "data": {
    "station_status": "active",
    "server_time": "2026-08-03T14:31:00+03:00",
    "settings": {
      "code_fallback_enabled": true,
      "anti_spoofing_enabled": true,
      "gps_radius_meters": 30,
      "min_seconds_between_punches": 60
    }
  }
}
```

`server_time` is tenant-zone (`TenantClock`) so the kiosk never renders the
tablet's own clock, which on a cheap tablet with no SIM is routinely wrong.

**Failure**

| Code | When | Tablet behaviour |
|---|---|---|
| `401` | Token revoked or unknown | Wipe local state, return to the pairing screen |
| `426` | `app_version` below `medjat_kiosk_min_version` | Show the supervisor-facing update message; refuse to identify anyone (FR-053) |
| `503` | Maintenance mode enabled for `permedjat_kiosk` | Show the maintenance screen |

`426` and `503` both come from `RemoteConfigService`, which gains a third app
entry alongside `permedjat_app` and `permedjat_central` ([R-007](../research.md)).

---

## POST `app/kiosk/list.php` *(new)*

Management sees the fleet (FR-004, FR-052, FR-054).

**Auth**: `X-Firebase-Token` · **Permission**: `kiosk_devices`

**Request**: `{ "branch_id": 3 }` — omit for every branch in the tenant

**Success `200`**

```json
{
  "status": "success",
  "data": {
    "stations": [
      {
        "id": 12,
        "name": "Main gate",
        "branch": { "id": 3, "name": "فرع المعادي" },
        "status": "active",
        "app_version": "1.0.0",
        "below_min_version": false,
        "last_seen_at": "2026-08-03T14:29:00+03:00",
        "is_offline": false,
        "punch_count": 1834,
        "last_punch_at": "2026-08-03T14:02:00+03:00"
      }
    ],
    "min_version": "1.0.0"
  }
}
```

`below_min_version` is what makes FR-054 answerable **before** a minimum is
raised: management can see which tablets a change would take offline, which
matters because a directly-installed kiosk has no store to update itself from.

`is_offline` derives from `last_seen_at` against the branch's working hours — the
same signal `attendance_devices.last_seen_at` provides for ZKTeco terminals.

---

## POST `app/kiosk/revoke.php` *(new)*

**Auth**: `X-Firebase-Token` · **Permission**: `kiosk_devices`

**Request**: `{ "station_id": 12, "reason": "tablet replaced" }`

Sets `attendance_stations.status = 'revoked'` and stamps `revoked_at` on the live
row in `kiosk_auth_tokens`. Historical attendance keeps pointing at the station
row — revocation must never orphan `attendance.station_id`.

Effective on the device's next request, which is the honest guarantee: a tablet
that is switched off or offline cannot be told anything (FR-005, SC-006).

---

## Authentication summary

| Principal | Header | Resolver | Scope |
|---|---|---|---|
| Administrator | `X-Firebase-Token` | `Auth::authenticateUser` (existing) | Their tenant, gated by permission |
| Employee | `X-Employee-Token` | `Auth::authenticateEmployee` (existing) | Themselves |
| **Kiosk** | `X-Kiosk-Token` | `Auth::authenticateKiosk` (**new**) | One branch, no person |

`authenticateKiosk()` resolves `SHA-256(token)` against `kiosk_auth_tokens`,
rejects when `revoked_at IS NOT NULL` or the station is not `active`, touches
`last_seen_at`, and returns `['tenant_id', 'branch_id', 'station_id']`. It never
returns an `employee_id`, because a kiosk is not a person — every downstream
handler must resolve the employee from the identification, not from the token.

All five endpoints are **POST**, including the two that only read: writes require
POST in this codebase and the reads are kept consistent with their neighbours.
