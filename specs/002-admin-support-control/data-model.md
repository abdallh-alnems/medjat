# Phase 1 Data Model: Admin Support & App Control Center

## Existing tables (reused — no change)

### `support_tickets`
| Field | Type | Notes |
|-------|------|-------|
| id | int unsigned PK | |
| tenant_id | int unsigned FK→tenants | owning company |
| opened_by_admin_id | int unsigned FK→admins | tenant admin who opened it |
| subject | varchar(255) | |
| category | enum(technical,billing,feature_request,account,other) | |
| priority | enum(low,normal,high,urgent) | |
| status | enum(open,pending_support,pending_user,resolved,closed) | |
| assigned_super_admin_id | int unsigned NULL | **unused in v1** (shared queue) |
| last_message_at | timestamp NULL | inbox ordering |
| last_message_preview | varchar(255) | |
| unread_for_user | tinyint(1) | support reply unread by user |
| unread_for_support | tinyint(1) | **drives support inbox badge** |
| created_at / updated_at | timestamp | |

State transitions (already enforced in `SupportModel`):
- create → `open` (unread_for_support=1)
- user message → `pending_support` (unread_for_support=1)
- support reply → `pending_user` (unread_for_user=1)
- operator action → `resolved` / `closed` (NEW endpoint) ; reopen → `pending_support`

### `support_messages`
| Field | Type | Notes |
|-------|------|-------|
| id | int unsigned PK | |
| ticket_id | int unsigned FK→support_tickets | |
| sender_type | enum(user,support,system) | |
| sender_admin_id | int unsigned NULL | set when sender_type=user |
| sender_super_admin_id | int unsigned NULL | set when sender_type=support |
| body | text | required, ≤5000 chars |
| attachment_url / attachment_name | varchar NULL | **kept, unused in v1 (text-only)** |
| created_at | timestamp | thread ordering / `after_id` polling key (`id`) |

## New table

### `super_admin_devices` (migration `2026_06_admin_support_control.sql`)
Device tokens for support-team push (FR-010b / SC-009). Mirrors `admin_devices` but FK→`super_admins`.

| Field | Type | Notes |
|-------|------|-------|
| id | int unsigned PK AUTO_INCREMENT | |
| admin_id | int unsigned FK→super_admins ON DELETE CASCADE | support member |
| fcm_token | varchar(500) NOT NULL | |
| platform | enum(android,ios,web) DEFAULT 'android' | |
| device_id | varchar(100) NULL | |
| device_model | varchar(100) NULL | |
| app_version | varchar(20) NULL | |
| is_active | tinyint(1) DEFAULT 1 | |
| created_at / updated_at | timestamp | |
| | UNIQUE KEY (admin_id, device_id) | upsert on re-register |
| | KEY idx_token (fcm_token(50)) | |

## Configuration "entity" — Firebase Remote Config (not a DB table)

App-control values live as Remote Config parameters (read/written by the backend `RemoteConfigService`). Logical shape returned to the admin app:

```json
{
  "apps": [
    { "key": "medjat_app",     "name": "Employee App",       "min_version": "1.2.0", "maintenance": false, "supports_maintenance": true },
    { "key": "medjat_central", "name": "HR Management App",   "min_version": "1.4.1", "maintenance": false, "supports_maintenance": true },
    { "key": "medjat_admin",   "name": "Admin App",          "min_version": "1.0.0", "maintenance": null,  "supports_maintenance": false }
  ]
}
```

Validation rules:
- `min_version`: non-empty, dotted-numeric (`^\d+(\.\d+){0,3}$`); empty/`0.0.0` = no force update. Reject malformed (FR-017).
- `maintenance`: boolean; only accepted for `permedjat_app` and `permedjat_central` (reject for `permedjat_admin`, FR-014).
- High-impact writes (maintenance=true, or raising min_version) are confirmed in the UI (FR-018) and audited (FR-002).

## Flutter models (permedjat_admin)

- **SupportTicketModel**: id, tenantId, tenantName, subject, category, priority, status, lastMessageAt, lastMessagePreview, unreadForSupport. (from `admin_support/list.php` + `messages.php` `ticket`)
- **SupportMessageModel**: id, ticketId, senderType, body, createdAt. (`sender_super_admin_id`/`sender_admin_id` collapsed to `senderType` for display)
- **AppControlModel**: key, name, minVersion, maintenance (nullable), supportsMaintenance.

## Audit (existing `super_admin_audit_log` via `AdminAuth::logAction`)
Actions logged: `support.reply` (exists), `support.status` (NEW), `app_control.set_version` (NEW), `app_control.set_maintenance` (NEW) — each with target app/ticket and old/new values.
