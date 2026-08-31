<?php

declare(strict_types=1);

namespace App\Modules\Auth\Services;

use App\Exceptions\ApiFailure;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;
use Kreait\Firebase\Exception\Auth\FailedToVerifyToken;
use Throwable;

/**
 * The production verifier, backed by the Firebase Admin SDK.
 */
final class KreaitFirebaseTokenVerifier implements FirebaseTokenVerifier
{
    public function __construct(private readonly FirebaseAuth $auth) {}

    public function verify(string $idToken): VerifiedFirebaseUser
    {
        if ($idToken === '') {
            throw new ApiFailure('Token is required', 400);
        }

        try {
            // 60 seconds of leeway for clock skew between the handset and here,
            // matching the old backend. Signature checking stays on.
            $verified = $this->auth->verifyIdToken($idToken, false, 60);
        } catch (FailedToVerifyToken) {
            throw new ApiFailure(__('messages.token_invalid_or_expired'), 401);
        } catch (Throwable $e) {
            // A misconfigured service account and a forged token must not look
            // alike to the caller: this is ours, so it is a 500 and it is logged.
            Log::error('Firebase token verification failed', ['exception' => $e]);
            throw new ApiFailure(__('messages.authentication_failed'), 500);
        }

        $claims = $verified->claims();
        $uid = $claims->get('sub');

        if (! is_string($uid) || $uid === '') {
            throw new ApiFailure(__('messages.token_invalid_or_expired'), 401);
        }

        $email = $claims->get('email');
        $name = $claims->get('name');

        return new VerifiedFirebaseUser(
            uid: $uid,
            email: is_string($email) && $email !== '' ? $email : null,
            name: is_string($name) && $name !== '' ? $name : null,
        );
    }
}
