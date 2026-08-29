<?php

declare(strict_types=1);

use App\Http\Controllers\Attendance\BranchAttendanceController;
use App\Http\Controllers\Attendance\BranchQrCodeController;
use App\Http\Controllers\Attendance\CheckInController;
use App\Http\Controllers\Attendance\CheckOutController;
use App\Http\Controllers\Attendance\CrewCheckInController;
use App\Http\Controllers\Attendance\CrewListController;
use App\Http\Controllers\Attendance\FaceChallengeController;
use App\Http\Controllers\Attendance\FaceLogsController;
use App\Http\Controllers\Attendance\ManualCheckInController;
use App\Http\Controllers\Attendance\MyAttendanceController;
use App\Http\Controllers\Attendance\PunchPhotoController;
use App\Http\Controllers\Attendance\SecurityLogController;
use App\Http\Controllers\Attendance\SetDayStatusController;
use App\Http\Controllers\Attendance\SetMethodOverrideController;
use App\Http\Controllers\Attendance\SyncOfflineController;
use App\Http\Controllers\Attendance\UpdateNoteController;
use App\Http\Controllers\Attendance\WebStatusController;
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
use App\Http\Controllers\Documents\EmployeeDocumentsController;
use App\Http\Controllers\Documents\ReviewDocumentController;
use App\Http\Controllers\Employees\ActivationCodeController;
use App\Http\Controllers\Employees\CreateEmployeeController;
use App\Http\Controllers\Employees\DeleteEmployeeController;
use App\Http\Controllers\Employees\EmployeeProfileController;
use App\Http\Controllers\Employees\EmployeeStatusController;
use App\Http\Controllers\Employees\ListEmployeesController;
use App\Http\Controllers\Employees\ListTerminatedController;
use App\Http\Controllers\Employees\MyProfileController;
use App\Http\Controllers\Employees\SuspensionController;
use App\Http\Controllers\Employees\UpdateEmployeeController;
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

    // ── Attendance ───────────────────────────────────────────────────────
    // Both channels reach the same action; which one is in play comes from the
    // session, never from the request.
    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::post('v1/attendance/check-in', CheckInController::class)->name('attendance.check-in');
        Route::post('v1/attendance/check-out', CheckOutController::class)->name('attendance.check-out');

        Route::post('app/attendance/check_in.php', CheckInController::class)
            ->name('legacy.attendance.check-in');
        Route::post('app/attendance/check_out.php', CheckOutController::class)
            ->name('legacy.attendance.check-out');

        Route::post('v1/attendance/face-challenge', FaceChallengeController::class)
            ->name('attendance.face-challenge');
        Route::post('v1/attendance/crew', CrewListController::class)->name('attendance.crew');
        Route::post('v1/attendance/security-log', SecurityLogController::class)
            ->name('attendance.security-log');

        Route::post('app/attendance/face_challenge.php', FaceChallengeController::class)
            ->name('legacy.attendance.face-challenge');
        Route::post('app/attendance/crew_list.php', CrewListController::class)
            ->name('legacy.attendance.crew');

        Route::post('v1/attendance/crew/punch', CrewCheckInController::class)
            ->name('attendance.crew.punch');
        Route::post('app/attendance/crew_check_in.php', CrewCheckInController::class)
            ->name('legacy.attendance.crew.punch');

        Route::post('v1/attendance/sync-offline', SyncOfflineController::class)
            ->name('attendance.sync-offline');
        Route::post('app/attendance/sync_offline.php', SyncOfflineController::class)
            ->name('legacy.attendance.sync-offline');
        Route::post('app/attendance/security_log.php', SecurityLogController::class)
            ->name('legacy.attendance.security-log');

        Route::get('v1/attendance/mine', MyAttendanceController::class)->name('attendance.mine');
        Route::get('app/attendance/get_my_attendance.php', MyAttendanceController::class)
            ->name('legacy.attendance.mine');

        Route::post('v1/attendance/web-status', WebStatusController::class)
            ->name('attendance.web-status');
        Route::post('app/attendance/web_status.php', WebStatusController::class)
            ->name('legacy.attendance.web-status');
    });

    // Management side: recorded for an employee rather than by them.
    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::post('v1/attendance/method-override', SetMethodOverrideController::class)
            ->middleware('can.do:manage_company_settings')
            ->name('attendance.method-override');
        Route::post('app/attendance/set_method_override.php', SetMethodOverrideController::class)
            ->middleware('can.do:manage_company_settings')
            ->name('legacy.attendance.method-override');

        Route::post('v1/attendance/branch-qr', BranchQrCodeController::class)
            ->middleware('can.do:manage_company_settings')
            ->name('attendance.branch-qr');
        Route::post('app/attendance/branch_qr_code.php', BranchQrCodeController::class)
            ->middleware('can.do:manage_company_settings')
            ->name('legacy.attendance.branch-qr');

        Route::middleware('can.do:manage_attendance')->group(function (): void {
            Route::get('v1/attendance/branch', BranchAttendanceController::class)
                ->name('attendance.branch');
            Route::get('v1/attendance/photo', PunchPhotoController::class)
                ->name('attendance.photo');
            Route::post('v1/attendance/face-logs', FaceLogsController::class)
                ->name('attendance.face-logs');

            Route::get('app/attendance/get_branch_attendance.php', BranchAttendanceController::class)
                ->name('legacy.attendance.branch');
            Route::get('app/attendance/punch_photo.php', PunchPhotoController::class)
                ->name('legacy.attendance.photo');
            Route::post('app/attendance/face_logs.php', FaceLogsController::class)
                ->name('legacy.attendance.face-logs');

            Route::post('v1/attendance/day-status', SetDayStatusController::class)
                ->name('attendance.day-status');
            Route::post('app/attendance/set_day_status.php', SetDayStatusController::class)
                ->name('legacy.attendance.day-status');

            Route::post('v1/attendance/manual', ManualCheckInController::class)
                ->name('attendance.manual');
            Route::post('v1/attendance/note', UpdateNoteController::class)->name('attendance.note');

            Route::post('app/attendance/manual_check_in.php', ManualCheckInController::class)
                ->name('legacy.attendance.manual');
            Route::post('app/attendance/update_note.php', UpdateNoteController::class)
                ->name('legacy.attendance.note');
        });
    });

    // ── Employees ────────────────────────────────────────────────────────
    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::get('v1/employees/me', MyProfileController::class)->name('employees.me');
        Route::get('app/employees/my_profile.php', MyProfileController::class)
            ->name('legacy.employees.me');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_employees'])->group(function (): void {
        Route::get('v1/employees', ListEmployeesController::class)->name('employees.list');
        Route::get('v1/employees/terminated', ListTerminatedController::class)
            ->name('employees.terminated');
        Route::post('v1/employees/delete', DeleteEmployeeController::class)->name('employees.delete');

        Route::get('app/employees/list.php', ListEmployeesController::class)
            ->name('legacy.employees.list');
        Route::get('app/employees/list_terminated.php', ListTerminatedController::class)
            ->name('legacy.employees.terminated');
        Route::post('app/employees/delete.php', DeleteEmployeeController::class)
            ->name('legacy.employees.delete');

        Route::post('v1/employees', CreateEmployeeController::class)->name('employees.create');
        Route::post('v1/employees/update', UpdateEmployeeController::class)->name('employees.update');

        Route::post('app/employees/create.php', CreateEmployeeController::class)
            ->name('legacy.employees.create');
        Route::post('app/employees/update.php', UpdateEmployeeController::class)
            ->name('legacy.employees.update');

        Route::get('v1/employees/suspensions', [SuspensionController::class, 'index'])
            ->name('employees.suspensions');
        Route::post('v1/employees/suspend', [SuspensionController::class, 'open'])
            ->name('employees.suspend');
        Route::post('v1/employees/end-suspension', [SuspensionController::class, 'close'])
            ->name('employees.end-suspension');
        Route::post('v1/employees/reactivate', [EmployeeStatusController::class, 'reactivate'])
            ->name('employees.reactivate');
        Route::post('v1/employees/crew-supervisor', [EmployeeStatusController::class, 'setCrewSupervisor'])
            ->name('employees.crew-supervisor');
        Route::post('v1/employees/reset-web-pin', [EmployeeStatusController::class, 'resetWebPin'])
            ->name('employees.reset-web-pin');

        Route::get('app/employees/get_suspensions.php', [SuspensionController::class, 'index'])
            ->name('legacy.employees.suspensions');
        Route::post('app/employees/suspend.php', [SuspensionController::class, 'open'])
            ->name('legacy.employees.suspend');
        Route::post('app/employees/end_suspension.php', [SuspensionController::class, 'close'])
            ->name('legacy.employees.end-suspension');
        Route::post('app/employees/reactivate.php', [EmployeeStatusController::class, 'reactivate'])
            ->name('legacy.employees.reactivate');
        Route::post('app/employees/set_crew_supervisor.php', [EmployeeStatusController::class, 'setCrewSupervisor'])
            ->name('legacy.employees.crew-supervisor');
        Route::post('app/employees/reset_web_pin.php', [EmployeeStatusController::class, 'resetWebPin'])
            ->name('legacy.employees.reset-web-pin');

        Route::get('v1/employees/activation-code', [ActivationCodeController::class, 'show'])
            ->name('employees.activation-code');
        Route::post('v1/employees/activation-code', [ActivationCodeController::class, 'regenerate'])
            ->name('employees.activation-code.regenerate');

        Route::get('app/employees/activation_code.php', [ActivationCodeController::class, 'show'])
            ->name('legacy.employees.activation-code');
        Route::post('app/employees/activation_code.php', [ActivationCodeController::class, 'regenerate'])
            ->name('legacy.employees.activation-code.regenerate');
    });

    // ── Employee documents ───────────────────────────────────────────────
    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::middleware('can.do:manage_documents')->group(function (): void {
            Route::get('v1/employees/documents', [EmployeeDocumentsController::class, 'index'])
                ->name('documents.index');
            Route::get('v1/employees/documents/missing', [EmployeeDocumentsController::class, 'missing'])
                ->name('documents.missing');
            Route::post('v1/employees/documents/update', [ReviewDocumentController::class, 'update'])
                ->name('documents.update');
            Route::post('v1/employees/documents/delete', [ReviewDocumentController::class, 'destroy'])
                ->name('documents.delete');

            Route::get('app/employees/get_documents.php', [EmployeeDocumentsController::class, 'index'])
                ->name('legacy.documents.index');
            Route::get('app/employees/get_missing_documents.php', [EmployeeDocumentsController::class, 'missing'])
                ->name('legacy.documents.missing');
            Route::post('app/employees/update_document.php', [ReviewDocumentController::class, 'update'])
                ->name('legacy.documents.update');
            Route::post('app/employees/delete_document.php', [ReviewDocumentController::class, 'destroy'])
                ->name('legacy.documents.delete');
        });

        // Verifying is its own permission: deciding whether a passport is
        // genuine is a different job from filing it.
        Route::middleware('can.do:documents_verify')->group(function (): void {
            Route::post('v1/employees/documents/verify', [ReviewDocumentController::class, 'verify'])
                ->name('documents.verify');
            Route::post('v1/employees/documents/reject', [ReviewDocumentController::class, 'reject'])
                ->name('documents.reject');

            Route::post('app/employees/verify_document.php', [ReviewDocumentController::class, 'verify'])
                ->name('legacy.documents.verify');
            Route::post('app/employees/reject_document.php', [ReviewDocumentController::class, 'reject'])
                ->name('legacy.documents.reject');
        });
    });

    // ── Employee profile ─────────────────────────────────────────────────
    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::get('v1/employees/profile', [EmployeeProfileController::class, 'show'])
            ->name('employees.profile');
        Route::get('app/employees/get_profile.php', [EmployeeProfileController::class, 'show'])
            ->name('legacy.employees.profile');

        Route::get('v1/employees/expiring-compliance', [EmployeeProfileController::class, 'expiringCompliance'])
            ->middleware('can.do:manage_employees')
            ->name('employees.expiring-compliance');
        Route::get('app/employees/expiring_compliance.php', [EmployeeProfileController::class, 'expiringCompliance'])
            ->middleware('can.do:manage_employees')
            ->name('legacy.employees.expiring-compliance');

        Route::get('v1/employees/year-to-date', [EmployeeProfileController::class, 'yearToDate'])
            ->middleware('can.do:manage_payroll')
            ->name('employees.year-to-date');
        Route::get('app/employees/get_year_to_date.php', [EmployeeProfileController::class, 'yearToDate'])
            ->middleware('can.do:manage_payroll')
            ->name('legacy.employees.year-to-date');
    });

});
