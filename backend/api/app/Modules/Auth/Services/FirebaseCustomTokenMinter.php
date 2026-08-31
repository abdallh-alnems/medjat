<?php

declare(strict_types=1);

namespace App\Modules\Auth\Services;

use App\Exceptions\ApiFailure;

/**
 * Mints a Firebase custom token for a uid.
 *
 * The desktop shell trades one for a real session through
 * signInWithCustomToken — the same mechanism the support-desk impersonation
 * link uses. Behind an interface for the same reason as the verifier: otherwise
 * nothing on this path can be tested without live credentials.
 */
interface FirebaseCustomTokenMinter
{
    /**
     * @param  array<string, mixed>  $claims  Extra claims embedded in the token.
     *
     * @throws ApiFailure When the token cannot be minted.
     */
    public function mint(string $uid, array $claims = []): string;
}
