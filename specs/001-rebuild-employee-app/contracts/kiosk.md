# Contract: Kiosk (Attendance Station) — REUSE existing backend

**Feature**: `001-rebuild-employee-app`, User Story 7. **No backend changes** — these endpoints already exist and are verified. Kiosk requests use **`X-Station-Token`** (NOT `X-Employee-Token`) + Basic auth. The app stores the station token in secure storage under `station_token`.

Admin side (already in management app, out of scope): `stations/create.php` (makes a station + pairing QR), `stations/update_branch_settings.php` (methods/threshold/anti-spoofing/radius/PIN), `stations/regenerate_qr.php`, `stations/list.php`.

---

## Pair the device
**POST `app/station/activate.php`** — no station token yet.
- Body: `{ "qr_payload": "<scanned from admin>", "device_info": {…} }`
- Success: station record incl. token + branch info (store token). Failure 400 `Invalid or expired QR code` → stay on pairing screen.

## Load roster + settings
- **GET `app/station/sync.php`** — `X-Station-Token`. Returns sync payload (employees, branch station settings, lock state). Updates `last_sync_at`. 403 if station locked. Cache for offline.
- **GET `app/station/branch_employees.php`** — `X-Station-Token`. `{items:[{id,name,phone,job_title,biometric_enrollment_status}]}` for active branch employees.

## Check in / out
**POST `app/station/check_in_out.php`** — `X-Station-Token`.
- Body: `{ "employee_id", "method", "confidence?", "gps_lat?", "gps_lng?", "captured_image_base64?" }`, `method ∈ {face, fingerprint, both}` (must respect branch `station_methods`).
- Success: `{ action: check_in|check_out, attendance_id, employee_name, timestamp }`.
- 429 when `action=too_soon` (duplicate within interval → FR-032). 403 if station locked. 404 employee.
- Every attempt is logged server-side (recognition log) → FR-028 audit.

## Admin gate + enrollment
- **POST `app/station/verify_admin_pin.php`** — `{pin}` → `{valid:bool}`. Used to exit kiosk mode / open settings (FR-029) and before enrollment.
- **POST `app/station/enroll_employee_biometric.php`** — `{admin_pin, employee_id, face_embedding?|fingerprint_template?}`. Admin-PIN gated (403 invalid PIN). Stores embedding/template (FR-030).

## Liveness / lock
**POST `app/station/heartbeat.php`** — `{gps_lat?, gps_lng?}`. Server auto-locks the station if it drifts beyond `3 × station_gps_radius_meters` from the branch; returns `{status: ok|locked, reason?}`. App polls periodically; on `locked` it refuses check-ins and shows the locked state (FR-033).

---

## App responsibilities (StationController / station_data)
1. **Pairing** (from login screen "وضع الكيوسك"): scan admin QR → `activate` → store `station_token` → route to kiosk home.
2. **On-device biometric** matching (face and/or fingerprint per branch `station_methods`), honoring `station_confidence_threshold` + `station_anti_spoofing_enabled`; send resulting `confidence`. Library choice deferred to tasks (research D10).
3. **Offline**: queue check-ins locally + roster from last `sync`; submit when online; respect lock state.
4. **Lock to screen** + admin-PIN to exit (FR-029) via `verify_admin_pin`.
5. **Heartbeat** loop; stop accepting check-ins when `locked`.
