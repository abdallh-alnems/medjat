<?php

declare(strict_types=1);

use App\Shared\Http\ApiResponse;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| The root
|--------------------------------------------------------------------------
|
| This host serves an API, not a site — the marketing pages live on
| permedjatapp.com and the management app on app.permedjatapp.com. The skeleton's
| welcome page was still here, which told anybody who found the domain what
| framework and version it runs.
|
| Answering rather than 404ing, because somebody eventually points a browser
| here and a one-line answer is kinder than a stack of nothing. The health
| check is /up.
|
*/

Route::get('/', fn () => ApiResponse::success([
    'service' => 'permedjat-api',
    'endpoints' => '/v1',
]))->name('root');
