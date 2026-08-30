<?php

declare(strict_types=1);

namespace App\Modules\Auth\Services;

/**
 * Firebase account operations that are not about verifying a token.
 *
 * Behind an interface for the same reason as the rest of this namespace: none of
 * the endpoints that use them could otherwise be tested without live
 * service-account credentials.
 */
interface FirebaseAccountManager
{
    /**
     * Removes the Firebase user.
     *
     * Best-effort by contract: it is called after the database row is already
     * gone, and a failure here must not resurrect an account the person asked to
     * delete. Returns whether it succeeded so the caller can log it.
     */
    public function deleteUser(string $uid): bool;

    /**
     * A password-reset link for this address.
     *
     * Returns null when there is no such account. Callers must respond
     * identically either way — revealing which addresses are registered is the
     * enumeration leak this endpoint exists to avoid.
     */
    public function passwordResetLink(string $email): ?string;

    /**
     * An email-verification link for this address, or null if there is no such
     * account. Same non-disclosure rule as above.
     */
    public function emailVerificationLink(string $email): ?string;
}
