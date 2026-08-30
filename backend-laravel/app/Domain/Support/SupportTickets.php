<?php

declare(strict_types=1);

namespace App\Domain\Support;

use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Support conversations between a company and whoever runs this service.
 *
 * A ticket's status is derived from who spoke last rather than set by hand:
 * a message from the company puts it on support's desk, a reply puts it back
 * on the company's. That keeps both inboxes honest without anybody having to
 * remember to move a ticket along.
 */
final class SupportTickets
{
    public const CATEGORIES = ['technical', 'billing', 'feature_request', 'account', 'other'];

    public const PRIORITIES = ['low', 'normal', 'high', 'urgent'];

    public const STATUSES = ['open', 'pending_support', 'pending_user', 'resolved', 'closed'];

    public static function create(
        int $tenantId,
        int $adminId,
        string $subject,
        string $category,
        string $priority,
        string $body,
    ): int {
        return DB::transaction(function () use ($tenantId, $adminId, $subject, $category, $priority, $body): int {
            $ticketId = (int) DB::table('support_tickets')->insertGetId([
                'tenant_id' => $tenantId,
                'opened_by_admin_id' => $adminId,
                'subject' => $subject,
                'category' => $category,
                'priority' => $priority,
                'status' => 'open',
                'unread_for_support' => 1,
                'last_message_at' => DB::raw('NOW()'),
                'last_message_preview' => mb_substr($body, 0, 255),
            ]);

            DB::table('support_messages')->insert([
                'ticket_id' => $ticketId,
                'sender_type' => 'user',
                'sender_admin_id' => $adminId,
                'body' => $body,
            ]);

            return $ticketId;
        });
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $id, int $tenantId): ?array
    {
        $row = DB::table('support_tickets')->where('id', $id)->where('tenant_id', $tenantId)->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * @return array{tickets: list<array<string, mixed>>, total: int, page: int, unread_total: int}
     */
    public static function forTenant(int $tenantId, ?string $status, int $page, int $limit): array
    {
        $base = fn (): QueryBuilder => DB::table('support_tickets')
            ->where('tenant_id', $tenantId)
            ->when(
                $status !== null && in_array($status, self::STATUSES, true),
                fn (QueryBuilder $q): QueryBuilder => $q->where('status', $status)
            );

        $tickets = $base()
            ->orderByDesc('last_message_at')->orderByDesc('created_at')
            ->limit($limit)->offset(($page - 1) * $limit)
            ->get()->all();

        return [
            'tickets' => array_values(array_map(self::toArray(...), $tickets)),
            'total' => $base()->count(),
            'page' => $page,
            // Only live conversations count as waiting: a closed ticket the
            // company never opened is not something anybody needs to act on.
            'unread_total' => DB::table('support_tickets')
                ->where('tenant_id', $tenantId)
                ->where('unread_for_user', 1)
                ->whereNotIn('status', ['closed', 'resolved'])
                ->count(),
        ];
    }

    /**
     * @return array{messages: list<array<string, mixed>>, last_id: int}
     */
    public static function messages(int $ticketId, ?int $afterId = null, bool $markRead = false): array
    {
        if ($markRead) {
            DB::table('support_tickets')->where('id', $ticketId)->update(['unread_for_user' => 0]);
        }

        $rows = DB::table('support_messages')
            ->where('ticket_id', $ticketId)
            ->when($afterId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('id', '>', $afterId))
            ->orderBy('id')
            ->get()->all();

        $messages = array_values(array_map(self::toArray(...), $rows));
        $last = $messages === [] ? null : $messages[count($messages) - 1];

        return [
            'messages' => $messages,
            'last_id' => $last === null ? 0 : Value::int($last['id'] ?? null),
        ];
    }

    /**
     * Adds a message and moves the ticket to whoever now has to answer.
     */
    public static function addMessage(
        int $ticketId,
        string $senderType,
        ?int $senderAdminId,
        ?int $senderSuperAdminId,
        string $body,
        ?string $attachmentUrl = null,
        ?string $attachmentName = null,
    ): int {
        return DB::transaction(function () use (
            $ticketId, $senderType, $senderAdminId, $senderSuperAdminId, $body, $attachmentUrl, $attachmentName
        ): int {
            $messageId = (int) DB::table('support_messages')->insertGetId([
                'ticket_id' => $ticketId,
                'sender_type' => $senderType,
                'sender_admin_id' => $senderAdminId,
                'sender_super_admin_id' => $senderSuperAdminId,
                'body' => $body,
                'attachment_url' => $attachmentUrl,
                'attachment_name' => $attachmentName,
            ]);

            // An attachment-only message still needs something to show in the
            // list, or the thread looks empty from the outside.
            $preview = $body !== ''
                ? mb_substr($body, 0, 255)
                : '📎 '.mb_substr($attachmentName ?? 'مرفق', 0, 250);

            $changes = ['last_message_at' => DB::raw('NOW()'), 'last_message_preview' => $preview];

            if ($senderType === 'user') {
                $changes += ['status' => 'pending_support', 'unread_for_support' => 1, 'unread_for_user' => 0];
            } elseif ($senderType === 'support') {
                $changes += ['status' => 'pending_user', 'unread_for_user' => 1, 'unread_for_support' => 0];
            }

            DB::table('support_tickets')->where('id', $ticketId)->update($changes);

            return $messageId;
        });
    }

    public static function close(int $ticketId, int $tenantId): void
    {
        DB::table('support_tickets')->where('id', $ticketId)->where('tenant_id', $tenantId)
            ->update(['status' => 'closed']);
    }

    public static function reopen(int $ticketId, int $tenantId): void
    {
        DB::table('support_tickets')->where('id', $ticketId)->where('tenant_id', $tenantId)->update([
            'status' => 'pending_support',
            'unread_for_support' => 1,
            'unread_for_user' => 0,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private static function toArray(mixed $row): array
    {
        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }
}
