# Contract: Support Push (super-admin devices)

Adds FCM delivery to the support team. Separate slice (medjat_admin currently has no Firebase).

## POST `/admin/devices/register.php` — NEW
Auth: Bearer `<admin_token>`, role `admin`.
Body: `{ fcm_token, platform?, device_id?, device_model?, app_version? }`.
Upserts into `super_admin_devices` keyed by `(admin_id, device_id)`; sets `is_active=1`.
Response `data`: `{ registered: true }`.

## Push trigger (no new endpoint — extend existing tenant-side flow)
In `app/support/create.php` and `app/support/reply.php` (when `sender_type='user'`), after persisting, call:

```
NotificationService::sendToSupportTeam(
  title: 'New support message',
  body:  <ticket subject / preview>,
  data:  { type: 'support', ticket_id: <id> }
);
```

`NotificationService::sendToSupportTeam()` — NEW:
- Select active `fcm_token`s from `super_admin_devices` (optionally all `admin`+`superadmin` roles).
- Send a multicast FCM message via the existing kreait messaging client.
- Best-effort: failures are logged, never block the ticket write.

## Client behavior (medjat_admin)
- On login/app-start: request notification permission, fetch FCM token, call `/admin/devices/register.php`.
- On notification tap with `data.type='support'`: deep-link to the support thread for `ticket_id`.
- Independent of push, the inbox always shows `unread_for_support` badges (works with no Firebase).
