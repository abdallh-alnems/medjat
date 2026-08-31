<?php

declare(strict_types=1);

namespace App\Modules\AdminSupport\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\SuperAdmin;
use App\Modules\Notifications\Domain\PushSender;
use App\Modules\SuperAdmin\Domain\SuperAdminAudit;
use App\Modules\Support\Domain\SupportAttachment;
use App\Modules\Support\Domain\SupportTickets;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Ports of api/app/admin_support/*.php.
 *
 * The support desk's side of a ticket. It is deliberately not scoped to a
 * company — looking across them is the whole point — so nothing here takes a
 * tenant id, and every action lands in the super-admin audit log rather than
 * in the company's own activity feed, where it would both mislead that company
 * and hide the action from every other one it touched.
 */
final class AdminSupportController
{
    private const MAX_BODY_LENGTH = 5000;

    private const DEFAULT_LIMIT = 30;

    private const MAX_LIMIT = 50;

    /** What the desk may set. `reopen` is a verb, not a stored status. */
    private const SETTABLE = ['resolved', 'closed', 'reopen'];

    public function __construct(private readonly PushSender $push) {}

    public function index(Request $request): JsonResponse
    {
        $page = max(1, Value::int($request->query('page'), 1));
        $limit = min(self::MAX_LIMIT, max(1, Value::int($request->query('limit'), self::DEFAULT_LIMIT)));

        $tenantId = Value::int($request->query('tenant_id'));
        $status = Value::string($request->query('status'));

        return ApiResponse::success(SupportTickets::queue(
            $status !== '' ? $status : null,
            $tenantId > 0 ? $tenantId : null,
            $page,
            $limit,
        ));
    }

    public function messages(Request $request): JsonResponse
    {
        $ticket = $this->ticket(Value::int($request->query('ticket_id')));
        $ticketId = Value::int($ticket['id'] ?? null);

        $afterId = $request->query('after_id');

        // A polling request asking only for what is new does not mean anybody
        // read the thread; opening it does.
        $opened = $afterId === null;

        if ($opened) {
            SupportTickets::markReadBySupport($ticketId);
            $ticket = $this->ticket($ticketId);
        }

        $messages = SupportTickets::messages($ticketId, $opened ? null : Value::int($afterId));

        return ApiResponse::success([
            'ticket' => $ticket,
            'messages' => $messages['messages'],
            'last_id' => $messages['last_id'],
        ]);
    }

    public function reply(Request $request): JsonResponse
    {
        $admin = self::admin($request);
        $ticket = $this->ticket(Value::int($request->input('ticket_id')));
        $ticketId = Value::int($ticket['id'] ?? null);

        $body = trim(Value::string($request->input('body')));
        $raw = $request->input('attachment');
        $hasAttachment = $raw !== null && $raw !== '';

        // A screenshot on its own is a complete answer, so the body may be
        // empty when something is attached — but a message with neither is not
        // a message.
        if ($body === '' && ! $hasAttachment) {
            throw new ApiFailure(__('messages.message_or_attachment_required'), 422, 'body_required');
        }

        if (mb_strlen($body) > self::MAX_BODY_LENGTH) {
            throw new ApiFailure(__('messages.message_too_long'), 422, 'body_too_long');
        }

        $attachment = $hasAttachment
            ? SupportAttachment::store($raw, $ticketId, Value::nullableString($request->input('attachment_name')))
            : null;

        if ($hasAttachment && $attachment === null) {
            throw new ApiFailure(
                __('messages.attachment_save_failed'),
                422,
                'attachment_rejected',
            );
        }

        $messageId = SupportTickets::addMessage(
            $ticketId, 'support', null, $admin->id, $body,
            $attachment['path'] ?? null, $attachment['name'] ?? null,
        );

        $this->tellTheCompany($ticket, $body, $attachment['name'] ?? null, $ticketId);

        SuperAdminAudit::record($admin->id, 'support.reply', 'support_ticket', $ticketId, [
            'message_id' => $messageId,
        ]);

        return ApiResponse::success([
            'message_id' => $messageId,
            'status' => SupportTickets::status($ticketId),
        ]);
    }

