# Contract: App Control Endpoints (Remote Config)

All require `Authorization: Bearer <admin_token>` and role **`superadmin`** (`AdminAuth::require('superadmin')`). Backend reads/writes Firebase Remote Config via `core/RemoteConfigService.php` (`kreait/firebase-php`).

## GET `/admin_app_control/get.php` — NEW
Reads the current Remote Config template values for all governed apps.
Response `data`:
```json
{ "apps": [
  { "key": "permedjat_app",     "name": "Employee App",     "min_version": "1.2.0", "maintenance": false, "supports_maintenance": true },
  { "key": "permedjat_central", "name": "HR Management App", "min_version": "1.4.1", "maintenance": false, "supports_maintenance": true },
  { "key": "permedjat_admin",   "name": "Admin App",        "min_version": "1.0.0", "maintenance": null,  "supports_maintenance": false }
] }
```
On RC fetch failure: 503 with a clear message (the app shows an error, never assumes values).

## POST `/admin_app_control/set.php` — NEW
Body (one field per call, or both):
```json
{ "app": "permedjat_app", "min_version": "1.3.0", "maintenance": true }
```
Rules:
- `app ∈ {permedjat_app, permedjat_central, permedjat_admin}`.
- `min_version` (if present): non-empty, regex `^\d+(\.\d+){0,3}$` → writes `<app>_min_version`. Reject malformed (422, FR-017).
- `maintenance` (if present): boolean → writes `<app>_maintenance_enabled`. **Rejected (422) when `app=permedjat_admin`** (FR-014: Admin not stoppable).
- Publishes the updated Remote Config template.
- Audit `app_control.set_version` and/or `app_control.set_maintenance` with `{app, from, to}`.
Response `data`: `{ app, min_version?, maintenance? }` (echo of new state).
Errors: 422 invalid app/version or maintenance-on-admin; 503 Remote Config write failure (no partial state reported).

> High-impact confirmation (FR-018) is enforced **client-side** before calling `set.php` (enabling maintenance or raising min_version shows a confirm dialog naming the app).
