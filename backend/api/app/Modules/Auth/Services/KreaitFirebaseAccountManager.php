<?php

declare(strict_types=1);

namespace App\Modules\Auth\Services;

use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;
use Throwable;

final class KreaitFirebaseAccountManager implements FirebaseAccountManager
{
    public function __construct(private readonly FirebaseAuth $auth) {}

    public function deleteUser(string $uid): bool
    {
        if ($uid === '') {
            // An account that was never bound to Firebase — invited but never
            // signed in. Nothing to remove, and nothing went wrong.
            return true;
        }

        try {
            $this->auth->deleteUser($uid);

            return true;
        } catch (Throwable $e) {
            // The database row is already gone by the time this runs. Leaving a
            // stray Firebase user behind is untidy; failing the request would
            // tell someone their deletion did not work when it did.
            Log::warning('Firebase user deletion failed', ['uid' => $uid, 'exception' => $e]);

            return false;
        }
    }

    public function passwordResetLink(string $email): ?string
    {
        if ($email === '') {
            return null;
        }

        return $this->link(fn (): string => $this->auth->getPasswordResetLink($email));
    }

    public function emailVerificationLink(string $email): ?string
    {
        if ($email === '') {
            return null;
        }

        return $this->link(fn (): string => $this->auth->getEmailVerificationLink($email));
    }

    /**
     * user-not-found and its neighbours are swallowed on purpose: the caller has
     * to behave identically for a registered and an unregistered address.
     *
     * @param  callable(): string  $generate
     */
    private function link(callable $generate): ?string
    {
        try {
            return $generate();
        } catch (Throwable $e) {
            Log::debug('Firebase action link not generated', ['exception' => $e->getMessage()]);

            return null;
        }
    }
}
