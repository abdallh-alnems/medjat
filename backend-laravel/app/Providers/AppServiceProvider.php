<?php

declare(strict_types=1);

namespace App\Providers;

use App\Http\ApiResponse;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        $this->configureRateLimiting();
    }

    /**
     * Mirrors the old backend's RateLimiter::enforceIpLimit() — 600 requests
     * per minute per IP. The ceiling is high on purpose: a branch punching in
     * at shift change shares one NAT address, so this stops a runaway client
     * rather than shaping normal traffic.
     *
     * The refusal is rendered through ApiResponse so a throttled request looks
     * like every other failure to the apps, not like Laravel's default body.
     */
    private function configureRateLimiting(): void
    {
        RateLimiter::for('api', function (Request $request): Limit {
            return Limit::perMinute(Config::integer('medjat.rate_limit.per_minute'))
                ->by($request->ip() ?? 'unknown')
                ->response(fn (): mixed => ApiResponse::fail(
                    'عدد كبير من الطلبات، حاول بعد قليل',
                    429,
                    'rate_limited'
                ));
        });
    }
}
