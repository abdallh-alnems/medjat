<?php

declare(strict_types=1);

namespace App\Providers;

use App\Services\Auth\FirebaseTokenVerifier;
use App\Services\Auth\KreaitFirebaseTokenVerifier;
use Illuminate\Contracts\Foundation\Application;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\ServiceProvider;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;
use Kreait\Firebase\Factory;
use RuntimeException;

final class FirebaseServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(FirebaseAuth::class, function (): FirebaseAuth {
            $path = Config::string('medjat.firebase.credentials_path');

            if ($path === '' || ! is_file($path)) {
                // The old backend logged this and returned null, so the first
                // sign-in attempt died on a null dereference somewhere further
                // in. Failing here names the actual problem.
                throw new RuntimeException("Firebase credentials not found at: {$path}");
            }

            return (new Factory)->withServiceAccount($path)->createAuth();
        });

        // Resolved lazily: a request that never authenticates an administrator
        // must not need Firebase credentials to be present at all.
        $this->app->bind(
            FirebaseTokenVerifier::class,
            fn (Application $app): FirebaseTokenVerifier => new KreaitFirebaseTokenVerifier($app->make(FirebaseAuth::class)),
        );
    }
}
