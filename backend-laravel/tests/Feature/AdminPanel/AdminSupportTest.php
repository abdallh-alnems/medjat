<?php

declare(strict_types=1);

namespace Tests\Feature\AdminPanel;

use App\Domain\Notifications\PushSender;
use App\Domain\SuperAdmin\SuperAdminSession;
use App\Domain\Support\SupportTickets;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The support desk's side of a ticket.
 */
final class AdminSupportTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $companyAdminId;

    private int $ticketId;

    private int $operatorId;

    private FakePushSender $push;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();

        $this->push = new FakePushSender;
        $this->app->instance(PushSender::class, $this->push);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        $this->companyAdminId = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => 'uid-'.bin2hex(random_bytes(6)),
            'tenant_id' => $this->tenantId,
            'name' => 'Company manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);

        $this->ticketId = SupportTickets::create(
            $this->tenantId, $this->companyAdminId, 'Payroll question', 'other', 'normal',
            'The net salary on this month\'s payslip looks wrong.',
        );

        [$this->operatorId, $this->token] = $this->operator('admin');
    }

    /**
     * @return array{0: int, 1: string}
     */
    private function operator(string $role): array
    {
        $id = (int) DB::table('super_admins')->insertGetId([
            'username' => 'op-'.bin2hex(random_bytes(5)),
            // Cheapest cost the algorithm allows: nothing here verifies it,
            // and the default cost adds seconds across a suite this size.
            'password_hash' => password_hash('irrelevant', PASSWORD_BCRYPT, ['cost' => 4]),
            'display_name' => 'Operator '.$role,
            'role' => $role,
            'is_active' => 1,
        ]);

        return [$id, SuperAdminSession::open($id, '127.0.0.1', 'phpunit')['token']];
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function send(string $path, array $payload = [], ?string $token = null): TestResponse
    {
        return $this->withHeader('Authorization', 'Bearer '.($token ?? $this->token))->postJson($path, $payload);
    }

    /**
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function read(string $path, ?string $token = null): TestResponse
    {
        return $this->withHeader('Authorization', 'Bearer '.($token ?? $this->token))->getJson($path);
    }

    public function test_the_queue_spans_every_company(): void
    {
        // Looking across companies is the whole point of the desk.
        $this->read('/app/admin_support/list.php')
            ->assertOk()
            ->assertJsonPath('data.page', 1)
            ->assertJsonStructure(['data' => ['tickets', 'total', 'page']]);
    }

    public function test_each_ticket_names_the_company_it_came_from(): void
    {
        $response = $this->read('/app/admin_support/list.php?tenant_id='.$this->tenantId)->assertOk();

        /** @var list<array<string, mixed>> $tickets */
        $tickets = (array) $response->json('data.tickets');
        $this->assertNotEmpty($tickets);
        $this->assertArrayHasKey('tenant_name', $tickets[0]);
    }

    public function test_the_queue_can_be_filtered_by_status(): void
    {
        SupportTickets::setStatus($this->ticketId, 'closed');

        $open = $this->read('/app/admin_support/list.php?status=pending_support')->assertOk();
        $closed = $this->read('/app/admin_support/list.php?status=closed')->assertOk();

        $this->assertNotSame(
            Value::int($open->json('data.total')),
            Value::int($closed->json('data.total')),
        );
    }

    public function test_opening_a_thread_marks_it_read_for_the_desk(): void
    {
        $this->assertSame(1, Value::int(
            DB::table('support_tickets')->where('id', $this->ticketId)->value('unread_for_support')
        ));

        $this->read('/app/admin_support/messages.php?ticket_id='.$this->ticketId)
            ->assertOk()
            ->assertJsonCount(1, 'data.messages');

        $this->assertSame(0, Value::int(
            DB::table('support_tickets')->where('id', $this->ticketId)->value('unread_for_support')
        ));
    }

    public function test_polling_for_new_messages_does_not_mark_it_read(): void
    {
        // Asking what is new does not mean anybody read the thread; opening it
        // does.
        $this->read('/app/admin_support/messages.php?ticket_id='.$this->ticketId.'&after_id=0')->assertOk();

        $this->assertSame(1, Value::int(
            DB::table('support_tickets')->where('id', $this->ticketId)->value('unread_for_support')
        ));
    }

    public function test_a_reply_moves_the_ticket_to_the_company(): void
    {
        $this->send('/app/admin_support/reply.php', [
            'ticket_id' => $this->ticketId,
            'body' => 'Checked it — the deduction is a loan installment.',
        ])->assertOk()->assertJsonPath('data.status', 'pending_user');

        $this->assertDatabaseHas('support_messages', [
            'ticket_id' => $this->ticketId,
            'sender_type' => 'support',
            'sender_super_admin_id' => $this->operatorId,
        ]);
    }

    public function test_a_reply_tells_the_person_who_opened_the_ticket(): void
    {
        $this->send('/app/admin_support/reply.php', [
            'ticket_id' => $this->ticketId,
            'body' => 'Looking into it now.',
        ])->assertOk();

        $this->assertDatabaseHas('notifications', [
            'admin_id' => $this->companyAdminId,
            'type' => 'support',
            // The desk's thread with one person, not the company's own feed.
            'tenant_id' => null,
        ]);
        $this->assertCount(1, $this->push->sentToAdmins);
    }

    public function test_a_message_with_neither_text_nor_attachment_is_refused(): void
    {
        $this->send('/app/admin_support/reply.php', ['ticket_id' => $this->ticketId, 'body' => '  '])
            ->assertStatus(422);
    }

    public function test_an_attachment_alone_is_a_complete_answer(): void
    {
        Storage::fake('uploads');

        $png = base64_encode((string) file_get_contents(
            'data://image/png;base64,'
            .'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
        ));

        $this->send('/app/admin_support/reply.php', [
            'ticket_id' => $this->ticketId,
            'body' => '',
            'attachment' => $png,
            'attachment_name' => 'screenshot.png',
        ])->assertOk();

        $this->assertDatabaseHas('support_messages', [
            'ticket_id' => $this->ticketId,
            'attachment_name' => 'screenshot.png',
        ]);
    }

    public function test_an_overlong_message_is_refused(): void
    {
        $this->send('/app/admin_support/reply.php', [
            'ticket_id' => $this->ticketId,
            'body' => str_repeat('ا', 5001),
        ])->assertStatus(422);
    }

    public function test_a_reply_to_an_unknown_ticket_is_a_404(): void
    {
        $this->send('/app/admin_support/reply.php', ['ticket_id' => 99999999, 'body' => 'Hello?'])
            ->assertStatus(404);
    }

    public function test_a_ticket_can_be_resolved_and_reopened(): void
    {
        $this->send('/app/admin_support/status.php', ['ticket_id' => $this->ticketId, 'status' => 'resolved'])
            ->assertOk()
            ->assertJsonPath('data.status', 'resolved');

        // Reopening puts the ball back in the desk's court, which is what
        // pending_support means — there is no separate "reopened" state.
        $this->send('/app/admin_support/status.php', ['ticket_id' => $this->ticketId, 'status' => 'reopen'])
            ->assertOk()
            ->assertJsonPath('data.status', 'pending_support');
    }

    public function test_a_status_change_is_audited_with_what_it_was(): void
    {
        $this->send('/app/admin_support/status.php', ['ticket_id' => $this->ticketId, 'status' => 'closed'])
            ->assertOk();

        $payload = json_decode(Value::string(DB::table('super_admin_audit_log')
            ->where('action', 'support.status')->orderByDesc('id')->value('payload')), true);

        $this->assertIsArray($payload);
        $this->assertSame('open', $payload['from'] ?? null);
        $this->assertSame('closed', $payload['to'] ?? null);
    }

    public function test_an_arbitrary_status_cannot_be_set(): void
    {
        $this->send('/app/admin_support/status.php', ['ticket_id' => $this->ticketId, 'status' => 'urgent'])
            ->assertStatus(422);
    }

    public function test_an_attachment_is_served_only_to_a_live_session(): void
    {
        Storage::fake('uploads');
        Storage::disk('uploads')->put('support/'.$this->ticketId.'/note.pdf', '%PDF-1.4 test');

        $messageId = SupportTickets::addMessage(
            $this->ticketId, 'support', null, $this->operatorId, 'See attached',
            'uploads/support/'.$this->ticketId.'/note.pdf', 'note.pdf',
        );

        $this->read('/app/admin_support/attachment.php?message_id='.$messageId)
            ->assertOk()
            ->assertHeader('Content-Type', 'application/pdf');

        // A leaked URL is worthless without a session: a client's screenshot
        // can hold payroll figures or staff faces.
        $this->flushHeaders();
        $this->getJson('/app/admin_support/attachment.php?message_id='.$messageId)->assertStatus(401);
    }

    public function test_a_message_with_no_attachment_is_a_404(): void
    {
        $messageId = SupportTickets::addMessage(
            $this->ticketId, 'support', null, $this->operatorId, 'Text only',
        );

        $this->read('/app/admin_support/attachment.php?message_id='.$messageId)->assertStatus(404);
    }

    public function test_a_readonly_operator_cannot_reply(): void
    {
        [, $token] = $this->operator('readonly');

        $this->send('/app/admin_support/reply.php', [
            'ticket_id' => $this->ticketId, 'body' => 'Should not land',
        ], $token)->assertStatus(403);

        $this->read('/app/admin_support/list.php', $token)->assertStatus(403);
    }
}