    public function setStatus(Request $request): JsonResponse
    {
        $admin = self::admin($request);
        $ticket = $this->ticket(Value::int($request->input('ticket_id')));
        $ticketId = Value::int($ticket['id'] ?? null);

        $requested = trim(Value::string($request->input('status')));

        if (! in_array($requested, self::SETTABLE, true)) {
            throw new ApiFailure('status must be resolved, closed or reopen', 422, 'invalid_status');
        }

        $previous = SupportTickets::status($ticketId);

        // Reopening puts the ball back in the desk's court, which is what
        // pending_support means — there is no separate "reopened" state.
        $status = $requested === 'reopen' ? 'pending_support' : $requested;

        SupportTickets::setStatus($ticketId, $status);

        SuperAdminAudit::record($admin->id, 'support.status', 'support_ticket', $ticketId, [
            'from' => $previous,
            'to' => $status,
        ]);

        return ApiResponse::success(['ticket_id' => $ticketId, 'status' => $status]);
    }

    /**
     * Serves one attachment.
     *
     * Stored outside any publicly-served directory and reached only through
     * here, so a leaked URL is worthless without a live desk session — a
     * client's screenshot can hold payroll figures or staff faces.
     */
    public function attachment(Request $request): StreamedResponse
    {
        $messageId = Value::int($request->query('message_id'));

        $message = $messageId > 0 ? SupportTickets::message($messageId) : null;
        $stored = Value::nullableString($message['attachment_url'] ?? null);

        if ($message === null || $stored === null || $stored === '') {
            throw new ApiFailure(__('messages.attachment_not_found'), 404, 'not_found');
        }

        $relative = SupportAttachment::relativePath($stored);
        $disk = Storage::disk('uploads');

        if ($relative === null || ! $disk->exists($relative)) {
            throw new ApiFailure(__('messages.file_not_found'), 404, 'not_found');
        }

        $name = Value::string($message['attachment_name'] ?? null) ?: basename($relative);

        return $disk->response($relative, $name, [
            'Content-Type' => SupportAttachment::mimeFor($relative),
            // Inline, because the desk reads these rather than filing them.
            'Content-Disposition' => 'inline; filename="'.rawurlencode($name).'"',
            'Cache-Control' => 'private, max-age=300',
        ]);
    }

    /**
     * @param  array<string, mixed>  $ticket
     */
    private function tellTheCompany(array $ticket, string $body, ?string $attachmentName, int $ticketId): void
    {
        $recipient = Value::nullableInt($ticket['opened_by_admin_id'] ?? null);

        if ($recipient === null) {
            return;
        }

        $preview = $body !== '' ? $body : '📎 '.($attachmentName ?? 'مرفق');

        DB::table('notifications')->insert([
            'admin_id' => $recipient,
            // Deliberately null: the notification belongs to the desk's thread
            // with one person, not to the company's own feed.
            'tenant_id' => null,
            'type' => 'support',
            'title' => 'Support Reply',
            'title_ar' => 'رد الدعم',
            'body' => mb_substr($preview, 0, 200),
            'body_ar' => mb_substr($preview, 0, 200),
            'created_at' => DB::raw('NOW()'),
        ]);

        $this->push->toAdmin($recipient, 'رد الدعم', mb_substr($preview, 0, 100), [
            'type' => 'support',
            'ticket_id' => (string) $ticketId,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function ticket(int $ticketId): array
    {
        $ticket = $ticketId > 0 ? SupportTickets::findAnywhere($ticketId) : null;

        if ($ticket === null) {
            throw new ApiFailure(__('messages.ticket_not_found'), 404, 'not_found');
        }

        return $ticket;
    }

    private static function admin(Request $request): SuperAdmin
    {
        $admin = $request->attributes->get('super_admin');

        if (! $admin instanceof SuperAdmin) {
            throw new ApiFailure(__('messages.admin_token_required'), 401, 'admin_token_required');
        }

        return $admin;
    }
}
