<?php

declare(strict_types=1);

namespace App\Providers;

use App\Domain\Notifications\PushSender;
use App\Services\Auth\FirebaseAccountManager;
use App\Services\Auth\FirebaseCustomTokenMinter;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Services\Auth\KreaitFirebaseAccountManager;
use App\Services\Auth\KreaitFirebaseCustomTokenMinter;
use App\Services\Auth\KreaitFirebaseTokenVerifier;
use App\Services\Notifications\FirebasePushSender;
use App\Services\RemoteConfig\FirebaseRemoteConfigGate;
use App\Services\RemoteConfig\RemoteConfigGate;
use Illuminate\Contracts\Foundation\Application;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\ServiceProvider;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Contract\RemoteConfig;
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

        $this->app->bind(
            FirebaseCustomTokenMinter::class,
            fn (Application $app): FirebaseCustomTokenMinter => new KreaitFirebaseCustomTokenMinter($app->make(FirebaseAuth::class)),
        );

        $this->app->singleton(Messaging::class, function (): Messaging {
            $path = Config::string('medjat.firebase.credentials_path');

            if ($path === '' || ! is_file($path)) {
                throw new RuntimeException("Firebase credentials not found at: {$path}");
            }

            return (new Factory)->withServiceAccount($path)->createMessaging();
        });

        $this->app->bind(
            PushSender::class,
            fn (Application $app): PushSender => new FirebasePushSender($app->make(Messaging::class)),
        );

        $this->app->bind(
            FirebaseAccountManager::class,
            fn (Application $app): FirebaseAccountManager => new KreaitFirebaseAccountManager($app->make(FirebaseAuth::class)),
        );

        $this->app->singleton(RemoteConfig::class, function (): RemoteConfig {
            $path = Config::string('medjat.firebase.credentials_path');

            if ($path === '' || ! is_file($path)) {
                throw new RuntimeException("Firebase credentials not found at: {$path}");
            }

            return (new Factory)->withServiceAccount($path)->createRemoteConfig();
        });

        $this->app->bind(
            RemoteConfigGate::class,
            fn (Application $app): RemoteConfigGate => new FirebaseRemoteConfigGate($app->make(RemoteConfig::class)),
        );
    }
}
