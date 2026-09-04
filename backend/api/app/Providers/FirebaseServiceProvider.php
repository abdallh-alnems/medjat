<?php

declare(strict_types=1);

namespace App\Providers;

use App\Modules\Auth\Services\FirebaseAccountManager;
use App\Modules\Auth\Services\FirebaseCustomTokenMinter;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Auth\Services\KreaitFirebaseAccountManager;
use App\Modules\Auth\Services\KreaitFirebaseCustomTokenMinter;
use App\Modules\Auth\Services\KreaitFirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Modules\Notifications\Services\FirebasePushSender;
use App\Shared\RemoteConfig\FirebaseRemoteConfigAdmin;
use App\Shared\RemoteConfig\FirebaseRemoteConfigGate;
use App\Shared\RemoteConfig\RemoteConfigAdmin;
use App\Shared\RemoteConfig\RemoteConfigGate;
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
            $path = Config::string('permedjat.firebase.credentials_path');

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
            $path = Config::string('permedjat.firebase.credentials_path');

            if ($path === '' || ! is_file($path)) {
                throw new RuntimeException("Firebase credentials not found at: {$path}");
            }

            return (new Factory)->withServiceAccount($path)->createMessaging();
        });

        // The factory, not the client: resolving a PushSender must not read
        // the credentials file, because every caller treats delivery as
        // best-effort and a missing file would otherwise 500 the action being
        // announced rather than just losing the notification.
        $this->app->bind(
            PushSender::class,
            fn (Application $app): PushSender => new FirebasePushSender(
                static fn (): Messaging => $app->make(Messaging::class),
            ),
        );

        $this->app->bind(
            FirebaseAccountManager::class,
            fn (Application $app): FirebaseAccountManager => new KreaitFirebaseAccountManager($app->make(FirebaseAuth::class)),
        );

        $this->app->singleton(RemoteConfig::class, function (): RemoteConfig {
            $path = Config::string('permedjat.firebase.credentials_path');

            if ($path === '' || ! is_file($path)) {
                throw new RuntimeException("Firebase credentials not found at: {$path}");
            }

            return (new Factory)->withServiceAccount($path)->createRemoteConfig();
        });

        $this->app->bind(
            RemoteConfigGate::class,
            fn (Application $app): RemoteConfigGate => new FirebaseRemoteConfigGate($app->make(RemoteConfig::class)),
        );

        // The operator's view of the same thing: uncached and fail-loud, where
        // the gate above is cached and fails open.
        $this->app->bind(
            RemoteConfigAdmin::class,
            fn (Application $app): RemoteConfigAdmin => new FirebaseRemoteConfigAdmin($app->make(RemoteConfig::class)),
        );
    }
}
