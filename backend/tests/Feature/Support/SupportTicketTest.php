<?php

declare(strict_types=1);

namespace Tests\Feature\Support;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Modules\Support\Domain\SupportTickets;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * A company talking to whoever runs the service.
 */
final class SupportTicketTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private string $adminToken;

    private string $viewerToken;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('uploads');

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        DB::table('support_tickets')->where('tenant_id', $this->tenantId)->delete();

        $this->adminToken = $this->admin($firebase, 'general_manager');
        $this->viewerToken = $this->admin($firebase, 'viewer');
    }

    private function admin(FakeFirebaseTokenVerifier $firebase, string $role): string
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Admin '.$role,
            'role' => $role,
            'is_active' => 1,
        ]);

        return $firebase->issue($uid);
    }

    /**
     * @return array{0: int, 1: int}
     */
    private function otherCompany(): array
    {
        $tenantId = Value::int(DB::table('tenants')->where('id', '!=', $this->tenantId)->value('id'));
        $adminId = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => 'uid-'.bin2hex(random_bytes(6)),
            'tenant_id' => $tenantId,
            'name' => 'Somebody else',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);

        return [$tenantId, $adminId];
    }

    private function asAdmin(): self
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken);

        return $this;
    }

    private function opened(string $subject = 'Cannot print payslips'): int
    {
        $response = $this->asAdmin()->postJson('/v1/support/tickets', [
            'subject' => $subject,
            'body' => 'The download button does nothing.',
            'category' => 'technical',
            'priority' => 'high',
        ])->assertStatus(201);

        return Value::int($response->json('data.ticket_id'));
    }

    /** A one-pixel PNG, so the attachment is judged from real bytes. */
    private function png(): string
    {
        return 'data:image/png;base64,'.base64_encode(
            (string) base64_decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
                true
            )
        );
    }

    // ── Opening ──────────────────────────────────────────────────────────

    public function test_a_ticket_starts_with_its_first_message_on_support_desk(): void
    {
        $id = $this->opened();

        $this->assertDatabaseHas('support_tickets', [
            'id' => $id,
            'tenant_id' => $this->tenantId,
            'status' => 'open',
            'unread_for_support' => 1,
        ]);
        $this->assertDatabaseHas('support_messages', ['ticket_id' => $id, 'sender_type' => 'user']);
    }

    public function test_a_ticket_needs_a_subject_and_a_body(): void
    {
        $this->asAdmin()->postJson('/v1/support/tickets', ['body' => 'No subject'])
            ->assertStatus(422)->assertJsonPath('error_code', 'subject_required');

        $this->asAdmin()->postJson('/v1/support/tickets', ['subject' => 'No body'])
            ->assertStatus(422)->assertJsonPath('error_code', 'body_required');
    }

    public function test_an_unknown_category_is_refused(): void
    {
        $this->asAdmin()->postJson('/v1/support/tickets', [
            'subject' => 'Hello',
            'body' => 'Hi',
            'category' => 'philosophy',
        ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_category');
    }

    // ── The conversation ─────────────────────────────────────────────────

    public function test_a_reply_puts_the_ticket_back_on_support_desk(): void
    {
        // Status follows who spoke last, so neither inbox needs anybody to
        // remember to move a ticket along.
        $id = $this->opened();
        DB::table('support_tickets')->where('id', $id)->update(['status' => 'pending_user']);

        $this->asAdmin()->postJson('/v1/support/reply', ['ticket_id' => $id, 'body' => 'Still broken'])
            ->assertOk();

        $this->assertDatabaseHas('support_tickets', [
            'id' => $id,
            'status' => 'pending_support',
            'unread_for_support' => 1,
            'unread_for_user' => 0,
        ]);
    }

    public function test_a_message_with_neither_text_nor_attachment_is_not_a_message(): void
    {
        $id = $this->opened();

        $this->asAdmin()->postJson('/v1/support/reply', ['ticket_id' => $id, 'body' => '   '])
            ->assertStatus(422)->assertJsonPath('error_code', 'body_required');
    }

    public function test_a_screenshot_on_its_own_is_a_complete_report(): void
    {
        $id = $this->opened();

        $this->asAdmin()->postJson('/v1/support/reply', [
            'ticket_id' => $id,
            'attachment' => $this->png(),
            'attachment_name' => 'broken.png',
        ])->assertOk();

        $this->assertDatabaseHas('support_messages', [
            'ticket_id' => $id,
            'attachment_name' => 'broken.png',
        ]);

        // An attachment-only message still shows something in the list, or the
        // thread looks empty from the outside.
        $preview = Value::string(DB::table('support_tickets')->where('id', $id)->value('last_message_preview'));
        $this->assertStringContainsString('broken.png', $preview);
    }

    public function test_an_unusable_attachment_is_refused_rather_than_stored(): void
    {
        $id = $this->opened();

        $this->asAdmin()->postJson('/v1/support/reply', [
            'ticket_id' => $id,
            'attachment' => 'data:text/plain;base64,'.base64_encode('not an image'),
        ])->assertStatus(422)->assertJsonPath('error_code', 'attachment_rejected');
    }

    public function test_a_stored_filename_is_ours_not_the_uploaders(): void
    {
        // A filename supplied by a client must never become a path.
        $id = $this->opened();

        $this->asAdmin()->postJson('/v1/support/reply', [
            'ticket_id' => $id,
            'attachment' => $this->png(),
            'attachment_name' => '../../etc/passwd',
        ])->assertOk();

        $stored = Value::string(
            DB::table('support_messages')->where('ticket_id', $id)->orderByDesc('id')->value('attachment_url')
        );
        $name = Value::string(
            DB::table('support_messages')->where('ticket_id', $id)->orderByDesc('id')->value('attachment_name')
        );

        $this->assertStringStartsWith('uploads/support/ticket_', $stored);
        $this->assertStringNotContainsString('..', $stored);
        $this->assertStringNotContainsString('/', $name);
    }

    public function test_answering_a_closed_ticket_reopens_it(): void
    {
        // The conversation is plainly not over, and making somebody open a
        // second ticket to say one more thing loses the history.
        $id = $this->opened();
        $this->asAdmin()->postJson('/v1/support/close', ['ticket_id' => $id, 'action' => 'close'])->assertOk();

        $this->asAdmin()->postJson('/v1/support/reply', ['ticket_id' => $id, 'body' => 'It happened again'])
            ->assertOk();

        $this->assertDatabaseHas('support_tickets', ['id' => $id, 'status' => 'pending_support']);
    }

    public function test_reading_the_thread_marks_it_read_but_polling_does_not(): void
    {
        // A poll is not somebody looking at the screen.
        $id = $this->opened();
        $lastId = Value::int(DB::table('support_messages')->where('ticket_id', $id)->value('id'));
        DB::table('support_tickets')->where('id', $id)->update(['unread_for_user' => 1]);

        $this->asAdmin()->getJson('/v1/support/messages?ticket_id='.$id.'&after_id='.$lastId)
            ->assertOk()
            ->assertJsonPath('data.messages', []);

        $this->assertDatabaseHas('support_tickets', ['id' => $id, 'unread_for_user' => 1]);

        $this->asAdmin()->getJson('/v1/support/messages?ticket_id='.$id)
            ->assertOk()
            ->assertJsonPath('data.last_id', $lastId);

        $this->assertDatabaseHas('support_tickets', ['id' => $id, 'unread_for_user' => 0]);
    }

    // ── Closing ──────────────────────────────────────────────────────────

    public function test_a_ticket_is_closed_and_reopened(): void
    {
        $id = $this->opened();

        $this->asAdmin()->postJson('/v1/support/close', ['ticket_id' => $id, 'action' => 'close'])
            ->assertOk()->assertJsonPath('data.status', 'closed');

        $this->asAdmin()->postJson('/v1/support/close', ['ticket_id' => $id, 'action' => 'reopen'])
            ->assertOk()->assertJsonPath('data.status', 'pending_support');
    }

    public function test_an_unknown_action_is_refused(): void
    {
        $id = $this->opened();

        $this->asAdmin()->postJson('/v1/support/close', ['ticket_id' => $id, 'action' => 'burn'])
            ->assertStatus(400)->assertJsonPath('error_code', 'invalid_action_close_reopen');
    }

    // ── Listing and isolation ────────────────────────────────────────────

    public function test_the_unread_count_ignores_conversations_that_are_over(): void
    {
        // A closed ticket the company never opened is not something anybody
        // needs to act on.
        $open = $this->opened('Still open');
        $closed = $this->opened('Finished');
        DB::table('support_tickets')->whereIn('id', [$open, $closed])->update(['unread_for_user' => 1]);
        DB::table('support_tickets')->where('id', $closed)->update(['status' => 'closed']);

        $this->asAdmin()->getJson('/v1/support/tickets')
            ->assertOk()
            ->assertJsonPath('data.unread_total', 1);
    }

    public function test_a_ticket_from_another_company_is_not_found(): void
    {
        [$otherTenant, $otherAdmin] = $this->otherCompany();
        $id = SupportTickets::create($otherTenant, $otherAdmin, 'Elsewhere', 'other', 'normal', 'Body');

        $this->asAdmin()->getJson('/v1/support/messages?ticket_id='.$id)->assertNotFound();
    }

    public function test_an_attachment_belonging_to_another_company_is_not_served(): void
    {
        // A message id is a small integer, so without the ownership check any
        // company could walk another company's attachments.
        [$otherTenant, $otherAdmin] = $this->otherCompany();
        $ticketId = SupportTickets::create($otherTenant, $otherAdmin, 'Elsewhere', 'other', 'normal', 'Body');

        $messageId = Value::int(DB::table('support_messages')->where('ticket_id', $ticketId)->value('id'));
        DB::table('support_messages')->where('id', $messageId)
            ->update(['attachment_url' => 'uploads/support/theirs.png', 'attachment_name' => 'theirs.png']);
        Storage::disk('uploads')->put('support/theirs.png', 'not yours');

        $this->asAdmin()->getJson('/v1/support/attachment?message_id='.$messageId)->assertNotFound();
    }

    public function test_an_attachment_is_served_to_the_company_that_owns_it(): void
    {
        $id = $this->opened();
        $this->asAdmin()->postJson('/v1/support/reply', [
            'ticket_id' => $id,
            'attachment' => $this->png(),
            'attachment_name' => 'shot.png',
        ])->assertOk();

        $messageId = Value::int(
            DB::table('support_messages')->where('ticket_id', $id)->orderByDesc('id')->value('id')
        );

        $this->asAdmin()->get('/v1/support/attachment?message_id='.$messageId)
            ->assertOk()
            ->assertHeader('Content-Type', 'image/png')
            ->assertHeader('X-Content-Type-Options', 'nosniff');
    }

    public function test_support_is_closed_without_the_permission(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/v1/support/tickets')->assertForbidden();
    }
}
