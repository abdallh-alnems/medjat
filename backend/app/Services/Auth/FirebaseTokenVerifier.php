<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Exceptions\ApiFailure;

/**
 * Turns a Firebase ID token into the uid it belongs to.
 *
 * An interface rather than a direct call into the SDK so the whole admin
 * authentication path is testable: the old backend's Auth::verifyFirebaseToken()
 * reached straight for Firebase, which meant no test could exercise a single
 * endpoint behind it without real service-account credentials and a network. CI
 * binds the fake; production binds the SDK.
 */
interface FirebaseTokenVerifier
{
    /**
     * @return VerifiedFirebaseUser The verified identity.
     *
     * @throws ApiFailure When the token is missing, malformed, expired or forged.
     */
    public function verify(string $idToken): VerifiedFirebaseUser;
}
