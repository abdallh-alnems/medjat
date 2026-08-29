<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Domain\Notifications\PushSender;

/**
 * Records pushes instead of sending them, so every endpoint that notifies
 * somebody is testable without Firebase credentials.
 */
final class FakePushSender implements PushSender
{
    /** @var list<array{employee_id: int, title: string, body: string, data: array<string, string>}> */
    public array $sent = [];

    /** @var list<array{admin_id: int, title: string, body: string, data: array<string, string>}> */
    public array $sentToAdmins = [];

    /** Whether delivery should report failure, to prove it is best-effort. */
    public bool $fails = false;

    /**
     * @param  array<string, string>  $data
     */
    public function toEmployee(int $employeeId, string $title, string $body, array $data = []): bool
    {
        if ($this->fails) {
            return false;
        }

        $this->sent[] = ['employee_id' => $employeeId, 'title' => $title, 'body' => $body, 'data' => $data];

        return true;
    }

    /**
     * @param  array<string, string>  $data
     */
    public function toAdmin(int $adminId, string $title, string $body, array $data = []): bool
    {
        if ($this->fails) {
            return false;
        }

        $this->sentToAdmins[] = ['admin_id' => $adminId, 'title' => $title, 'body' => $body, 'data' => $data];

        return true;
    }

    public function lastBody(): ?string
    {
        $last = end($this->sent);

        return $last === false ? null : $last['body'];
    }
}
