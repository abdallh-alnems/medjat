<?php

declare(strict_types=1);

namespace App\Modules\Auth\Services;

/**
 * What a verified Firebase ID token tells us about the person holding it.
 *
 * Only the uid is guaranteed. Email is absent for some providers, and the
 * display name is absent whenever the account was created without one — which
 * is why sign-in falls back to the local part of the email and then to a
 * placeholder rather than treating either as required.
 */
final readonly class VerifiedFirebaseUser
{
    public function __construct(
        public string $uid,
        public ?string $email = null,
        public ?string $name = null,
    ) {}

    /**
     * The best name available: the provider's display name, else the local part
     * of the email address, else a placeholder the person can correct later.
     */
    public function displayName(): string
    {
        $name = trim((string) $this->name);
        if ($name !== '') {
            return $name;
        }

        if ($this->email !== null && str_contains($this->email, '@')) {
            $local = strstr($this->email, '@', true);
            if (is_string($local) && $local !== '') {
                return $local;
            }
        }

        return 'Admin';
    }
}
