# Contract — Administrator Settings

**Feature**: `004-web-attendance-checkin`

Consumed by `medjat_central` (Flutter) and, if it grows a settings screen, by
`medjat_central_web`.

⚠️ **Permission gating must match exactly.** Frontend menu and tab gates must use
the same permission the endpoint enforces. A mismatch does not fail politely —
the user gets a 403 that the apps surface as a generic "an error occurred", which
is the hardest class of bug to diagnose from a support ticket.

---

## POST `app/settings/company.php` *(extended)*

**Permission**: `manage_company_settings`

**New fields**

| Field | Type | Default | Notes |
|---|---|---|---|
| `web_attendance_enabled` | bool | `false` | FR-021 — off for every existing company |
| `web_attendance_photo_required` | bool | `true` | FR-017a — on by default *when* the channel is on |

**New response fields** (so the UI can render the honest disclosure of FR-014)

```json
{
  "web_attendance_enabled": false,
  "web_attendance_photo_required": true,
  "web_channel_limitations": {
    "wifi_bssid_verification": false,
    "mock_location_detection": false,
    "face_verification": false,
    "offline_queue": false
  },
  "branches_without_ip_networks": [3, 7]
}
```

`branches_without_ip_networks` exists so the settings screen can warn concretely:
those branches have **no network control at all** on this channel, because their
approved networks are wireless access points, which a browser cannot see
([R-005](../research.md)).

**Audit**: every change to either flag writes an `AuditLogModel` entry with the
actor and timestamp (FR-024).

---

## POST `app/categories/update_web_access.php` *(new)*

**Permission**: `manage_company_settings`

**Request**

| Field | Type | Notes |
|---|---|---|
| `category_id` | int | Must belong to the caller's tenant |
| `web_attendance_allowed` | bool \| null | `null` = inherit the company setting |

**Resolution** (FR-023, FR-023a):

```
company disabled                                  → refuse
company enabled, no category sets a value         → allow
company enabled, ≥1 of the employee's categories
  sets web_attendance_allowed = 1                 → allow
otherwise                                         → refuse
```

Union-with-any, matching how category attendance methods already resolve — one
mental model for administrators, not two.

⚠️ **This is not an attendance method** (FR-023b). It must not be added to
`AttendanceMethodResolver::ALLOWED` nor to the four selection screens. The web is
*where* attendance is recorded from; a method is *how it is proven*. That
distinction is already blurred in `ALLOWED`, and this feature must not blur it
further.

---

## POST `app/employees/reset_web_pin.php` *(new)*

**Permission**: `manage_employees`

**Request**: `employee_id`

**Success `200`**

```json
{
  "status": "success",
  "data": { "activation_code": "AB12CD", "expires_at": "2026-08-04T10:00:00+03:00" }
}
```

**Behaviour**

- Deletes the `employee_web_credentials` row, clearing any lockout.
- Revokes the employee's live `platform='web'` sessions — a reset must take
  effect immediately, not at next expiry.
- Issues a fresh single-use activation code so the employee can set a new PIN.
- Writes an audit entry.

**Doubles as a lockout control**: for a departing or suspended employee this is
the one call that severs browser access at once.

---

## Attendance review *(existing screens, extended)*

**Permission**: whatever already governs attendance review — unchanged.

Attendance rows returned to `medjat_central` gain:

| Field | Purpose |
|---|---|
| `check_in_origin` / `check_out_origin` | `app` · `web` · null — lets a manager see the channel (FR-008) |
| `check_in_photo` / `check_out_photo` | Path to the captured evidence (FR-018) |
| `shared_device_flag` | One device served several employees that day (FR-019) |

The flag is **advisory**. It must never auto-reject attendance (FR-020) — it is
information for a human decision, consistent with how `is_vpn` and the existing
security flags already behave.
