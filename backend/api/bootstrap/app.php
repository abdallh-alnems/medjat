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
    // Registered by hand because the commands live with the module they serve
    // rather than in app/Console/Commands, which is the only place Laravel
    // discovers them. Both entry points to the scheduled work — the CLI and
    // the cron URL — now sit in one directory with the code they run.
    ->withCommands([
        App\Modules\Cron\Console\BaselineSchemaCommand::class,
        App\Modules\Cron\Console\CatchUpAbsencesCommand::class,
        App\Modules\Cron\Console\PurgeKioskCapturesCommand::class,
        App\Modules\Cron\Console\RunDailyAlertsCommand::class,
        App\Shared\Docs\GenerateOpenApiCommand::class,
    ])
    ->withMiddleware(function (Middleware $middleware): void {
        // Who is allowed to tell us the client's address.
        //
        // Empty by default, and that is the correct setting for this
        // deployment: nginx maps Cloudflare's CF-Connecting-IP onto REMOTE_ADDR
        // before PHP sees the request, so the address is already right and
        // trusting a forwarded header on top of it would let a client name its
        // own IP by sending X-Forwarded-For. That would be worse than the
        // problem, because the address is what rate limiting buckets on and
        // what attendance_security_logs records.
        //
        // It is configured explicitly rather than left unset so the decision is
        // visible. If this ever runs behind a proxy that does *not* rewrite
        // REMOTE_ADDR, set TRUSTED_PROXIES to that proxy's addresses — never to
        // '*', which trusts whatever the caller claims.
        $proxies = array_values(array_filter(
            array_map('trim', explode(',', (string) env('TRUSTED_PROXIES', '')))
        ));

        if ($proxies !== []) {
            $middleware->trustProxies(at: $proxies);
        }

        // Every API request, before anything can produce a message: the reply
        // should be in the language the caller asked for, including the replies
        // from the guards below that reject it.
        $middleware->prependToGroup('api', App\Shared\Http\Middleware\ResolveLocale::class);

        $middleware->alias([
            // The shared secret the published app bundles carry. Not
            // authentication — that is the guards below — but the difference
            // between our clients reaching an endpoint and everything reaching
            // it.
            'app.secret' => App\Shared\Http\Middleware\RequireAppSecret::class,
            'auth.employee' => App\Shared\Http\Middleware\AuthenticateEmployee::class,
            'auth.admin' => App\Shared\Http\Middleware\AuthenticateAdmin::class,
            'auth.either' => App\Shared\Http\Middleware\AuthenticateEmployeeOrAdmin::class,
            // A kiosk authenticates as a branch, not as a person — the third
            // principal, and the reason it is a guard of its own.
            'auth.kiosk' => App\Shared\Http\Middleware\AuthenticateKiosk::class,
            'tenant' => App\Shared\Http\Middleware\RequireTenant::class,
            'can.do' => App\Shared\Http\Middleware\RequirePermission::class,
            // The support desk: the fourth principal, and the only one not
            // scoped to a company.
            'auth.super' => App\Shared\Http\Middleware\AuthenticateSuperAdmin::class,
            // The scheduled jobs, which authenticate with a shared secret
            // rather than as any of the principals.
            'auth.cron' => App\Shared\Http\Middleware\AuthenticateCron::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // 'v1/*', not Laravel's default 'api/*': apiPrefix is empty here, so
        // every endpoint is /v1/… and the stock condition matched nothing at
        // all. Clients that send Accept: application/json were carried by
        // expectsJson(), which is why it went unnoticed — but a client that
        // omits the header would have been handed an HTML error page by an API
        // that answers JSON everywhere else.
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('v1/*') || $request->expectsJson(),
        );
    })->create();
