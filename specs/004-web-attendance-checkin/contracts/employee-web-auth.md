# Contract — Employee Web Authentication

**Feature**: `004-web-attendance-checkin`

Conventions inherited from the codebase and non-negotiable here:

- **All writes are POST** (`Auth::requirePost`) — including logout. PUT/DELETE are
  not used anywhere in this backend.
- Requests are JSON bodies; the session travels in the **`X-Employee-Token`**
  header (`Auth::authenticateEmployee` also accepts it in the body or query, but
  the web client uses the header only).
- Every endpoint calls `RateLimiter::enforceIpLimit()` first, matching
  `employee_login.php` and `check_in.php`.
- Failures use `Response::fail(message, httpStatus, code)`. `message` is
  user-facing and localised; `code` is the stable machine identifier.

---

## POST `app/auth/employee_web_activate.php`

First-ever web sign-in. Consumes the single-use activation code and sets the PIN.

**Auth**: none (this is the entry point)

**Request**

| Field | Type | Notes |
|---|---|---|
| `phone` | string | E.164 with explicit country code (`Validator::phone`) |
| `activation_code` | string | Single-use, 24-hour lifetime — consumed here |
| `pin` | string | Exactly 6 digits |
| `device_id` | string | Browser UUID from the long-lived cookie |

**Success `200`**

```json
{
  "status": "success",
  "data": {
    "token": "<opaque web session token>",
    "expires_at": "2026-08-03T09:14:00+03:00",
    "employee": { "id": 12, "name": "…", "branch_id": 3, "branch_name": "…" }
  }
}
```

**Failures**

| Code | HTTP | When |
|---|---|---|
| `missing_fields` | 422 | Any required field absent |
| `invalid_pin_format` | 422 | Not exactly 6 digits, or trivial (`111111`, `123456`, `654321`) |
| `invalid_activation` | 401 | Code wrong, already consumed, or expired |
| `web_not_permitted` | 403 | Company or category forbids the channel — also written to `attendance_security_logs` |
| `already_activated` | 409 | A credential already exists; the employee should sign in, or ask an admin to reset |

**Behaviour**

- Creates the `employee_web_credentials` row and issues a web session in one
  transaction — a consumed code that produced no credential would strand the
  employee with nothing.
- `expires_at` computed **in SQL**: `DATE_ADD(NOW(), INTERVAL 16 HOUR)`.
- Revokes the employee's other `platform='web'` tokens. App tokens untouched.

---

## POST `app/auth/employee_web_login.php`

Every subsequent web sign-in.

**Auth**: none

**Request**: `phone`, `pin`, `device_id`

**Success `200`**: same shape as activate.

**Failures**

| Code | HTTP | When |
|---|---|---|
| `invalid_credentials` | 401 | Wrong phone or PIN. **Deliberately identical for both** — distinguishing them tells an attacker which phone numbers are enrolled |
| `web_pin_locked` | 423 | 5 consecutive failures; `locked_until` set. Logged |
| `not_activated` | 404 | No credential yet — the employee must activate first |
| `web_not_permitted` | 403 | Channel forbidden. Logged |
| `rate_limited` | 429 | Per-IP or per-phone limit exceeded ([R-007](../research.md)) |

**Behaviour**

- Increments `failed_attempts` on failure; resets to 0 on success.
- Rate limited on **both** IP and phone, so spreading an attack across addresses
  does not evade the limit.

---

## POST `app/auth/employee_web_logout.php`

**Auth**: `X-Employee-Token`

**Request**: empty body

**Success `200`**: `{"status":"success"}`

Revokes the presenting session only. Idempotent — logging out twice is a success,
not an error.

---

## Session behaviour (applies to all of the above)

| Rule | Detail |
|---|---|
| Lifetime | Ends at check-out, or 16 hours, whichever is first |
| Storage (client) | **httpOnly, Secure, SameSite=Lax** cookie — not `localStorage`, which any injected script can read |
| One per employee | Issuing revokes prior `platform='web'` sessions only |
| Expiry check | Server-side on every request; an expired token returns `401` and the client returns the employee to the PIN screen with their phone pre-filled |
| Lapse while checked in | Signing in again restores access to the still-open shift (FR-004b) — attendance rows never depend on the session that created them |
