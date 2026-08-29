<?php

declare(strict_types=1);

use App\Http\Controllers\Auth\AdminLoginController;
use App\Http\Controllers\Auth\AdminLogoutController;
use App\Http\Controllers\Auth\DeleteAccountController;
use App\Http\Controllers\Auth\DesktopAuthController;
use App\Http\Controllers\Auth\EmployeeActivateTokenController;
use App\Http\Controllers\Auth\EmployeeLoginController;
use App\Http\Controllers\Auth\EmployeeLogoutController;
use App\Http\Controllers\Auth\EmployeeWebActivateController;
use App\Http\Controllers\Auth\EmployeeWebLoginController;
use App\Http\Controllers\Auth\EmployeeWebLogoutController;
use App\Http\Controllers\Auth\NotificationPrefsController;
use App\Http\Controllers\Auth\SendAuthActionController;
use App\Http\Controllers\Auth\UpdateFcmTokenController;
use App\Http\Controllers\Auth\UpdateProfileController;
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
    Route::post('v1/auth/employee/activate', EmployeeActivateTokenController::class)
        ->name('employee.activate');
    Route::post('v1/auth/employee/login', EmployeeLoginController::class)
        ->name('employee.login');
    Route::post('v1/auth/employee/logout', EmployeeLogoutController::class)
        ->name('employee.logout');

    Route::post('app/auth/employee_activate_token.php', EmployeeActivateTokenController::class)
        ->name('legacy.employee.activate');
    Route::post('app/auth/employee_login.php', EmployeeLoginController::class)
        ->name('legacy.employee.login');
    Route::post('app/auth/employee_logout.php', EmployeeLogoutController::class)
        ->name('legacy.employee.logout');

    // ── Browser sessions ─────────────────────────────────────────────────
    // A separate identity from the phone: signing in here must not sign the
    // employee out of their app, and vice versa.
    Route::post('v1/auth/employee/web/activate', EmployeeWebActivateController::class)
        ->name('employee.web.activate');
    Route::post('v1/auth/employee/web/login', EmployeeWebLoginController::class)
        ->name('employee.web.login');
    Route::post('v1/auth/employee/web/logout', EmployeeWebLogoutController::class)
        ->name('employee.web.logout');

    Route::post('app/auth/employee_web_activate.php', EmployeeWebActivateController::class)
        ->name('legacy.employee.web.activate');
    Route::post('app/auth/employee_web_login.php', EmployeeWebLoginController::class)
        ->name('legacy.employee.web.login');
    Route::post('app/auth/employee_web_logout.php', EmployeeWebLogoutController::class)
        ->name('legacy.employee.web.logout');

    // ── Administrator sessions ───────────────────────────────────────────
    // Sign-in verifies the Firebase token itself, so it sits outside the guard.
    Route::post('v1/auth/admin/login', AdminLoginController::class)->name('admin.login');
    Route::post('app/auth/login.php', AdminLoginController::class)->name('legacy.admin.login');

    Route::middleware('auth.admin')->group(function (): void {
        Route::post('v1/auth/admin/logout', AdminLogoutController::class)
            ->name('admin.logout');
        Route::post('app/auth/logout.php', AdminLogoutController::class)
            ->name('legacy.admin.logout');
    });

    // ── Desktop shell sign-in ────────────────────────────────────────────
    // The exchange is unauthenticated on purpose: the code IS the credential.
    Route::post('v1/auth/desktop/exchange', [DesktopAuthController::class, 'exchange'])
        ->name('desktop.exchange');
    Route::post('app/auth/desktop_exchange.php', [DesktopAuthController::class, 'exchange'])
        ->name('legacy.desktop.exchange');

    Route::middleware('auth.admin')->group(function (): void {
        Route::post('v1/auth/desktop/authorize', [DesktopAuthController::class, 'authorize'])
            ->name('desktop.authorize');
        Route::post('app/auth/desktop_authorize.php', [DesktopAuthController::class, 'authorize'])
            ->name('legacy.desktop.authorize');

        Route::post('v1/auth/account', DeleteAccountController::class)->name('account.delete');
        Route::post('app/auth/delete_account.php', DeleteAccountController::class)
            ->name('legacy.account.delete');
    });

    // ── Transactional auth email ─────────────────────────────────────────
    // Unauthenticated, and both always answer success: saying whether an
    // address is registered would make either one an enumeration oracle.
    Route::post('v1/auth/password-reset', [SendAuthActionController::class, 'passwordReset'])
        ->name('password-reset.send');
    Route::post('v1/auth/verification', [SendAuthActionController::class, 'verification'])
        ->name('verification.send');

    Route::post('app/auth/send_password_reset.php', [SendAuthActionController::class, 'passwordReset'])
        ->name('legacy.password-reset.send');
    Route::post('app/auth/send_verification.php', [SendAuthActionController::class, 'verification'])
        ->name('legacy.verification.send');

    // ── Account settings ─────────────────────────────────────────────────
    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::post('v1/auth/profile', UpdateProfileController::class)->name('profile.update');
        Route::post('app/auth/update_profile.php', UpdateProfileController::class)
            ->name('legacy.profile.update');
    });

    Route::middleware('auth.employee')->group(function (): void {
        Route::get('v1/auth/notification-prefs', [NotificationPrefsController::class, 'show'])
            ->name('notification-prefs.show');
        Route::post('v1/auth/notification-prefs', [NotificationPrefsController::class, 'update'])
            ->name('notification-prefs.update');

        // One legacy URL, two methods — the old file branched on the request
        // method inside itself.
        Route::get('app/auth/notification_prefs.php', [NotificationPrefsController::class, 'show'])
            ->name('legacy.notification-prefs.show');
        Route::post('app/auth/notification_prefs.php', [NotificationPrefsController::class, 'update'])
            ->name('legacy.notification-prefs.update');
    });

    // Called by both apps, so the principal follows whichever credential arrived.
    Route::middleware('auth.either')->group(function (): void {
        Route::post('v1/auth/fcm-token', UpdateFcmTokenController::class)->name('fcm-token.update');
        Route::post('app/auth/update_fcm_token.php', UpdateFcmTokenController::class)
            ->name('legacy.fcm-token.update');
    });

});
