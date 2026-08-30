<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Exceptions\ApiFailure;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Services\Auth\VerifiedFirebaseUser;

/**
 * Stands in for Firebase in tests and in CI.
 *
 * Anything not issued here behaves like a forged or expired token. This is the
 * whole reason the verifier is an interface — without it not a single
 * administrator endpoint could be covered without service-account credentials
 * and a network call.
 */
final class FakeFirebaseTokenVerifier implements FirebaseTokenVerifier
{
    /** @var array<string, VerifiedFirebaseUser> */
    private array $valid = [];

    public function issue(string $uid, ?string $email = null, ?string $name = null, ?string $token = null): string
    {
        $token = $token ?? 'fake-token-'.$uid;
        $this->valid[$token] = new VerifiedFirebaseUser($uid, $email, $name);

        return $token;
    }

    public function verify(string $idToken): VerifiedFirebaseUser
    {
        if ($idToken === '') {
            throw new ApiFailure('Token is required', 400);
        }

        if (! isset($this->valid[$idToken])) {
            throw new ApiFailure('Invalid or expired token', 401);
        }

        return $this->valid[$idToken];
    }
}
