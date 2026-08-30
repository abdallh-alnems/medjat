<?php

declare(strict_types=1);

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
        // apiPrefix is empty because the old backend's URLs have no /api
        // segment and the published apps send them verbatim. The deployment
        // root supplies whatever prefix nginx needs.
        apiPrefix: '',
        api: __DIR__.'/../routes/api.php',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            // The shared secret the published app bundles carry. Not
            // authentication — that is the guards below — but the difference
            // between our clients reaching an endpoint and everything reaching
            // it.
            'app.secret' => App\Http\Middleware\RequireAppSecret::class,
            'auth.employee' => App\Http\Middleware\AuthenticateEmployee::class,
            'auth.admin' => App\Http\Middleware\AuthenticateAdmin::class,
            'auth.either' => App\Http\Middleware\AuthenticateEmployeeOrAdmin::class,
            // A kiosk authenticates as a branch, not as a person — the third
            // principal, and the reason it is a guard of its own.
            'auth.kiosk' => App\Http\Middleware\AuthenticateKiosk::class,
            'tenant' => App\Http\Middleware\RequireTenant::class,
            'can.do' => App\Http\Middleware\RequirePermission::class,
            // The support desk: the fourth principal, and the only one not
            // scoped to a company.
            'auth.super' => App\Http\Middleware\AuthenticateSuperAdmin::class,
            // The scheduled jobs, which authenticate with a shared secret
            // rather than as any of the principals.
            'auth.cron' => App\Http\Middleware\AuthenticateCron::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
