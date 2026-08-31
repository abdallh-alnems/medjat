<?php

declare(strict_types=1);

namespace Tests\Feature\Mail;

use App\Mail\NewDeviceLoginMail;
use App\Mail\TeamInvitationMail;
use App\Models\Admin;
use App\Models\Employee;
use App\Modules\Notifications\Domain\EmployeeActivationAlert;
use App\Modules\Notifications\Domain\LoginAlert;
use App\Modules\Notifications\Domain\PushSender;
use App\Modules\Team\Domain\ManagerInvitation;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use RuntimeException;
use Tests\Support\CreatesFixtures;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The transactional mail and the two alerts that carry it.
 */
final class TransactionalMailTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    private int $tenantId;

    private FakePushSender $push;

    protected function setUp(): void
    {
        parent::setUp();

        Mail::fake();
        $this->push = new FakePushSender;
        $this->app->instance(PushSender::class, $this->push);

        $this->tenantId = $this->createTenant();
    }

    private function admin(?string $email = 'manager@example.test'): Admin
    {
        $id = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => 'uid-'.bin2hex(random_bytes(6)),
            'tenant_id' => $this->tenantId,
            'email' => $email,
            'name' => 'A manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);

        return Admin::query()->findOrFail($id);
    }

    private function loginAttempt(Admin $admin, string $ip, string $ua, int $success = 1): void
    {
        DB::table('login_attempts')->insert([
            'identifier' => Value::string($admin->getAttribute('email')) ?: 'no-email',
            'identifier_type' => 'email',
            'tenant_id' => $admin->tenant_id,
            'admin_id' => $admin->id,
            'ip' => $ip,
            'user_agent' => $ua,
            'success' => $success,
            'created_at' => DB::raw('NOW()'),
        ]);
    }

    // ── The invitation email ─────────────────────────────────────────────

    public function test_the_invitation_carries_the_code_and_a_join_link(): void
    {
        ManagerInvitation::email('invitee@example.test', 'AB12CD34', 'hr', 'Acme');

        Mail::assertSent(TeamInvitationMail::class, function (TeamInvitationMail $mail): bool {
            $rendered = $mail->render();

            // Both, deliberately: the link can be swallowed by a mail client or
            // an app-less device, and the code can always be typed.
            return $mail->hasTo('invitee@example.test')
                && str_contains($rendered, 'AB12CD34')
                && str_contains($rendered, 'join_team?code=AB12CD34');
        });
    }

    public function test_the_invitation_names_the_role_in_arabic(): void
    {
        ManagerInvitation::email('invitee@example.test', 'CODE1234', 'branch_manager', 'Acme');

        Mail::assertSent(TeamInvitationMail::class, static fn (TeamInvitationMail $mail): bool => str_contains($mail->render(), 'مدير فرع')
            && str_contains($mail->render(), 'Acme'));
    }

    public function test_a_failing_mail_server_never_costs_anybody_their_invitation(): void
    {
        Mail::shouldReceive('to')->andThrow(new RuntimeException('SMTP down'));

        // Reaching the next line is the assertion: email() swallowed it. The
        // invitation row is already committed and the code also comes back in
        // the API response, so a dead mail server must cost nobody theirs.
        $this->expectNotToPerformAssertions();

        ManagerInvitation::email('invitee@example.test', 'CODE1234', 'hr', 'Acme');
    }

    // ── The new-device alert ─────────────────────────────────────────────

    public function test_the_first_ever_sign_in_is_not_reported_as_a_new_device(): void
    {
        $admin = $this->admin();
        $this->loginAttempt($admin, '1.1.1.1', 'Chrome');

        app(LoginAlert::class)->handle($admin, '1.1.1.1', 'Chrome');

        Mail::assertNothingSent();
        $this->assertSame(0, DB::table('notifications')->where('admin_id', $admin->id)->count());
    }

    public function test_a_genuinely_new_device_is_reported_every_way(): void
    {
        $admin = $this->admin();
        $this->loginAttempt($admin, '1.1.1.1', 'Chrome');
        $this->loginAttempt($admin, '9.9.9.9', 'Firefox');

        app(LoginAlert::class)->handle($admin, '9.9.9.9', 'Firefox');

        Mail::assertSent(NewDeviceLoginMail::class, static fn (NewDeviceLoginMail $m): bool => $m->hasTo('manager@example.test') && str_contains($m->render(), '9.9.9.9'));

        $this->assertDatabaseHas('notifications', [
            'admin_id' => $admin->id, 'type' => 'system', 'title' => 'New login',
        ]);
        $this->assertCount(1, $this->push->sentToAdmins);
        $this->assertDatabaseHas('audit_log', [
            'tenant_id' => $this->tenantId, 'action' => 'login.new_device',
        ]);
    }

    public function test_a_device_that_has_signed_in_before_is_not_reported(): void
    {
        $admin = $this->admin();
        $this->loginAttempt($admin, '1.1.1.1', 'Chrome');
        $this->loginAttempt($admin, '1.1.1.1', 'Chrome');

        app(LoginAlert::class)->handle($admin, '1.1.1.1', 'Chrome');

        Mail::assertNothingSent();
    }

    public function test_the_same_new_device_is_reported_once_a_day_not_every_sign_in(): void
    {
        // An alert people learn to ignore is worse than none: this is the one
        // that matters when an account is actually taken.
        $admin = $this->admin();
        $this->loginAttempt($admin, '1.1.1.1', 'Chrome');
        $this->loginAttempt($admin, '9.9.9.9', 'Firefox');

        app(LoginAlert::class)->handle($admin, '9.9.9.9', 'Firefox');
        app(LoginAlert::class)->handle($admin, '9.9.9.9', 'Firefox');

        $this->assertSame(1, DB::table('notifications')
            ->where('admin_id', $admin->id)->where('type', 'system')->count());
    }

    public function test_an_account_with_no_email_still_gets_the_in_app_notice(): void
    {
        $admin = $this->admin(null);
        $this->loginAttempt($admin, '1.1.1.1', 'Chrome');
        $this->loginAttempt($admin, '9.9.9.9', 'Firefox');

        app(LoginAlert::class)->handle($admin, '9.9.9.9', 'Firefox');

        Mail::assertNothingSent();
        $this->assertDatabaseHas('notifications', ['admin_id' => $admin->id, 'type' => 'system']);
    }

    public function test_the_security_notice_offers_nothing_to_click(): void
    {
        // Asking somebody to click something in a security notice is training
        // them to click things in security notices.
        $mail = new NewDeviceLoginMail('2026-08-30 09:00', '9.9.9.9');

        $this->assertStringNotContainsString('<a href', $mail->render());
    }

    // ── The employee activation alert ────────────────────────────────────

    public function test_managers_are_told_when_an_employee_activates(): void
    {
        $manager = $this->admin();
        $employee = $this->employeeFor();

        app(EmployeeActivationAlert::class)->notify($employee, true);

        $this->assertDatabaseHas('notifications', [
            'tenant_id' => $this->tenantId,
            'admin_id' => $manager->id,
            'employee_id' => $employee->id,
            'title' => 'Employee account activated',
        ]);
    }

    public function test_a_later_sign_in_says_so_rather_than_claiming_an_activation(): void
    {
        $manager = $this->admin();
        $employee = $this->employeeFor();

        app(EmployeeActivationAlert::class)->notify($employee, false);

        $this->assertDatabaseHas('notifications', [
            'admin_id' => $manager->id, 'title' => 'Employee signed in',
        ]);
    }

    public function test_the_alert_does_not_go_to_staff_accounts(): void
    {
        $manager = $this->admin();

        $staffAccount = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => 'uid-'.bin2hex(random_bytes(6)),
            'tenant_id' => $this->tenantId,
            'name' => 'A staff account',
            'role' => 'employee',
            'is_active' => 1,
        ]);

        $employee = $this->employeeFor();

        app(EmployeeActivationAlert::class)->notify($employee, true);

        $recipients = array_map(
            static fn (mixed $id): int => Value::int($id),
            DB::table('notifications')->where('employee_id', $employee->id)->pluck('admin_id')->all(),
        );

        // A manager hears about it; a staff account sharing the admins table
        // does not — those are employees, not people who manage them.
        $this->assertContains($manager->id, $recipients);
        $this->assertNotContains($staffAccount, $recipients);
    }

    private function employeeFor(): Employee
    {
        $id = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Newly activated',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
        ]);

        return Employee::query()->findOrFail($id);
    }
}
