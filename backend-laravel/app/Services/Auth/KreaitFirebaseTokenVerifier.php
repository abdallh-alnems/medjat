<?php

declare(strict_types=1);

namespace App\Services\Auth;

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

    public function verify(string $idToken): string
    {
        if ($idToken === '') {
            throw new ApiFailure('Token is required', 400);
        }

        try {
            // 60 seconds of leeway for clock skew between the handset and here,
            // matching the old backend. Signature checking stays on.
            $verified = $this->auth->verifyIdToken($idToken, false, 60);
        } catch (FailedToVerifyToken) {
            throw new ApiFailure('Invalid or expired token', 401);
        } catch (Throwable $e) {
            // A misconfigured service account and a forged token must not look
            // alike to the caller: this is ours, so it is a 500 and it is logged.
            Log::error('Firebase token verification failed', ['exception' => $e]);
            throw new ApiFailure('Authentication failed', 500);
        }

        $uid = $verified->claims()->get('sub');

        if (! is_string($uid) || $uid === '') {
            throw new ApiFailure('Invalid or expired token', 401);
        }

        return $uid;
    }
}
