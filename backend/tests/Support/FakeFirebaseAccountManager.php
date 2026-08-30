<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Services\Auth\FirebaseAccountManager;
use App\Services\Auth\FirebaseCustomTokenMinter;

/**
 * Firebase account operations, recorded rather than performed.
 */
final class FakeFirebaseAccountManager implements FirebaseAccountManager, FirebaseCustomTokenMinter
{
    /** @var list<string> */
    public array $deletedUids = [];

    /** @var array<string, string> email => link */
    private array $accounts = [];

    /** Whether deleteUser should report failure, to prove it is best-effort. */
    public bool $deletionFails = false;

    public function register(string $email, string $link = 'https://firebase.test/action?oobCode=abc'): void
    {
        $this->accounts[$email] = $link;
    }

    public function deleteUser(string $uid): bool
    {
        if ($this->deletionFails) {
            return false;
        }

        $this->deletedUids[] = $uid;

        return true;
    }

    public function passwordResetLink(string $email): ?string
    {
        return $this->accounts[$email] ?? null;
    }

    public function emailVerificationLink(string $email): ?string
    {
        return $this->accounts[$email] ?? null;
    }

    /**
     * @param  array<string, mixed>  $claims
     */
    public function mint(string $uid, array $claims = []): string
    {
        return 'custom-token:'.$uid.':'.json_encode($claims);
    }
}
