<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Exceptions\ApiFailure;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;
use Throwable;

final class KreaitFirebaseCustomTokenMinter implements FirebaseCustomTokenMinter
{
    public function __construct(private readonly FirebaseAuth $auth) {}

    /**
     * @param  array<string, mixed>  $claims
     */
    public function mint(string $uid, array $claims = []): string
    {
        if ($uid === '') {
            throw new ApiFailure('تعذّر إنشاء رمز الدخول', 500);
        }

        // Claim keys reach Firebase as JSON object keys, so an empty one would
        // produce a malformed token rather than a rejected request.
        $claims = array_filter($claims, static fn (string $key): bool => $key !== '', ARRAY_FILTER_USE_KEY);

        try {
            return $this->auth->createCustomToken($uid, $claims)->toString();
        } catch (Throwable $e) {
            Log::error('Desktop sign-in token failed', ['uid' => $uid, 'exception' => $e]);
            throw new ApiFailure('تعذّر إنشاء رمز الدخول', 500);
        }
    }
}
