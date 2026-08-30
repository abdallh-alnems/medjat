<?php

declare(strict_types=1);

namespace Tests\Feature\Reports;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * A real .docx built from the table the client already has on screen.
 */
final class WordExportTest extends TestCase
{
    use DatabaseTransactions;

    private const ENDPOINT = '/app/reports/export_word.php';

    private int $tenantId;

    private FakeFirebaseTokenVerifier $firebase;

    private string $adminToken;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        $this->adminToken = $this->admin('general_manager');
    }

    private function admin(string $role): string
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Admin '.$role,
            'role' => $role,
            'is_active' => 1,
        ]);

        return $this->firebase->issue($uid);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return TestResponse<\Symfony\Component\HttpFoundation\StreamedResponse>
     */
    private function export(array $overrides = [], ?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)
            ->postJson(self::ENDPOINT, $overrides + [
                'title' => 'تقرير الحضور',
                'headers' => ['الموظف', 'الحضور', 'التأخير'],
                'rows' => [['أحمد', '22', '3'], ['سارة', '20', '0']],
            ]);
    }

    public function test_the_export_is_a_real_word_document(): void
    {
        $response = $this->export()
            ->assertOk()
            ->assertHeader(
                'Content-Type',
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            );

        // A .docx is a zip. Serving HTML under the extension is what produces
        // Word's "format and extension don't match" warning.
        $this->assertStringStartsWith('PK', $response->streamedContent());
    }

    public function test_an_arabic_title_survives_into_the_filename(): void
    {
        // Letters in any script, so an Arabic report does not arrive as a row
        // of underscores.
        $this->export()
            ->assertOk()
            ->assertHeader('Content-Disposition', 'attachment; filename="تقرير_الحضور.docx"');
    }

    public function test_a_title_that_reduces_to_nothing_still_gets_a_name(): void
    {
        $this->export(['title' => '!!!'])
            ->assertOk()
            ->assertHeader('Content-Disposition', 'attachment; filename="_.docx"');
    }

    public function test_the_optional_company_and_subtitle_are_accepted(): void
    {
        $this->export([
            'company' => 'شركة مجات',
            'subtitle' => 'أغسطس 2026',
        ])->assertOk();
    }

    public function test_a_left_to_right_report_is_accepted(): void
    {
        $this->export(['dir' => 'ltr'])->assertOk();
    }

    public function test_a_report_with_no_headers_is_refused(): void
    {
        $this->export(['headers' => []])->assertStatus(422);
        $this->export(['headers' => 'الموظف'])->assertStatus(422);
    }

    public function test_a_report_with_no_rows_is_still_a_document(): void
    {
        // An empty result is a legitimate answer — "nobody was late" — and the
        // header row alone says so.
        $this->export(['rows' => []])->assertOk();
    }

    public function test_an_oversized_report_is_refused_rather_than_exhausting_memory(): void
    {
        $this->export(['headers' => array_fill(0, 41, 'ع')])->assertStatus(413);
        $this->export(['rows' => array_fill(0, 10001, ['أ', 'ب', 'ج'])])->assertStatus(413);
    }

    public function test_a_short_row_still_produces_a_full_width_one(): void
    {
        // Driven by the headers rather than the row, so the table cannot go
        // ragged halfway down.
        $this->export(['rows' => [['أحمد'], ['سارة', '20', '0']]])->assertOk();
    }

    public function test_a_row_that_is_not_a_row_is_skipped(): void
    {
        $this->export(['rows' => ['not-a-row', ['سارة', '20', '0']]])->assertOk();
    }

    public function test_exporting_needs_the_permission_that_shows_the_report(): void
    {
        $this->export([], $this->admin('attendance'))->assertStatus(403);
    }

    public function test_an_unauthenticated_export_is_refused(): void
    {
        // 400, as the original answered a missing token — the published app
        // bundles distinguish it from a rejected one.
        $this->flushHeaders();
        $this->postJson(self::ENDPOINT, ['headers' => ['a'], 'rows' => []])->assertStatus(400);
    }
}
