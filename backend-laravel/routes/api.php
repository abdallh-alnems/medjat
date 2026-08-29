<?php

declare(strict_types=1);

use App\Http\Controllers\Auth\EmployeeLogoutController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API routes
|--------------------------------------------------------------------------
|
| Two names for every endpoint, on purpose.
|
| `legacy` reproduces the old backend's URLs, .php suffix and all, because
| API_HOST is compiled into the Flutter bundles: every medjat_app and
| medjat_central install already in Google Play, the App Store and AppGallery
| asks for /app/auth/employee_logout.php and will keep asking for as long as it
| stays installed. These are permanent, not transitional.
|
| `v1` is the shape new clients get. As each module is ported the legacy name
| stops being served by the old PHP backend and starts being served here, which
| is what makes this a strangler migration rather than a rewrite: at no point is
| there a version of the system that does not work.
|
*/

Route::middleware('throttle:api')->group(function (): void {

    // ── Employee sessions ────────────────────────────────────────────────
    Route::post('v1/auth/employee/logout', EmployeeLogoutController::class)
        ->name('employee.logout');

    Route::post('app/auth/employee_logout.php', EmployeeLogoutController::class)
        ->name('legacy.employee.logout');

});
