# Contract: Admin Support Endpoints

All require `Authorization: Bearer <admin_token>` and role **`admin`** (`AdminAuth::require('admin')`). Responses use the standard `Response::success(...)` envelope: `{ "success": true, "data": {...} }`.

## GET `/admin_support/list.php` — EXISTS (reuse)
Query: `page` (default 1), `limit` (≤50, default 30), `status?`, `tenant_id?`
Response `data`: `{ tickets: Ticket[], total, page }` where each Ticket includes `tenant_name`, `unread_for_support`, `last_message_at`, `last_message_preview`, `status`, `priority`, `category`.

## GET `/admin_support/messages.php` — EXISTS (reuse, used for polling)
Query: `ticket_id` (required), `after_id?`
- Without `after_id`: marks ticket read for support, returns full thread + `ticket`.
- With `after_id`: returns only messages with `id > after_id` (poll loop, no mark-read).
Response `data`: `{ ticket, messages: Message[], last_id }`.

## POST `/admin_support/reply.php` — EXISTS (reuse)
Body: `{ ticket_id, body }` (body required, ≤5000). Appends a `support` message, sets status `pending_user`, notifies the originating tenant admin, audits `support.reply`.
Response `data`: `{ message_id, status }`.

## POST `/admin_support/status.php` — NEW
Body: `{ ticket_id, status }` where `status ∈ {resolved, closed, reopen}`.
- `reopen` → `pending_support`; otherwise set to the given status.
- Validate ticket exists (`SupportModel::findTicketByIdGlobal`); validate enum.
- Call `SupportModel::setTicketStatus(ticketId, mapped)`; audit `support.status` with `{from, to}`.
Response `data`: `{ ticket_id, status }`.
Errors: 404 ticket not found; 422 invalid status.
