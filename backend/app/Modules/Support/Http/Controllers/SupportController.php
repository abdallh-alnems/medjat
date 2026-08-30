<?php

declare(strict_types=1);

namespace App\Modules\Support\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Support\Domain\SupportAttachment;
use App\Modules\Support\Domain\SupportTickets;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Ports of api/app/support/*.php.
 *
 * A company talking to whoever runs this service.
 */
final class SupportController
{
    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        return ApiResponse::success(SupportTickets::forTenant(
            $tenantId,
            Value::string($request->query('status')) ?: null,
            max(1, Value::int($request->query('page'), 1)),
            min(50, max(1, Value::int($request->query('limit'), 20))),
        ));
    }

    public function create(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        $subject = trim(Value::string($request->input('subject')));
        $body = trim(Value::string($request->input('body')));

        if ($subject === '' || mb_strlen($subject) > 255) {
            throw new ApiFailure('subject is required', 422, 'subject_required');
        }

        if ($body === '' || mb_strlen($body) > 5000) {
            throw new ApiFailure('body is required', 422, 'body_required');
        }

        $category = Value::string($request->input('category'), 'other') ?: 'other';
        $priority = Value::string($request->input('priority'), 'normal') ?: 'normal';

        if (! in_array($category, SupportTickets::CATEGORIES, true)) {
            throw new ApiFailure('Invalid category', 422, 'invalid_category');
        }

        if (! in_array($priority, SupportTickets::PRIORITIES, true)) {
            throw new ApiFailure('Invalid priority', 422, 'invalid_priority');
        }

        $ticketId = SupportTickets::create($tenantId, $adminId, $subject, $category, $priority, $body);

        AuditLog::record($tenantId, $adminId, 'support.ticket.create', 'support_ticket', $ticketId, [
            'subject' => $subject,
            'category' => $category,
        ]);

        return ApiResponse::success(['ticket_id' => $ticketId, 'message' => 'Ticket created'], 201);
    }

    /**
     * The thread.
     *
     * Reading the whole thread marks it read; polling for what arrived after a
     * known message does not, because a poll is not somebody looking at the
     * screen.
     */
    public function messages(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $ticketId = self::existing($request, $tenantId, fromQuery: true);

        $afterId = $request->has('after_id') ? Value::int($request->query('after_id')) : null;
        $markRead = $afterId === null;

        $result = SupportTickets::messages($ticketId, $afterId, $markRead);

        return ApiResponse::success([
            'ticket' => SupportTickets::find($ticketId, $tenantId),
            'messages' => $result['messages'],
            'last_id' => $result['last_id'],
        ]);
    }

    public function reply(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $ticketId = self::existing($request, $tenantId);
        $ticket = SupportTickets::find($ticketId, $tenantId) ?? [];

        $body = trim(Value::string($request->input('body')));
        $hasAttachment = Value::string($request->input('attachment')) !== '';

        // A screenshot on its own is a complete report, so the body may be
        // empty when something is attached — but a message with neither is not
        // a message.
        if ($body === '' && ! $hasAttachment) {
            throw new ApiFailure('اكتب رسالة أو أرفق ملفًا', 422, 'body_required');
        }

        if (mb_strlen($body) > 5000) {
            throw new ApiFailure('body is too long', 422, 'body_too_long');
        }

        // Answering a closed ticket reopens it: the conversation is plainly not
        // over, and making somebody open a second ticket to say one more thing
        // loses the history.
        if (Value::string($ticket['status'] ?? null) === 'closed') {
            SupportTickets::reopen($ticketId, $tenantId);
        }

        $attachment = null;

        if ($hasAttachment) {
            $attachment = SupportAttachment::store(
                $request->input('attachment'),
                $ticketId,
                Value::nullableString($request->input('attachment_name')),
            );

            if ($attachment === null) {
                throw new ApiFailure(
                    'تعذّر حفظ المرفق — يُقبل صورة أو PDF حتى 5 ميجابايت',
                    422,
                    'attachment_rejected',
                );
            }
        }

        $messageId = SupportTickets::addMessage(
            $ticketId, 'user', $adminId, null, $body,
            $attachment['path'] ?? null, $attachment['name'] ?? null,
        );

        return ApiResponse::success(['message_id' => $messageId, 'message' => 'Reply sent']);
    }

    public function close(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $ticketId = self::existing($request, $tenantId);
        $action = Value::string($request->input('action'));

        if ($action === 'close') {
            SupportTickets::close($ticketId, $tenantId);
            $status = 'closed';
        } elseif ($action === 'reopen') {
            SupportTickets::reopen($ticketId, $tenantId);
            $status = 'pending_support';
        } else {
            throw new ApiFailure('Invalid action. Use "close" or "reopen".', 400, 'invalid_action_close_reopen');
        }

        AuditLog::record($tenantId, $adminId, 'support.ticket.'.$action, 'support_ticket', $ticketId, [
            'new_status' => $status,
        ]);

        return ApiResponse::success(['status' => $status]);
    }

    /**
     * One attachment, to the company that owns the ticket.
     *
     * The ownership check is the point: a message id is a small integer, so
     * without it any company could walk another company's attachments.
     */
    public function attachment(Request $request): Response
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $messageId = Value::int($request->query('message_id'));

        $message = DB::table('support_messages as m')
            ->join('support_tickets as t', 't.id', '=', 'm.ticket_id')
            ->where('m.id', $messageId)->where('t.tenant_id', $tenantId)
            ->first(['m.attachment_url', 'm.attachment_name']);

        $stored = $message === null ? null : Value::nullableString($message->attachment_url);
        $path = SupportAttachment::relativePath($stored);

        if ($path === null || ! Storage::disk('uploads')->exists($path)) {
            throw new ApiFailure('Attachment not found', 404, 'not_found');
        }

        $name = Value::string($message?->attachment_name) ?: basename($path);

        return response(Value::string(Storage::disk('uploads')->get($path)), 200, [
            'Content-Type' => SupportAttachment::mimeFor($path),
            'Content-Disposition' => 'inline; filename="'.addslashes($name).'"',
            'X-Content-Type-Options' => 'nosniff',
            'Cache-Control' => 'private, no-store, max-age=0',
        ]);
    }

    private static function existing(Request $request, int $tenantId, bool $fromQuery = false): int
    {
        $ticketId = $fromQuery
            ? Value::int($request->query('ticket_id'))
            : Value::int($request->input('ticket_id'));

        if ($ticketId <= 0 || SupportTickets::find($ticketId, $tenantId) === null) {
            throw new ApiFailure('Ticket not found', 404, 'not_found');
        }

        return $ticketId;
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $admin;
    }
}
